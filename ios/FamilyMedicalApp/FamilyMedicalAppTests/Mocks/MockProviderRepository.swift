import CryptoKit
import Foundation
@testable import FamilyMedicalApp

/// Mock implementation of ProviderRepositoryProtocol for testing
final class MockProviderRepository: ProviderRepositoryProtocol, @unchecked Sendable {
    // MARK: - Storage

    private var providers: [UUID: Provider] = [:]
    private var providerPersonMap: [UUID: UUID] = [:] // providerId -> personId

    // MARK: - Test Configuration

    var shouldFailSave = false
    var shouldFailFetch = false
    var shouldFailFetchAll = false
    var shouldFailDelete = false
    var shouldFailSearch = false

    // MARK: - Call Tracking

    var saveCallCount = 0
    var fetchCallCount = 0
    var fetchAllCallCount = 0
    var deleteCallCount = 0
    var searchCallCount = 0

    var lastSavedProvider: Provider?
    var lastSavedPersonId: UUID?
    var lastFetchedId: UUID?
    var lastDeletedId: UUID?
    var lastSearchQuery: String?

    // MARK: - ProviderRepositoryProtocol

    func save(_ provider: Provider, personId: UUID, primaryKey: SymmetricKey) async throws {
        saveCallCount += 1
        lastSavedProvider = provider
        lastSavedPersonId = personId

        if shouldFailSave {
            throw RepositoryError.saveFailed("Mock save failed")
        }

        providers[provider.id] = provider
        providerPersonMap[provider.id] = personId
    }

    func fetch(byId id: UUID, personId: UUID, primaryKey: SymmetricKey) async throws -> Provider? {
        fetchCallCount += 1
        lastFetchedId = id

        if shouldFailFetch {
            throw RepositoryError.fetchFailed("Mock fetch failed")
        }

        guard let provider = providers[id], providerPersonMap[id] == personId else {
            return nil
        }
        return provider
    }

    func fetchAll(forPerson personId: UUID, primaryKey: SymmetricKey) async throws -> [Provider] {
        fetchAllCallCount += 1

        if shouldFailFetchAll {
            throw RepositoryError.fetchFailed("Mock fetch all failed")
        }

        return providers.values
            .filter { providerPersonMap[$0.id] == personId }
            .sorted { ($0.name ?? "") < ($1.name ?? "") }
    }

    func delete(id: UUID) async throws {
        deleteCallCount += 1
        lastDeletedId = id

        if shouldFailDelete {
            throw RepositoryError.deleteFailed("Mock delete failed")
        }

        providers.removeValue(forKey: id)
        providerPersonMap.removeValue(forKey: id)
    }

    func search(query: String, forPerson personId: UUID, primaryKey: SymmetricKey) async throws -> [Provider] {
        searchCallCount += 1
        lastSearchQuery = query

        if shouldFailSearch {
            throw RepositoryError.fetchFailed("Mock search failed")
        }

        let lowercased = query.lowercased()
        return providers.values
            .filter { providerPersonMap[$0.id] == personId }
            .filter {
                ($0.name?.lowercased().contains(lowercased) ?? false) ||
                    ($0.organization?.lowercased().contains(lowercased) ?? false)
            }
            .sorted { ($0.name ?? "") < ($1.name ?? "") }
    }

    // MARK: - Test Helpers

    func reset() {
        providers.removeAll()
        providerPersonMap.removeAll()
        shouldFailSave = false
        shouldFailFetch = false
        shouldFailFetchAll = false
        shouldFailDelete = false
        shouldFailSearch = false
        saveCallCount = 0
        fetchCallCount = 0
        fetchAllCallCount = 0
        deleteCallCount = 0
        searchCallCount = 0
        lastSavedProvider = nil
        lastSavedPersonId = nil
        lastFetchedId = nil
        lastDeletedId = nil
        lastSearchQuery = nil
    }

    /// Add a provider directly (for test setup)
    func addProvider(_ provider: Provider, personId: UUID) {
        providers[provider.id] = provider
        providerPersonMap[provider.id] = personId
    }
}
