import Foundation
@testable import FamilyMedicalApp

/// Mock implementation of MedicalRecordRepositoryProtocol for testing
final class MockMedicalRecordRepository: MedicalRecordRepositoryProtocol, @unchecked Sendable {
    // MARK: - Storage

    private var records: [UUID: MedicalRecord] = [:]

    // MARK: - Test Configuration

    var shouldFailSave = false
    var shouldFailFetch = false
    var shouldFailDelete = false
    var shouldFailExists = false

    // MARK: - Call Tracking

    var saveCallCount = 0
    var fetchCallCount = 0
    var fetchForPersonCallCount = 0
    var deleteCallCount = 0
    var existsCallCount = 0

    // MARK: - MedicalRecordRepositoryProtocol

    func save(_ record: MedicalRecord) async throws {
        saveCallCount += 1

        if shouldFailSave {
            throw RepositoryError.saveFailed("Mock save failed")
        }

        records[record.id] = record
    }

    func fetch(id: UUID) async throws -> MedicalRecord? {
        fetchCallCount += 1

        if shouldFailFetch {
            throw RepositoryError.fetchFailed("Mock fetch failed")
        }

        return records[id]
    }

    func fetchForPerson(personId: UUID) async throws -> [MedicalRecord] {
        fetchForPersonCallCount += 1

        if shouldFailFetch {
            throw RepositoryError.fetchFailed("Mock fetch for person failed")
        }

        return records.values.filter { $0.personId == personId }
    }

    func delete(id: UUID) async throws {
        deleteCallCount += 1

        if shouldFailDelete {
            throw RepositoryError.deleteFailed("Mock delete failed")
        }

        records.removeValue(forKey: id)
    }

    func exists(id: UUID) async throws -> Bool {
        existsCallCount += 1

        if shouldFailExists {
            throw RepositoryError.fetchFailed("Mock exists failed")
        }

        return records[id] != nil
    }

    // MARK: - Test Helpers

    func reset() {
        records.removeAll()
        shouldFailSave = false
        shouldFailFetch = false
        shouldFailDelete = false
        shouldFailExists = false
        saveCallCount = 0
        fetchCallCount = 0
        fetchForPersonCallCount = 0
        deleteCallCount = 0
        existsCallCount = 0
    }

    func addRecord(_ record: MedicalRecord) {
        records[record.id] = record
    }

    func getAllRecords() -> [MedicalRecord] {
        Array(records.values)
    }
}
