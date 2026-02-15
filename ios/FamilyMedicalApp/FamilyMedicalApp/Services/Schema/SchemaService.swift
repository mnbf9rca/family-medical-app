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
    private let logger: TracingCategoryLogger

    // MARK: - Initialization

    init(schemaRepository: CustomSchemaRepositoryProtocol, logger: CategoryLoggerProtocol? = nil) {
        self.schemaRepository = schemaRepository
        self.logger = TracingCategoryLogger(
            wrapping: logger ?? LoggingService.shared.logger(category: .storage)
        )
    }

    // MARK: - SchemaServiceProtocol

    func schema(
        forId schemaId: String,
        personId: UUID,
        familyMemberKey: SymmetricKey
    ) async throws -> RecordSchema? {
        let start = ContinuousClock.now
        logger.entry("schema(forId:)", "schemaId=\(schemaId)")
        // Try to fetch from repository
        if let stored = try await schemaRepository.fetch(
            schemaId: schemaId,
            forPerson: personId,
            familyMemberKey: familyMemberKey
        ) {
            logger.exit("schema(forId:)", duration: ContinuousClock.now - start)
            return stored
        }

        // Fall back to hardcoded built-in schema if it exists
        if let builtInType = BuiltInSchemaType(rawValue: schemaId) {
            logger.exit("schema(forId:)", duration: ContinuousClock.now - start)
            return builtInType.schema
        }

        logger.exit("schema(forId:)", duration: ContinuousClock.now - start)
        return nil
    }

    func allSchemas(
        forPerson personId: UUID,
        familyMemberKey: SymmetricKey
    ) async throws -> [RecordSchema] {
        let start = ContinuousClock.now
        logger.entry("allSchemas(forPerson:)")
        let stored = try await schemaRepository.fetchAll(
            forPerson: personId,
            familyMemberKey: familyMemberKey
        )

        // If Person has stored schemas, return those
        if !stored.isEmpty {
            logger.exit("allSchemas(forPerson:)", duration: ContinuousClock.now - start)
            return stored
        }

        // Fall back to hardcoded built-in schemas
        let result = BuiltInSchemaType.allCases.map(\.schema)
        logger.exit("allSchemas(forPerson:)", duration: ContinuousClock.now - start)
        return result
    }

    func builtInSchemas(
        forPerson personId: UUID,
        familyMemberKey: SymmetricKey
    ) async throws -> [RecordSchema] {
        let start = ContinuousClock.now
        logger.entry("builtInSchemas(forPerson:)")
        let allSchemas = try await self.allSchemas(
            forPerson: personId,
            familyMemberKey: familyMemberKey
        )

        // Filter to only built-in schema types
        let builtInIds = Set(BuiltInSchemaType.allCases.map(\.rawValue))
        let result = allSchemas.filter { builtInIds.contains($0.id) }
        logger.exit("builtInSchemas(forPerson:)", duration: ContinuousClock.now - start)
        return result
    }

    func save(
        _ schema: RecordSchema,
        forPerson personId: UUID,
        familyMemberKey: SymmetricKey
    ) async throws {
        let start = ContinuousClock.now
        logger.entry("save", "schemaId=\(schema.id)")
        try await schemaRepository.save(
            schema,
            forPerson: personId,
            familyMemberKey: familyMemberKey
        )
        logger.exit("save", duration: ContinuousClock.now - start)
    }
}
