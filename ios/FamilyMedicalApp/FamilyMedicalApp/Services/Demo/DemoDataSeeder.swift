import CryptoKit
import Foundation

/// Protocol for seeding demo data
protocol DemoDataSeederProtocol: Sendable {
    /// Seed sample data for demo mode
    /// - Parameter primaryKey: Demo account's primary key
    func seedDemoData(primaryKey: SymmetricKey) async throws
}

/// Service that imports demo data from bundled JSON file
final class DemoDataSeeder: DemoDataSeederProtocol, @unchecked Sendable {
    // MARK: - Dependencies

    private let demoDataLoader: DemoDataLoaderProtocol
    private let importService: ImportServiceProtocol
    private let logger: CategoryLoggerProtocol

    // MARK: - Initialization

    init(
        demoDataLoader: DemoDataLoaderProtocol = DemoDataLoader(),
        importService: ImportServiceProtocol? = nil,
        logger: CategoryLoggerProtocol? = nil
    ) {
        self.demoDataLoader = demoDataLoader
        self.importService = importService ?? Self.makeDefaultImportService()
        self.logger = logger ?? LoggingService.shared.logger(category: .storage)
    }

    // MARK: - DemoDataSeederProtocol

    func seedDemoData(primaryKey: SymmetricKey) async throws {
        logger.logOperation("seedDemoData", state: "started")

        // Load demo data from bundled JSON
        let payload = try demoDataLoader.loadDemoData()

        // Import using standard import service
        try await importService.importData(payload, primaryKey: primaryKey)

        logger.logOperation("seedDemoData", state: "completed")
        logger.info("Seeded \(payload.persons.count) demo persons, \(payload.records.count) records")
    }

    // MARK: - Factory

    private static func makeDefaultImportService() -> ImportServiceProtocol {
        let coreDataStack = CoreDataStack.shared
        let encryptionService = EncryptionService()
        let fmkService = FamilyMemberKeyService()

        // AttachmentFileStorageService init can throw, but if it fails we have bigger problems
        // Use fatalError since this is called during app initialization
        let fileStorage: AttachmentFileStorageServiceProtocol
        do {
            fileStorage = try AttachmentFileStorageService()
        } catch {
            fatalError("Failed to initialize attachment file storage: \(error)")
        }

        return ImportService(
            personRepository: PersonRepository(
                coreDataStack: coreDataStack,
                encryptionService: encryptionService,
                fmkService: fmkService
            ),
            recordRepository: MedicalRecordRepository(
                coreDataStack: coreDataStack
            ),
            recordContentService: RecordContentService(encryptionService: encryptionService),
            attachmentService: AttachmentService(
                attachmentRepository: AttachmentRepository(
                    coreDataStack: coreDataStack,
                    encryptionService: encryptionService,
                    fmkService: fmkService
                ),
                fileStorage: fileStorage,
                imageProcessor: ImageProcessingService(),
                encryptionService: encryptionService,
                fmkService: fmkService
            ),
            customSchemaRepository: CustomSchemaRepository(
                coreDataStack: coreDataStack,
                encryptionService: encryptionService
            ),
            fmkService: fmkService
        )
    }
}
