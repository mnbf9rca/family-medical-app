import CryptoKit
import Foundation

/// Protocol for data import operations
protocol ImportServiceProtocol: Sendable {
    func importData(_ payload: BackupPayload, primaryKey: SymmetricKey) async throws
}

/// Service for importing backup data into the app
final class ImportService: ImportServiceProtocol, @unchecked Sendable {
    private let personRepository: PersonRepositoryProtocol
    private let recordRepository: MedicalRecordRepositoryProtocol
    private let recordContentService: RecordContentServiceProtocol
    private let attachmentService: AttachmentServiceProtocol
    private let fmkService: FamilyMemberKeyServiceProtocol
    private let logger: TracingCategoryLogger

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
        self.logger = TracingCategoryLogger(
            wrapping: logger ?? LoggingService.shared.logger(category: .backup)
        )
    }

    func importData(_ payload: BackupPayload, primaryKey: SymmetricKey) async throws {
        let start = ContinuousClock.now
        logger.entry("importData")

        var personFMKs: [UUID: SymmetricKey] = [:]

        for personBackup in payload.persons {
            let fmk = try await importPerson(personBackup, primaryKey: primaryKey)
            personFMKs[personBackup.id] = fmk
        }

        for recordBackup in payload.records {
            try await importRecord(recordBackup, personFMKs: personFMKs)
        }

        for attachmentBackup in payload.attachments {
            try await importAttachment(attachmentBackup, personFMKs: personFMKs, primaryKey: primaryKey)
        }

        logger.debug(
            "Import complete: \(payload.persons.count) persons, "
                + "\(payload.records.count) records, "
                + "\(payload.attachments.count) attachments"
        )
        logger.exit("importData", duration: ContinuousClock.now - start)
    }

    private func importPerson(_ backup: PersonBackup, primaryKey: SymmetricKey) async throws -> SymmetricKey {
        let start = ContinuousClock.now
        logger.entry("importPerson")

        let person: Person
        do {
            person = try backup.toPerson()
        } catch {
            logger.error("Failed to create person from backup")
            throw BackupError.importFailed("Invalid person data in backup")
        }

        let fmk = fmkService.generateFMK()
        do {
            try fmkService.storeFMK(fmk, familyMemberID: person.id.uuidString, primaryKey: primaryKey)
        } catch {
            logger.error("Failed to store FMK for imported person")
            throw BackupError.importFailed("Failed to create encryption key for person")
        }

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

        let envelope: RecordContentEnvelope
        do {
            envelope = try backup.toEnvelope()
        } catch {
            logger.error("Invalid record type in backup")
            throw BackupError.corruptedFile
        }

        let encryptedContent: Data
        do {
            encryptedContent = try recordContentService.encrypt(envelope, using: fmk)
        } catch {
            logger.error("Failed to encrypt record content during import")
            throw BackupError.importFailed("Failed to encrypt medical record")
        }

        let record = MedicalRecord(
            id: backup.id,
            personId: backup.personId,
            encryptedContent: encryptedContent,
            createdAt: backup.createdAt,
            updatedAt: backup.updatedAt,
            version: backup.version,
            previousVersionId: backup.previousVersionId
        )

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

        if backup.linkedRecordIds.count > 1 {
            logger.notice(
                "Attachment \(backup.id) has \(backup.linkedRecordIds.count) linked records; "
                    + "only importing link to first record \(recordId)"
            )
        }

        guard let content = backup.contentData else {
            logger.error("Attachment has no content data")
            throw BackupError.importFailed("Attachment content is missing")
        }

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
}
