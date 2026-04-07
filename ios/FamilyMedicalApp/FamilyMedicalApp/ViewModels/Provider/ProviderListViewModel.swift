import CryptoKit
import Foundation
import Observation

/// ViewModel for displaying and managing a list of providers for a person
@MainActor
@Observable
final class ProviderListViewModel {
    // MARK: - State

    let person: Person
    var providers: [Provider] = []
    var searchText = ""
    var isLoading = false
    var errorMessage: String?

    // MARK: - Dependencies

    private let providerRepository: ProviderRepositoryProtocol
    private let primaryKeyProvider: PrimaryKeyProviderProtocol
    private let logger: TracingCategoryLogger

    // MARK: - Initialization

    init(
        person: Person,
        providerRepository: ProviderRepositoryProtocol? = nil,
        primaryKeyProvider: PrimaryKeyProviderProtocol? = nil,
        logger: CategoryLoggerProtocol? = nil
    ) {
        self.person = person
        self.providerRepository = providerRepository ?? ProviderRepository(
            coreDataStack: CoreDataStack.shared,
            encryptionService: EncryptionService(),
            fmkService: FamilyMemberKeyService()
        )
        self.primaryKeyProvider = primaryKeyProvider ?? PrimaryKeyProvider()
        self.logger = TracingCategoryLogger(
            wrapping: logger ?? LoggingService.shared.logger(category: .storage)
        )
    }

    // MARK: - Computed Properties

    var filteredProviders: [Provider] {
        guard !searchText.isEmpty else { return providers }
        let query = searchText.lowercased()
        return providers.filter { provider in
            let nameMatch = provider.name?.lowercased().contains(query) ?? false
            let orgMatch = provider.organization?.lowercased().contains(query) ?? false
            let specialtyMatch = provider.specialty?.lowercased().contains(query) ?? false
            return nameMatch || orgMatch || specialtyMatch
        }
    }

    // MARK: - Actions

    func loadProviders() async {
        let start = ContinuousClock.now
        logger.entry("loadProviders", "personId=\(person.id)")

        isLoading = true
        errorMessage = nil

        do {
            let primaryKey = try primaryKeyProvider.getPrimaryKey()
            providers = try await providerRepository.fetchAll(
                forPerson: person.id,
                primaryKey: primaryKey
            )
            logger.exit("loadProviders", duration: ContinuousClock.now - start)
        } catch {
            errorMessage = "Unable to load providers. Please try again."
            logger.exitWithError("loadProviders", error: error, duration: ContinuousClock.now - start)
        }

        isLoading = false
    }

    func saveProvider(_ provider: Provider) async {
        let start = ContinuousClock.now
        logger.entry("saveProvider", "providerId=\(provider.id)")

        isLoading = true
        errorMessage = nil

        do {
            let primaryKey = try primaryKeyProvider.getPrimaryKey()
            try await providerRepository.save(provider, personId: person.id, primaryKey: primaryKey)
            await loadProviders()
            logger.exit("saveProvider", duration: ContinuousClock.now - start)
        } catch {
            errorMessage = "Unable to save provider. Please try again."
            logger.exitWithError("saveProvider", error: error, duration: ContinuousClock.now - start)
        }

        isLoading = false
    }

    func deleteProvider(id: UUID) async {
        let start = ContinuousClock.now
        logger.entry("deleteProvider", "providerId=\(id)")

        isLoading = true
        errorMessage = nil

        do {
            try await providerRepository.delete(id: id)
            providers.removeAll { $0.id == id }
            logger.exit("deleteProvider", duration: ContinuousClock.now - start)
        } catch {
            errorMessage = "Unable to delete provider. Please try again."
            logger.exitWithError("deleteProvider", error: error, duration: ContinuousClock.now - start)
        }

        isLoading = false
    }
}
