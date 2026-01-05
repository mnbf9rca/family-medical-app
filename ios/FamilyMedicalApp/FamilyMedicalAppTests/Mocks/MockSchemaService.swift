import CryptoKit
import Foundation
@testable import FamilyMedicalApp

/// Mock implementation of SchemaServiceProtocol for testing
final class MockSchemaService: SchemaServiceProtocol, @unchecked Sendable {
    // MARK: - Storage

    /// Schemas stored as [personId: [schemaId: RecordSchema]]
    private var schemas: [UUID: [String: RecordSchema]] = [:]

    // MARK: - Test Configuration

    var shouldFailFetch = false
    var shouldFailFetchAll = false
    var shouldFailSave = false

    // MARK: - Call Tracking

    var schemaCallCount = 0
    var allSchemasCallCount = 0
    var builtInSchemasCallCount = 0
    var saveCallCount = 0
    var lastFetchedSchemaId: String?
    var lastFetchedPersonId: UUID?
    var lastSavedSchema: RecordSchema?

    // MARK: - SchemaServiceProtocol

    func schema(
        forId schemaId: String,
        personId: UUID,
        familyMemberKey: SymmetricKey
    ) async throws -> RecordSchema? {
        schemaCallCount += 1
        lastFetchedSchemaId = schemaId
        lastFetchedPersonId = personId

        if shouldFailFetch {
            throw RepositoryError.fetchFailed("Mock fetch failed")
        }

        // Check stored schemas first
        if let stored = schemas[personId]?[schemaId] {
            return stored
        }

        // Fall back to built-in schema
        return BuiltInSchemaType(rawValue: schemaId)?.schema
    }

    func allSchemas(
        forPerson personId: UUID,
        familyMemberKey: SymmetricKey
    ) async throws -> [RecordSchema] {
        allSchemasCallCount += 1

        if shouldFailFetchAll {
            throw RepositoryError.fetchFailed("Mock fetchAll failed")
        }

        // Return stored schemas if any
        if let stored = schemas[personId], !stored.isEmpty {
            return Array(stored.values).sorted { $0.id < $1.id }
        }

        // Fall back to built-in schemas
        return BuiltInSchemaType.allCases.map(\.schema)
    }

    func builtInSchemas(
        forPerson personId: UUID,
        familyMemberKey: SymmetricKey
    ) async throws -> [RecordSchema] {
        builtInSchemasCallCount += 1

        if shouldFailFetchAll {
            throw RepositoryError.fetchFailed("Mock builtInSchemas failed")
        }

        let allSchemas = try await self.allSchemas(forPerson: personId, familyMemberKey: familyMemberKey)
        let builtInIds = Set(BuiltInSchemaType.allCases.map(\.rawValue))
        return allSchemas.filter { builtInIds.contains($0.id) }
    }

    func save(
        _ schema: RecordSchema,
        forPerson personId: UUID,
        familyMemberKey: SymmetricKey
    ) async throws {
        saveCallCount += 1
        lastSavedSchema = schema

        if shouldFailSave {
            throw RepositoryError.saveFailed("Mock save failed")
        }

        if schemas[personId] == nil {
            schemas[personId] = [:]
        }
        schemas[personId]?[schema.id] = schema
    }

    // MARK: - Test Helpers

    func reset() {
        schemas.removeAll()
        shouldFailFetch = false
        shouldFailFetchAll = false
        shouldFailSave = false
        schemaCallCount = 0
        allSchemasCallCount = 0
        builtInSchemasCallCount = 0
        saveCallCount = 0
        lastFetchedSchemaId = nil
        lastFetchedPersonId = nil
        lastSavedSchema = nil
    }

    /// Add a schema directly (for test setup)
    func addSchema(_ schema: RecordSchema, forPerson personId: UUID) {
        if schemas[personId] == nil {
            schemas[personId] = [:]
        }
        schemas[personId]?[schema.id] = schema
    }
}
