import CryptoKit
import Foundation
@testable import FamilyMedicalApp

/// Mock implementation of PersonRepositoryProtocol for testing
final class MockPersonRepository: PersonRepositoryProtocol, @unchecked Sendable {
    // MARK: - Storage

    private var persons: [UUID: Person] = [:]

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

    var lastSavedPerson: Person?
    var lastFetchedId: UUID?
    var lastDeletedId: UUID?

    // MARK: - PersonRepositoryProtocol

    func save(_ person: Person, primaryKey: SymmetricKey) async throws {
        saveCallCount += 1
        lastSavedPerson = person

        if shouldFailSave {
            throw RepositoryError.saveFailed("Mock save failed")
        }

        persons[person.id] = person
    }

    func fetch(id: UUID, primaryKey: SymmetricKey) async throws -> Person? {
        fetchCallCount += 1
        lastFetchedId = id

        if shouldFailFetch {
            throw RepositoryError.fetchFailed("Mock fetch failed")
        }

        return persons[id]
    }

    func fetchAll(primaryKey: SymmetricKey) async throws -> [Person] {
        fetchAllCallCount += 1

        if shouldFailFetchAll {
            throw RepositoryError.fetchFailed("Mock fetch all failed")
        }

        return Array(persons.values).sorted { $0.name < $1.name }
    }

    func delete(id: UUID) async throws {
        deleteCallCount += 1
        lastDeletedId = id

        if shouldFailDelete {
            throw RepositoryError.deleteFailed("Mock delete failed")
        }

        persons.removeValue(forKey: id)
    }

    func exists(id: UUID) async throws -> Bool {
        existsCallCount += 1

        if shouldFailExists {
            throw RepositoryError.fetchFailed("Mock exists failed")
        }

        return persons[id] != nil
    }

    // MARK: - Test Helpers

    /// Reset the mock to initial state
    func reset() {
        persons.removeAll()
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
        lastSavedPerson = nil
        lastFetchedId = nil
        lastDeletedId = nil
    }

    /// Get all persons (without requiring primary key)
    func getAllPersons() -> [Person] {
        Array(persons.values).sorted { $0.name < $1.name }
    }

    /// Add a person directly (for test setup)
    func addPerson(_ person: Person) {
        persons[person.id] = person
    }
}
