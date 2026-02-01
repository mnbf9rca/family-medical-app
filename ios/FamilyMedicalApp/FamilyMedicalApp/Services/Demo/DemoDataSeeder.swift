import CryptoKit
import Foundation

/// Configuration for a demo person
struct DemoPersonConfig {
    let name: String
    let labels: [String]
    let notes: String?
}

/// Protocol for seeding demo data
protocol DemoDataSeederProtocol: Sendable {
    /// Seed sample data for demo mode
    /// - Parameter primaryKey: Demo account's primary key
    func seedDemoData(primaryKey: SymmetricKey) async throws
}

/// Service that creates sample data for demo mode
final class DemoDataSeeder: DemoDataSeederProtocol, @unchecked Sendable {
    // MARK: - Demo Data Templates

    /// Pre-defined demo persons for sample data
    static let demoPersons: [DemoPersonConfig] = [
        DemoPersonConfig(
            name: "Alex Johnson",
            labels: ["Self"],
            notes: "Demo account holder"
        ),
        DemoPersonConfig(
            name: "Sam Johnson",
            labels: ["Spouse", "Household Member"],
            notes: nil
        ),
        DemoPersonConfig(
            name: "Jamie Johnson",
            labels: ["Child", "Dependent"],
            notes: "Age 8"
        )
    ]

    // MARK: - Dependencies

    private let personRepository: PersonRepositoryProtocol
    private let schemaSeeder: SchemaSeederProtocol
    private let fmkService: FamilyMemberKeyServiceProtocol
    private let logger: CategoryLoggerProtocol

    // MARK: - Initialization

    init(
        personRepository: PersonRepositoryProtocol,
        schemaSeeder: SchemaSeederProtocol,
        fmkService: FamilyMemberKeyServiceProtocol,
        logger: CategoryLoggerProtocol? = nil
    ) {
        self.personRepository = personRepository
        self.schemaSeeder = schemaSeeder
        self.fmkService = fmkService
        self.logger = logger ?? LoggingService.shared.logger(category: .storage)
    }

    // MARK: - DemoDataSeederProtocol

    func seedDemoData(primaryKey: SymmetricKey) async throws {
        logger.logOperation("seedDemoData", state: "started")

        for personConfig in Self.demoPersons {
            // Create person
            let person = try Person(
                name: personConfig.name,
                labels: personConfig.labels,
                notes: personConfig.notes
            )

            // Generate and store FMK for this person
            let fmk = fmkService.generateFMK()
            try fmkService.storeFMK(
                fmk,
                familyMemberID: person.id.uuidString,
                primaryKey: primaryKey
            )

            // Save person (encrypted with FMK via repository)
            try await personRepository.save(person, primaryKey: primaryKey)

            // Seed schemas for this person
            try await schemaSeeder.seedBuiltInSchemas(
                forPerson: person.id,
                familyMemberKey: fmk
            )

            logger.debug("Created demo person: \(personConfig.name)")
        }

        logger.logOperation("seedDemoData", state: "completed")
        logger.info("Seeded \(Self.demoPersons.count) demo persons")
    }
}
