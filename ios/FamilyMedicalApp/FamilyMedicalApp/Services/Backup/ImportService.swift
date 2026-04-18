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
    private let providerRepository: ProviderRepositoryProtocol
    private let fmkService: FamilyMemberKeyServiceProtocol
    private let logger: TracingCategoryLogger

    init(
        personRepository: PersonRepositoryProtocol,
        recordRepository: MedicalRecordRepositoryProtocol,
        recordContentService: RecordContentServiceProtocol,
        providerRepository: ProviderRepositoryProtocol,
        fmkService: FamilyMemberKeyServiceProtocol,
        logger: CategoryLoggerProtocol? = nil
    ) {
        self.personRepository = personRepository
        self.recordRepository = recordRepository
        self.recordContentService = recordContentService
        self.providerRepository = providerRepository
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

        for providerBackup in payload.providers {
            try await importProvider(providerBackup, primaryKey: primaryKey)
        }

        logger.debug(
            "Import complete: \(payload.persons.count) persons, "
                + "\(payload.records.count) records, "
                + "\(payload.providers.count) providers"
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
            logger.logError(error, context: "ImportService.importPerson")
            throw BackupError.importFailed("Invalid person data in backup")
        }

        let fmk = fmkService.generateFMK()
        do {
            try fmkService.storeFMK(fmk, personId: person.id.uuidString, primaryKey: primaryKey)
        } catch {
            logger.logError(error, context: "ImportService.importPerson")
            throw BackupError.importFailed("Failed to create encryption key for person")
        }

        do {
            try await personRepository.save(person, primaryKey: primaryKey)
        } catch {
            logger.logError(error, context: "ImportService.importPerson")
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
            logger.logError(error, context: "ImportService.importRecord")
            throw BackupError.corruptedFile
        }

        let encryptedContent: Data
        do {
            encryptedContent = try recordContentService.encrypt(envelope, using: fmk)
        } catch {
            logger.logError(error, context: "ImportService.importRecord")
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
            logger.logError(error, context: "ImportService.importRecord")
            throw BackupError.importFailed("Failed to save medical record")
        }

        logger.exit("importRecord", duration: ContinuousClock.now - start)
    }

    private func importProvider(_ backup: ProviderBackup, primaryKey: SymmetricKey) async throws {
        let start = ContinuousClock.now
        logger.entry("importProvider")

        let provider: Provider
        do {
            provider = try backup.toProvider()
        } catch {
            logger.logError(error, context: "ImportService.importProvider")
            throw BackupError.corruptedFile
        }

        do {
            try await providerRepository.save(provider, personId: backup.personId, primaryKey: primaryKey)
        } catch {
            logger.logError(error, context: "ImportService.importProvider")
            throw BackupError.importFailed("Failed to save provider")
        }

        logger.exit("importProvider", duration: ContinuousClock.now - start)
    }
}
