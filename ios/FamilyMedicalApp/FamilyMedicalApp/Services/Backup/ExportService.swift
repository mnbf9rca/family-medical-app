import CryptoKit
import Foundation

/// Collects backup data during export
private struct BackupCollector {
    var persons: [PersonBackup] = []
    var records: [MedicalRecordBackup] = []
    var attachments: [AttachmentBackup] = []

    func buildPayload(appVersion: String, logger: CategoryLoggerProtocol) -> BackupPayload {
        let metadata = BackupMetadata(
            personCount: persons.count,
            recordCount: records.count,
            attachmentCount: attachments.count
        )

        logger.debug(
            "Export complete: \(metadata.personCount) persons, "
                + "\(metadata.recordCount) records, "
                + "\(metadata.attachmentCount) attachments"
        )

        return BackupPayload(
            exportedAt: Date(),
            appVersion: appVersion,
            metadata: metadata,
            persons: persons,
            records: records,
            attachments: attachments
        )
    }
}

/// Protocol for data export operations
protocol ExportServiceProtocol: Sendable {
    func exportData(primaryKey: SymmetricKey) async throws -> BackupPayload
}

/// Service for exporting user data to backup format
final class ExportService: ExportServiceProtocol, @unchecked Sendable {
    private let personRepository: PersonRepositoryProtocol
    private let recordRepository: MedicalRecordRepositoryProtocol
    private let recordContentService: RecordContentServiceProtocol
    private let attachmentService: AttachmentServiceProtocol
    private let fmkService: FamilyMemberKeyServiceProtocol
    private let logger: CategoryLoggerProtocol

    init(
        personRepository: PersonRepositoryProtocol,
        recordRepository: MedicalRecordRepositoryProtocol,
        recordContentService: RecordContentServiceProtocol,
        attachmentService: AttachmentServiceProtocol,
        fmkService: FamilyMemberKeyServiceProtocol,
        logger: CategoryLoggerProtocol? = nil
    ) {
        self.personRepository = personRepository
        self.recordRepository = recordRepository
        self.recordContentService = recordContentService
        self.attachmentService = attachmentService
        self.fmkService = fmkService
        self.logger = logger ?? LoggingService.shared.logger(category: .storage)
    }

    func exportData(primaryKey: SymmetricKey) async throws -> BackupPayload {
        logger.debug("Starting data export")

        let persons = try await fetchPersons(primaryKey: primaryKey)
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
    }

    private func retrieveFMK(for person: Person, primaryKey: SymmetricKey) throws -> SymmetricKey {
        do {
            return try fmkService.retrieveFMK(familyMemberID: person.id.uuidString, primaryKey: primaryKey)
        } catch {
            logger.error("Failed to retrieve FMK for person during export")
            throw BackupError.exportFailed("Failed to retrieve encryption key for person")
        }
    }

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
            let envelope: RecordContentEnvelope
            do {
                envelope = try recordContentService.decrypt(record.encryptedContent, using: fmk)
            } catch {
                logger.error("Failed to decrypt record content during export")
                throw BackupError.exportFailed("Failed to decrypt medical record")
            }

            backups.append(MedicalRecordBackup(from: record, envelope: envelope))

            let attachments = try await exportAttachments(for: record, personId: person.id, primaryKey: primaryKey)
            collector.attachments.append(contentsOf: attachments)
        }

        return backups
    }

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

            backups.append(AttachmentBackup(
                id: attachment.id,
                personId: personId,
                linkedRecordIds: [record.id],
                fileName: attachment.fileName,
                mimeType: attachment.mimeType,
                content: content,
                thumbnail: attachment.thumbnailData,
                uploadedAt: attachment.uploadedAt
            ))
        }

        return backups
    }

    private func appVersion() -> String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
}
