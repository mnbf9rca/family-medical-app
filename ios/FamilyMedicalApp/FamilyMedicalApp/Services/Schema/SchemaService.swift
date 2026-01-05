import CryptoKit
import Foundation

/// Protocol for schema access operations
protocol SchemaServiceProtocol: Sendable {
    /// Fetch a schema for a Person by schema ID
    ///
    /// Returns the Person's stored schema, or falls back to the hardcoded built-in
    /// schema if the Person doesn't have a stored copy yet.
    ///
    /// - Parameters:
    ///   - schemaId: The schema's logical ID (e.g., "vaccine", "prescription")
    ///   - personId: UUID of the Person who owns the schema
    ///   - familyMemberKey: Person's FMK for decryption
    /// - Returns: Schema if found, nil if not a known schema ID
    /// - Throws: RepositoryError on failure
    func schema(
        forId schemaId: String,
        personId: UUID,
        familyMemberKey: SymmetricKey
    ) async throws -> RecordSchema?

    /// Fetch all schemas for a Person
    ///
    /// Returns all stored schemas for the Person. If the Person has no stored
    /// schemas, returns the hardcoded built-in schemas as fallback.
    ///
    /// - Parameters:
    ///   - personId: UUID of the Person who owns the schemas
    ///   - familyMemberKey: Person's FMK for decryption
    /// - Returns: Array of all schemas for this Person
    /// - Throws: RepositoryError on failure
    func allSchemas(
        forPerson personId: UUID,
        familyMemberKey: SymmetricKey
    ) async throws -> [RecordSchema]

    /// Fetch all built-in schemas for a Person
    ///
    /// Returns only the built-in schema types (vaccine, prescription, etc.),
    /// excluding any user-created custom schemas.
    ///
    /// - Parameters:
    ///   - personId: UUID of the Person who owns the schemas
    ///   - familyMemberKey: Person's FMK for decryption
    /// - Returns: Array of built-in schemas for this Person
    /// - Throws: RepositoryError on failure
    func builtInSchemas(
        forPerson personId: UUID,
        familyMemberKey: SymmetricKey
    ) async throws -> [RecordSchema]

    /// Save a schema for a Person
    ///
    /// - Parameters:
    ///   - schema: Schema to save
    ///   - personId: UUID of the Person who owns the schema
    ///   - familyMemberKey: Person's FMK for encryption
    /// - Throws: RepositoryError on failure
    func save(
        _ schema: RecordSchema,
        forPerson personId: UUID,
        familyMemberKey: SymmetricKey
    ) async throws
}

/// Service providing unified schema access for Persons
///
/// This is the single source of truth for schema access. It fetches schemas
/// from the repository with fallback to hardcoded built-in schemas when needed.
/// Views and view models should use this service rather than accessing the
/// repository directly.
final class SchemaService: SchemaServiceProtocol, @unchecked Sendable {
    // MARK: - Dependencies

    private let schemaRepository: CustomSchemaRepositoryProtocol

    // MARK: - Initialization

    init(schemaRepository: CustomSchemaRepositoryProtocol) {
        self.schemaRepository = schemaRepository
    }

    // MARK: - SchemaServiceProtocol

    func schema(
        forId schemaId: String,
        personId: UUID,
        familyMemberKey: SymmetricKey
    ) async throws -> RecordSchema? {
        // Try to fetch from repository
        if let stored = try await schemaRepository.fetch(
            schemaId: schemaId,
            forPerson: personId,
            familyMemberKey: familyMemberKey
        ) {
            return stored
        }

        // Fall back to hardcoded built-in schema if it exists
        if let builtInType = BuiltInSchemaType(rawValue: schemaId) {
            return builtInType.schema
        }

        return nil
    }

    func allSchemas(
        forPerson personId: UUID,
        familyMemberKey: SymmetricKey
    ) async throws -> [RecordSchema] {
        let stored = try await schemaRepository.fetchAll(
            forPerson: personId,
            familyMemberKey: familyMemberKey
        )

        // If Person has stored schemas, return those
        if !stored.isEmpty {
            return stored
        }

        // Fall back to hardcoded built-in schemas
        return BuiltInSchemaType.allCases.map(\.schema)
    }

    func builtInSchemas(
        forPerson personId: UUID,
        familyMemberKey: SymmetricKey
    ) async throws -> [RecordSchema] {
        let allSchemas = try await self.allSchemas(
            forPerson: personId,
            familyMemberKey: familyMemberKey
        )

        // Filter to only built-in schema types
        let builtInIds = Set(BuiltInSchemaType.allCases.map(\.rawValue))
        return allSchemas.filter { builtInIds.contains($0.id) }
    }

    func save(
        _ schema: RecordSchema,
        forPerson personId: UUID,
        familyMemberKey: SymmetricKey
    ) async throws {
        try await schemaRepository.save(
            schema,
            forPerson: personId,
            familyMemberKey: familyMemberKey
        )
    }
}
