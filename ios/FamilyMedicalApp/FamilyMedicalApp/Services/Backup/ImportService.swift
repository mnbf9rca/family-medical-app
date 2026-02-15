import CryptoKit
import Foundation

/// Protocol for data import operations
///
/// ImportService restores user data from a BackupPayload into the app's repositories.
protocol ImportServiceProtocol: Sendable {
    /// Import data from a backup payload
    ///
    /// This method:
    /// 1. Creates new persons with fresh FMKs
    /// 2. Encrypts and saves medical records
    /// 3. Saves attachments (re-encrypts with new FMK)
    /// 4. Saves custom schemas
    ///
    /// - Parameters:
    ///   - payload: The backup payload to import
    ///   - primaryKey: User's primary key for FMK operations
    /// - Throws: BackupError if import fails
    func importData(_ payload: BackupPayload, primaryKey: SymmetricKey) async throws
}

/// Service for importing backup data into the app
///
/// Takes a BackupPayload and restores all data to repositories, generating
/// new FMKs for each person and re-encrypting all sensitive data.
final class ImportService: ImportServiceProtocol, @unchecked Sendable {
    // MARK: - Dependencies

    private let personRepository: PersonRepositoryProtocol
    private let recordRepository: MedicalRecordRepositoryProtocol
    private let recordContentService: RecordContentServiceProtocol
    private let attachmentService: AttachmentServiceProtocol
    private let customSchemaRepository: CustomSchemaRepositoryProtocol
    private let fmkService: FamilyMemberKeyServiceProtocol
    private let logger: TracingCategoryLogger

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
        self.logger = TracingCategoryLogger(
            wrapping: logger ?? LoggingService.shared.logger(category: .backup)
        )
    }

    // MARK: - ImportServiceProtocol

    func importData(_ payload: BackupPayload, primaryKey: SymmetricKey) async throws {
        let start = ContinuousClock.now
        logger.entry("importData")
        logger.debug("Starting data import")

        // Track FMKs by person ID for record/schema imports
        var personFMKs: [UUID: SymmetricKey] = [:]

        // Step 1: Import persons and create FMKs
        for personBackup in payload.persons {
            let fmk = try await importPerson(personBackup, primaryKey: primaryKey)
            personFMKs[personBackup.id] = fmk
        }

        // Step 2: Import records (need person FMKs)
        for recordBackup in payload.records {
            try await importRecord(recordBackup, personFMKs: personFMKs)
        }

        // Step 3: Import attachments (need person FMKs and record IDs)
        for attachmentBackup in payload.attachments {
            try await importAttachment(attachmentBackup, personFMKs: personFMKs, primaryKey: primaryKey)
        }

        // Step 4: Import schemas (need person FMKs)
        for schemaBackup in payload.schemas {
            try await importSchema(schemaBackup, personFMKs: personFMKs)
        }

        logger.debug(
            "Import complete: \(payload.persons.count) persons, " +
                "\(payload.records.count) records, " +
                "\(payload.attachments.count) attachments, " +
                "\(payload.schemas.count) schemas"
        )
        logger.exit("importData", duration: ContinuousClock.now - start)
    }

    // MARK: - Private Import Methods

    private func importPerson(_ backup: PersonBackup, primaryKey: SymmetricKey) async throws -> SymmetricKey {
        let start = ContinuousClock.now
        logger.entry("importPerson")
        // Convert to Person model
        let person: Person
        do {
            person = try backup.toPerson()
        } catch {
            logger.error("Failed to create person from backup")
            throw BackupError.importFailed("Invalid person data in backup")
        }

        // TODO: Issue #98 - Add conflict detection and resolution UI
        // Currently fails if person already exists with different FMK

        // Generate and store new FMK for this person
        let fmk = fmkService.generateFMK()
        do {
            try fmkService.storeFMK(fmk, familyMemberID: person.id.uuidString, primaryKey: primaryKey)
        } catch {
            logger.error("Failed to store FMK for imported person")
            throw BackupError.importFailed("Failed to create encryption key for person")
        }

        // Save person
        do {
            try await personRepository.save(person, primaryKey: primaryKey)
        } catch {
            logger.error("Failed to save imported person")
            throw BackupError.importFailed("Failed to save person")
        }

        logger.exit("importPerson", duration: ContinuousClock.now - start)
        return fmk
    }

    private func importRecord(_ backup: MedicalRecordBackup, personFMKs: [UUID: SymmetricKey]) async throws {
        let start = ContinuousClock.now
        logger.entry("importRecord")
        guard let fmk = personFMKs[backup.personId] else {
            logger.error("No FMK found for record's person")
            throw BackupError.importFailed("Missing encryption key for record")
        }

        // Convert to RecordContent and encrypt
        let content: RecordContent
        do {
            content = try backup.toRecordContent()
        } catch let error as FieldValueConversionError {
            logger.error("Invalid field value in backup record: \(error.localizedDescription)")
            throw BackupError.corruptedFile
        }

        let encryptedContent: Data
        do {
            encryptedContent = try recordContentService.encrypt(content, using: fmk)
        } catch {
            logger.error("Failed to encrypt record content during import")
            throw BackupError.importFailed("Failed to encrypt medical record")
        }

        // Create MedicalRecord with encrypted content
        let record = MedicalRecord(
            id: backup.id,
            personId: backup.personId,
            encryptedContent: encryptedContent,
            createdAt: backup.createdAt,
            updatedAt: backup.updatedAt,
            version: backup.version,
            previousVersionId: backup.previousVersionId
        )

        // Save record
        do {
            try await recordRepository.save(record)
        } catch {
            logger.error("Failed to save imported record")
            throw BackupError.importFailed("Failed to save medical record")
        }
        logger.exit("importRecord", duration: ContinuousClock.now - start)
    }

    private func importAttachment(
        _ backup: AttachmentBackup,
        personFMKs: [UUID: SymmetricKey],
        primaryKey: SymmetricKey
    ) async throws {
        let start = ContinuousClock.now
        logger.entry("importAttachment")
        guard personFMKs[backup.personId] != nil else {
            logger.error("No FMK found for attachment's person")
            throw BackupError.importFailed("Missing encryption key for attachment")
        }

        guard let recordId = backup.linkedRecordIds.first else {
            logger.error("Attachment has no linked record")
            throw BackupError.importFailed("Attachment has no linked record")
        }

        // Log notice if attachment has multiple linked records (not currently supported)
        if backup.linkedRecordIds.count > 1 {
            logger.notice(
                "Attachment \(backup.id) has \(backup.linkedRecordIds.count) linked records; " +
                    "only importing link to first record \(recordId)"
            )
        }

        guard let content = backup.contentData else {
            logger.error("Attachment has no content data")
            throw BackupError.importFailed("Attachment content is missing")
        }

        // Use AttachmentService to add (which handles encryption, thumbnails, etc.)
        // Pass backup.id to preserve attachment IDs for attachmentIds field references
        let input = AddAttachmentInput(
            id: backup.id,
            data: content,
            fileName: backup.fileName,
            mimeType: backup.mimeType,
            recordId: recordId,
            personId: backup.personId,
            primaryKey: primaryKey
        )

        do {
            _ = try await attachmentService.addAttachment(input)
        } catch {
            logger.error("Failed to save imported attachment")
            throw BackupError.importFailed("Failed to save attachment")
        }
        logger.exit("importAttachment", duration: ContinuousClock.now - start)
    }

    private func importSchema(_ backup: SchemaBackup, personFMKs: [UUID: SymmetricKey]) async throws {
        let start = ContinuousClock.now
        logger.entry("importSchema")
        guard let fmk = personFMKs[backup.personId] else {
            logger.error("No FMK found for schema's person")
            throw BackupError.importFailed("Missing encryption key for schema")
        }

        do {
            try await customSchemaRepository.save(backup.schema, forPerson: backup.personId, familyMemberKey: fmk)
        } catch {
            logger.error("Failed to save imported schema")
            throw BackupError.importFailed("Failed to save custom schema")
        }
        logger.exit("importSchema", duration: ContinuousClock.now - start)
    }
}
