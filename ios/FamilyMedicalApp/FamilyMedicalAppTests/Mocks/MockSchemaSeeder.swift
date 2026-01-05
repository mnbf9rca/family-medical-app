import CryptoKit
import Foundation
@testable import FamilyMedicalApp

/// Mock implementation of SchemaSeederProtocol for testing
final class MockSchemaSeeder: SchemaSeederProtocol, @unchecked Sendable {
    // MARK: - Storage

    /// Track which Persons have been seeded
    private var seededPersons: Set<UUID> = []

    // MARK: - Test Configuration

    var shouldFailSeed = false
    var shouldFailHasSchemas = false

    // MARK: - Call Tracking

    var seedCallCount = 0
    var hasSchemasCallCount = 0
    var lastSeededPersonId: UUID?

    // MARK: - SchemaSeederProtocol

    func seedBuiltInSchemas(forPerson personId: UUID, familyMemberKey: SymmetricKey) async throws {
        seedCallCount += 1
        lastSeededPersonId = personId

        if shouldFailSeed {
            throw RepositoryError.saveFailed("Mock seed failed")
        }

        seededPersons.insert(personId)
    }

    func hasSchemas(forPerson personId: UUID, familyMemberKey: SymmetricKey) async throws -> Bool {
        hasSchemasCallCount += 1

        if shouldFailHasSchemas {
            throw RepositoryError.fetchFailed("Mock hasSchemas failed")
        }

        return seededPersons.contains(personId)
    }

    // MARK: - Test Helpers

    func reset() {
        seededPersons.removeAll()
        shouldFailSeed = false
        shouldFailHasSchemas = false
        seedCallCount = 0
        hasSchemasCallCount = 0
        lastSeededPersonId = nil
    }

    /// Mark a Person as seeded (for test setup)
    func markAsSeeded(personId: UUID) {
        seededPersons.insert(personId)
    }
}
