import CryptoKit
import Foundation

/// Collects backup data during export
private struct BackupCollector {
    var persons: [PersonBackup] = []
    var records: [MedicalRecordBackup] = []
    var attachments: [AttachmentBackup] = []
    var schemas: [SchemaBackup] = []

    func buildPayload(appVersion: String, logger: CategoryLoggerProtocol) -> BackupPayload {
        let metadata = BackupMetadata(
            personCount: persons.count,
            recordCount: records.count,
            attachmentCount: attachments.count,
            schemaCount: schemas.count
        )

        logger.debug(
            "Export complete: \(metadata.personCount) persons, " +
                "\(metadata.recordCount) records, " +
                "\(metadata.attachmentCount) attachments, " +
                "\(metadata.schemaCount) schemas"
        )

        return BackupPayload(
            exportedAt: Date(),
            appVersion: appVersion,
            metadata: metadata,
            persons: persons,
            records: records,
            attachments: attachments,
            schemas: schemas
        )
    }
}

/// Protocol for data export operations
///
/// ExportService orchestrates the collection of all user data (persons, medical records,
/// attachments, custom schemas) into a BackupPayload suitable for serialization.
protocol ExportServiceProtocol: Sendable {
    /// Export all user data to a backup payload
    ///
    /// This method:
    /// 1. Fetches all persons
    /// 2. For each person, fetches their medical records (decrypted)
    /// 3. For each record, fetches linked attachments with content
    /// 4. For each person, fetches custom schemas
    /// 5. Assembles everything into a BackupPayload
    ///
    /// - Parameter primaryKey: User's primary key for FMK decryption
    /// - Returns: BackupPayload containing all exportable data
    /// - Throws: BackupError if data collection fails
    func exportData(primaryKey: SymmetricKey) async throws -> BackupPayload
}

/// Service for exporting user data to backup format
///
/// Collects all user data from repositories, decrypts as needed, and assembles
/// into a BackupPayload. The payload can then be encrypted and serialized
/// by BackupFileService.
final class ExportService: ExportServiceProtocol, @unchecked Sendable {
    // MARK: - Dependencies

    private let personRepository: PersonRepositoryProtocol
    private let recordRepository: MedicalRecordRepositoryProtocol
    private let recordContentService: RecordContentServiceProtocol
    private let attachmentService: AttachmentServiceProtocol
    private let customSchemaRepository: CustomSchemaRepositoryProtocol
    private let fmkService: FamilyMemberKeyServiceProtocol
    private let logger: CategoryLoggerProtocol

    // MARK: - Initialization

    init(
        personRepository: PersonRepositoryProtocol,
        recordRepository: MedicalRecordRepositoryProtocol,
        recordContentService: RecordContentServiceProtocol,
        attachmentService: AttachmentServiceProtocol,
        customSchemaRepository: CustomSchemaRepositoryProtocol,
        fmkService: FamilyMemberKeyServiceProtocol,
        logger: CategoryLoggerProtocol? = nil
    ) {
        self.personRepository = personRepository
        self.recordRepository = recordRepository
        self.recordContentService = recordContentService
        self.attachmentService = attachmentService
        self.customSchemaRepository = customSchemaRepository
        self.fmkService = fmkService
        self.logger = logger ?? LoggingService.shared.logger(category: .storage)
    }

    // MARK: - ExportServiceProtocol

    func exportData(primaryKey: SymmetricKey) async throws -> BackupPayload {
        logger.debug("Starting data export")

        let persons = try await fetchPersons(primaryKey: primaryKey)
        logger.debug("Exporting \(persons.count) persons")

        var collector = BackupCollector()

        for person in persons {
            try await exportPerson(person, primaryKey: primaryKey, collector: &collector)
        }

        return collector.buildPayload(appVersion: appVersion(), logger: logger)
    }

    private func fetchPersons(primaryKey: SymmetricKey) async throws -> [Person] {
        do {
            return try await personRepository.fetchAll(primaryKey: primaryKey)
        } catch {
            logger.error("Failed to fetch persons for export")
            throw BackupError.exportFailed("Failed to fetch persons: \(error.localizedDescription)")
        }
    }

