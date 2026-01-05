import CryptoKit
import Foundation
@testable import FamilyMedicalApp

/// Mock implementation of CustomSchemaRepositoryProtocol for testing
///
/// Stores schemas per-Person to match the real repository behavior.
final class MockCustomSchemaRepository: CustomSchemaRepositoryProtocol, @unchecked Sendable {
    // MARK: - Storage

    /// Schemas stored as [personId: [schemaId: RecordSchema]]
    private var schemas: [UUID: [String: RecordSchema]] = [:]

    // MARK: - Test Configuration

    var shouldFailSave = false
    var shouldFailFetch = false
    var shouldFailFetchAll = false
    var shouldFailDelete = false
    var shouldFailExists = false

    // MARK: - Call Tracking

    var saveCallCount = 0
    var fetchCallCount = 0
    var fetchAllCallCount = 0
    var deleteCallCount = 0
    var existsCallCount = 0

    var lastSavedSchema: RecordSchema?
    var lastSavedPersonId: UUID?
    var lastFetchedSchemaId: String?
    var lastFetchedPersonId: UUID?
    var lastDeletedSchemaId: String?
    var lastDeletedPersonId: UUID?

    // MARK: - CustomSchemaRepositoryProtocol

    func save(_ schema: RecordSchema, forPerson personId: UUID, familyMemberKey: SymmetricKey) async throws {
        saveCallCount += 1
        lastSavedSchema = schema
        lastSavedPersonId = personId

        if shouldFailSave {
            throw RepositoryError.saveFailed("Mock save failed")
        }

        if schemas[personId] == nil {
            schemas[personId] = [:]
        }
        schemas[personId]?[schema.id] = schema
    }

    func fetch(
        schemaId: String,
        forPerson personId: UUID,
        familyMemberKey: SymmetricKey
    ) async throws -> RecordSchema? {
        fetchCallCount += 1
        lastFetchedSchemaId = schemaId
        lastFetchedPersonId = personId

        if shouldFailFetch {
            throw RepositoryError.fetchFailed("Mock fetch failed")
        }

        return schemas[personId]?[schemaId]
    }

    func fetchAll(forPerson personId: UUID, familyMemberKey: SymmetricKey) async throws -> [RecordSchema] {
        fetchAllCallCount += 1

        if shouldFailFetchAll {
            throw RepositoryError.fetchFailed("Mock fetch all failed")
        }

        guard let personSchemas = schemas[personId] else {
            return []
        }
        return Array(personSchemas.values).sorted { $0.id < $1.id }
    }

    func delete(schemaId: String, forPerson personId: UUID) async throws {
        deleteCallCount += 1
        lastDeletedSchemaId = schemaId
        lastDeletedPersonId = personId

        if shouldFailDelete {
            throw RepositoryError.deleteFailed("Mock delete failed")
        }

        if schemas[personId]?.removeValue(forKey: schemaId) == nil {
            throw RepositoryError.customSchemaNotFound(schemaId)
        }
    }

    func exists(schemaId: String, forPerson personId: UUID) async throws -> Bool {
        existsCallCount += 1

        if shouldFailExists {
            throw RepositoryError.fetchFailed("Mock exists failed")
        }

        return schemas[personId]?[schemaId] != nil
    }

    // MARK: - Test Helpers

    /// Reset the mock to initial state
    func reset() {
        schemas.removeAll()
        shouldFailSave = false
        shouldFailFetch = false
        shouldFailFetchAll = false
        shouldFailDelete = false
        shouldFailExists = false
        saveCallCount = 0
        fetchCallCount = 0
        fetchAllCallCount = 0
        deleteCallCount = 0
        existsCallCount = 0
        lastSavedSchema = nil
        lastSavedPersonId = nil
        lastFetchedSchemaId = nil
        lastFetchedPersonId = nil
        lastDeletedSchemaId = nil
        lastDeletedPersonId = nil
    }

    /// Get all schemas for a person (without requiring key)
    func getAllSchemas(forPerson personId: UUID) -> [RecordSchema] {
        guard let personSchemas = schemas[personId] else {
            return []
        }
        return Array(personSchemas.values).sorted { $0.id < $1.id }
    }

    /// Add a schema directly for a person (for test setup)
    func addSchema(_ schema: RecordSchema, forPerson personId: UUID) {
        if schemas[personId] == nil {
            schemas[personId] = [:]
        }
        schemas[personId]?[schema.id] = schema
    }
}
