import CryptoKit
import Foundation

/// Protocol for seeding schemas to a Person's schema set
protocol SchemaSeederProtocol: Sendable {
    /// Seed all built-in schemas for a newly created Person
    ///
    /// This method is called when a Person is created. It creates copies of all
    /// built-in schemas and stores them encrypted with the Person's FamilyMemberKey.
    ///
    /// - Parameters:
    ///   - personId: UUID of the Person to seed schemas for
    ///   - familyMemberKey: Person's FMK for encryption
    /// - Throws: RepositoryError on failure
    func seedBuiltInSchemas(forPerson personId: UUID, familyMemberKey: SymmetricKey) async throws

    /// Check if a Person has their schemas seeded
    ///
    /// - Parameters:
    ///   - personId: UUID of the Person
    ///   - familyMemberKey: Person's FMK for decryption
    /// - Returns: true if the Person has at least one schema
    func hasSchemas(forPerson personId: UUID, familyMemberKey: SymmetricKey) async throws -> Bool
}

/// Service that seeds built-in schemas for Persons
///
/// When a new Person is created, this service creates copies of all built-in
/// schemas and stores them in the repository, encrypted with the Person's FMK.
/// This allows each Person to have independent schema definitions that can be
/// customized without affecting other Persons.
final class SchemaSeeder: SchemaSeederProtocol, @unchecked Sendable {
    // MARK: - Dependencies

    private let schemaRepository: CustomSchemaRepositoryProtocol

    // MARK: - Initialization

    init(schemaRepository: CustomSchemaRepositoryProtocol) {
        self.schemaRepository = schemaRepository
    }

    // MARK: - SchemaSeederProtocol

    func seedBuiltInSchemas(forPerson personId: UUID, familyMemberKey: SymmetricKey) async throws {
        // Get all built-in schemas
        let builtInSchemas = BuiltInSchemaType.allCases.map(\.schema)

        // Save each schema for this Person
        for schema in builtInSchemas {
            try await schemaRepository.save(
                schema,
                forPerson: personId,
                familyMemberKey: familyMemberKey
            )
        }
    }

    func hasSchemas(forPerson personId: UUID, familyMemberKey: SymmetricKey) async throws -> Bool {
        let schemas = try await schemaRepository.fetchAll(
            forPerson: personId,
            familyMemberKey: familyMemberKey
        )
        return !schemas.isEmpty
    }
}