    private func exportPerson(
        _ person: Person,
        primaryKey: SymmetricKey,
        collector: inout BackupCollector
    ) async throws {
        let fmk = try retrieveFMK(for: person, primaryKey: primaryKey)

        collector.persons.append(PersonBackup(from: person))

        let records = try await exportRecords(for: person, fmk: fmk, primaryKey: primaryKey, collector: &collector)
        collector.records.append(contentsOf: records)

        let schemas = try await exportSchemas(for: person, fmk: fmk)
        collector.schemas.append(contentsOf: schemas)
    }

    private func retrieveFMK(for person: Person, primaryKey: SymmetricKey) throws -> SymmetricKey {
        do {
            return try fmkService.retrieveFMK(familyMemberID: person.id.uuidString, primaryKey: primaryKey)
        } catch {
            logger.error("Failed to retrieve FMK for person during export")
            throw BackupError.exportFailed("Failed to retrieve encryption key for person")
        }
    }

    // MARK: - Private Helpers

    /// Export all medical records for a person
    private func exportRecords(
        for person: Person,
        fmk: SymmetricKey,
        primaryKey: SymmetricKey,
        collector: inout BackupCollector
    ) async throws -> [MedicalRecordBackup] {
        let records: [MedicalRecord]
        do {
            records = try await recordRepository.fetchForPerson(personId: person.id)
        } catch {
            logger.error("Failed to fetch records for person during export")
            throw BackupError.exportFailed("Failed to fetch medical records")
        }

        var backups: [MedicalRecordBackup] = []

        for record in records {
            let content: RecordContent
            do {
                content = try recordContentService.decrypt(record.encryptedContent, using: fmk)
            } catch {
                logger.error("Failed to decrypt record content during export")
                throw BackupError.exportFailed("Failed to decrypt medical record")
            }

            let backup = MedicalRecordBackup(from: record, content: content)
            backups.append(backup)

            let attachments = try await exportAttachments(for: record, personId: person.id, primaryKey: primaryKey)
            collector.attachments.append(contentsOf: attachments)
        }

        return backups
    }

    /// Export all attachments for a record
    private func exportAttachments(
        for record: MedicalRecord,
        personId: UUID,
        primaryKey: SymmetricKey
    ) async throws -> [AttachmentBackup] {
        let attachments: [Attachment]
        do {
            attachments = try await attachmentService.fetchAttachments(
                recordId: record.id,
                personId: personId,
                primaryKey: primaryKey
            )
        } catch {
            logger.error("Failed to fetch attachments during export")
            throw BackupError.exportFailed("Failed to fetch attachments")
        }

        var backups: [AttachmentBackup] = []

        for attachment in attachments {
            // Get decrypted content
            let content: Data
            do {
                content = try await attachmentService.getContent(
                    attachment: attachment,
                    personId: personId,
                    primaryKey: primaryKey
                )
            } catch {
                logger.error("Failed to retrieve attachment content during export")
                throw BackupError.exportFailed("Failed to retrieve attachment content")
            }

            let backup = AttachmentBackup(
                id: attachment.id,
                personId: personId,
                linkedRecordIds: [record.id],
                fileName: attachment.fileName,
                mimeType: attachment.mimeType,
                content: content,
                thumbnail: attachment.thumbnailData,
                uploadedAt: attachment.uploadedAt
            )
            backups.append(backup)
        }

        return backups
    }

    /// Export all custom schemas for a person
    private func exportSchemas(
        for person: Person,
        fmk: SymmetricKey
    ) async throws -> [SchemaBackup] {
        let schemas: [RecordSchema]
        do {
            schemas = try await customSchemaRepository.fetchAll(forPerson: person.id, familyMemberKey: fmk)
        } catch {
            logger.error("Failed to fetch schemas during export")
            throw BackupError.exportFailed("Failed to fetch custom schemas")
        }

        return schemas.map { SchemaBackup(personId: person.id, schema: $0) }
    }

    /// Get app version string
    private func appVersion() -> String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
}
