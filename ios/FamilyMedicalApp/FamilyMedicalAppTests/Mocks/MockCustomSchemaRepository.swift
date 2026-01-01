import CryptoKit
import Foundation
@testable import FamilyMedicalApp

/// Mock implementation of CustomSchemaRepositoryProtocol for testing
final class MockCustomSchemaRepository: CustomSchemaRepositoryProtocol, @unchecked Sendable {
    // MARK: - Storage

    private var schemas: [String: RecordSchema] = [:]

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
    var lastFetchedSchemaId: String?
    var lastDeletedSchemaId: String?

    // MARK: - CustomSchemaRepositoryProtocol

    func save(_ schema: RecordSchema, primaryKey: SymmetricKey) async throws {
        saveCallCount += 1
        lastSavedSchema = schema

        if shouldFailSave {
            throw RepositoryError.saveFailed("Mock save failed")
        }

        schemas[schema.id] = schema
    }

    func fetch(schemaId: String, primaryKey: SymmetricKey) async throws -> RecordSchema? {
        fetchCallCount += 1
        lastFetchedSchemaId = schemaId

        if shouldFailFetch {
            throw RepositoryError.fetchFailed("Mock fetch failed")
        }

        return schemas[schemaId]
    }

    func fetchAll(primaryKey: SymmetricKey) async throws -> [RecordSchema] {
        fetchAllCallCount += 1

        if shouldFailFetchAll {
            throw RepositoryError.fetchFailed("Mock fetch all failed")
        }

        return Array(schemas.values).sorted { $0.id < $1.id }
    }

    func delete(schemaId: String) async throws {
        deleteCallCount += 1
        lastDeletedSchemaId = schemaId

        if shouldFailDelete {
            throw RepositoryError.deleteFailed("Mock delete failed")
        }

        if schemas.removeValue(forKey: schemaId) == nil {
            throw RepositoryError.customSchemaNotFound(schemaId)
        }
    }

    func exists(schemaId: String) async throws -> Bool {
        existsCallCount += 1

        if shouldFailExists {
            throw RepositoryError.fetchFailed("Mock exists failed")
        }

        return schemas[schemaId] != nil
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
        lastFetchedSchemaId = nil
        lastDeletedSchemaId = nil
    }

    /// Get all schemas (without requiring primary key)
    func getAllSchemas() -> [RecordSchema] {
        Array(schemas.values).sorted { $0.id < $1.id }
    }

    /// Add a schema directly (for test setup)
    func addSchema(_ schema: RecordSchema) {
        schemas[schema.id] = schema
    }
}
