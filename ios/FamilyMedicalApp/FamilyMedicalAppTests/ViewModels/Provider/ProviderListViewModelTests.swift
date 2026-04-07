import CryptoKit
import Foundation
import Testing
@testable import FamilyMedicalApp

@MainActor
struct ProviderListViewModelTests {
    // MARK: - Test Data

    let testPrimaryKey = SymmetricKey(size: .bits256)

    func makeTestPerson() throws -> Person {
        try PersonTestHelper.makeTestPerson()
    }

    func makeViewModel(
        person: Person,
        repository: MockProviderRepository = MockProviderRepository(),
        primaryKeyProvider: MockPrimaryKeyProvider? = nil
    ) -> ProviderListViewModel {
        let keyProvider = primaryKeyProvider ?? MockPrimaryKeyProvider(primaryKey: testPrimaryKey)
        return ProviderListViewModel(
            person: person,
            providerRepository: repository,
            primaryKeyProvider: keyProvider
        )
    }

    // MARK: - Initialization Tests

    @Test
    func initializesWithEmptyState() throws {
        let person = try makeTestPerson()
        let viewModel = makeViewModel(person: person)

        #expect(viewModel.person.id == person.id)
        #expect(viewModel.providers.isEmpty)
        #expect(viewModel.searchText.isEmpty)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
    }

    // MARK: - Load Providers Tests

    @Test
    func loadProvidersPopulatesArray() async throws {
        let person = try makeTestPerson()
        let mockRepo = MockProviderRepository()

        let provider1 = Provider(name: "Dr. Smith", specialty: "Cardiology")
        let provider2 = Provider(organization: "City Hospital")
        mockRepo.addProvider(provider1, personId: person.id)
        mockRepo.addProvider(provider2, personId: person.id)

        let viewModel = makeViewModel(person: person, repository: mockRepo)

        await viewModel.loadProviders()

        #expect(viewModel.providers.count == 2)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.isLoading == false)
        #expect(mockRepo.fetchAllCallCount == 1)
    }

    @Test
    func loadProvidersSetsErrorWhenPrimaryKeyUnavailable() async throws {
        let person = try makeTestPerson()
        let failingKeyProvider = MockPrimaryKeyProvider(shouldFail: true)
        let viewModel = makeViewModel(
            person: person,
            primaryKeyProvider: failingKeyProvider
        )

        await viewModel.loadProviders()

        #expect(viewModel.providers.isEmpty)
        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.errorMessage?.contains("Unable to load providers") == true)
        #expect(viewModel.isLoading == false)
    }

    @Test
    func loadProvidersSetsErrorWhenRepositoryFails() async throws {
        let person = try makeTestPerson()
        let mockRepo = MockProviderRepository()
        mockRepo.shouldFailFetchAll = true

        let viewModel = makeViewModel(person: person, repository: mockRepo)

        await viewModel.loadProviders()

        #expect(viewModel.providers.isEmpty)
        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.isLoading == false)
    }

    @Test
    func loadProvidersReturnsEmptyWhenNoneExist() async throws {
        let person = try makeTestPerson()
        let viewModel = makeViewModel(person: person)

        await viewModel.loadProviders()

        #expect(viewModel.providers.isEmpty)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.isLoading == false)
    }

    // MARK: - Filtered Providers Tests

    @Test
    func filteredProvidersReturnsAllWhenSearchEmpty() async throws {
        let person = try makeTestPerson()
        let mockRepo = MockProviderRepository()

        let provider = Provider(name: "Dr. Smith")
        mockRepo.addProvider(provider, personId: person.id)

        let viewModel = makeViewModel(person: person, repository: mockRepo)
        await viewModel.loadProviders()

        #expect(viewModel.filteredProviders.count == 1)
    }

    @Test
    func filteredProvidersFiltersByName() async throws {
        let person = try makeTestPerson()
        let mockRepo = MockProviderRepository()

        mockRepo.addProvider(Provider(name: "Dr. Smith"), personId: person.id)
        mockRepo.addProvider(Provider(name: "Dr. Jones"), personId: person.id)

        let viewModel = makeViewModel(person: person, repository: mockRepo)
        await viewModel.loadProviders()

        viewModel.searchText = "Smith"

        #expect(viewModel.filteredProviders.count == 1)
        #expect(viewModel.filteredProviders.first?.name == "Dr. Smith")
    }

    @Test
    func filteredProvidersFiltersByOrganization() async throws {
        let person = try makeTestPerson()
        let mockRepo = MockProviderRepository()

        mockRepo.addProvider(Provider(name: "Dr. Smith", organization: "City Hospital"), personId: person.id)
        mockRepo.addProvider(Provider(organization: "County Clinic"), personId: person.id)

        let viewModel = makeViewModel(person: person, repository: mockRepo)
        await viewModel.loadProviders()

        viewModel.searchText = "clinic"

        #expect(viewModel.filteredProviders.count == 1)
        #expect(viewModel.filteredProviders.first?.organization == "County Clinic")
    }

    @Test
    func filteredProvidersFiltersBySpecialty() async throws {
        let person = try makeTestPerson()
        let mockRepo = MockProviderRepository()

        mockRepo.addProvider(Provider(name: "Dr. Smith", specialty: "Cardiology"), personId: person.id)
        mockRepo.addProvider(Provider(name: "Dr. Jones", specialty: "Dermatology"), personId: person.id)

        let viewModel = makeViewModel(person: person, repository: mockRepo)
        await viewModel.loadProviders()

        viewModel.searchText = "cardio"

        #expect(viewModel.filteredProviders.count == 1)
        #expect(viewModel.filteredProviders.first?.name == "Dr. Smith")
    }

    @Test
    func filteredProvidersIsCaseInsensitive() async throws {
        let person = try makeTestPerson()
        let mockRepo = MockProviderRepository()

        mockRepo.addProvider(Provider(name: "Dr. SMITH"), personId: person.id)

        let viewModel = makeViewModel(person: person, repository: mockRepo)
        await viewModel.loadProviders()

        viewModel.searchText = "smith"

        #expect(viewModel.filteredProviders.count == 1)
    }

    @Test
    func filteredProvidersReturnsEmptyForNoMatch() async throws {
        let person = try makeTestPerson()
        let mockRepo = MockProviderRepository()

        mockRepo.addProvider(Provider(name: "Dr. Smith"), personId: person.id)

        let viewModel = makeViewModel(person: person, repository: mockRepo)
        await viewModel.loadProviders()

        viewModel.searchText = "nonexistent"

        #expect(viewModel.filteredProviders.isEmpty)
    }

    // MARK: - Delete Provider Tests

    @Test
    func deleteProviderRemovesFromArray() async throws {
        let person = try makeTestPerson()
        let mockRepo = MockProviderRepository()

        let provider = Provider(name: "Dr. Smith")
        mockRepo.addProvider(provider, personId: person.id)

        let viewModel = makeViewModel(person: person, repository: mockRepo)
        await viewModel.loadProviders()

        #expect(viewModel.providers.count == 1)

        await viewModel.deleteProvider(id: provider.id)

        #expect(viewModel.providers.isEmpty)
        #expect(viewModel.errorMessage == nil)
        #expect(mockRepo.deleteCallCount == 1)
        #expect(mockRepo.lastDeletedId == provider.id)
    }

    @Test
    func deleteProviderSetsErrorOnFailure() async throws {
        let person = try makeTestPerson()
        let mockRepo = MockProviderRepository()
        mockRepo.shouldFailDelete = true

        let provider = Provider(name: "Dr. Smith")
        mockRepo.addProvider(provider, personId: person.id)

        let viewModel = makeViewModel(person: person, repository: mockRepo)
        await viewModel.loadProviders()

        await viewModel.deleteProvider(id: provider.id)

        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.errorMessage?.contains("Unable to delete provider") == true)
        // Provider should remain in the array on failure
        #expect(viewModel.providers.count == 1)
    }

    // MARK: - Save Provider Tests

    @Test
    func saveProviderCallsRepositoryAndReloads() async throws {
        let person = try makeTestPerson()
        let mockRepo = MockProviderRepository()

        let viewModel = makeViewModel(person: person, repository: mockRepo)

        let newProvider = Provider(name: "Dr. New")
        await viewModel.saveProvider(newProvider)

        #expect(mockRepo.saveCallCount == 1)
        #expect(mockRepo.lastSavedProvider?.name == "Dr. New")
        #expect(mockRepo.lastSavedPersonId == person.id)
        // After save, loadProviders is called so fetchAll should also be called
        #expect(mockRepo.fetchAllCallCount == 1)
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    func saveProviderSetsErrorOnFailure() async throws {
        let person = try makeTestPerson()
        let mockRepo = MockProviderRepository()
        mockRepo.shouldFailSave = true

        let viewModel = makeViewModel(person: person, repository: mockRepo)

        let newProvider = Provider(name: "Dr. New")
        await viewModel.saveProvider(newProvider)

        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.errorMessage?.contains("Unable to save provider") == true)
    }

    @Test
    func saveProviderSetsErrorWhenPrimaryKeyUnavailable() async throws {
        let person = try makeTestPerson()
        let failingKeyProvider = MockPrimaryKeyProvider(shouldFail: true)
        let viewModel = makeViewModel(
            person: person,
            primaryKeyProvider: failingKeyProvider
        )

        let newProvider = Provider(name: "Dr. New")
        await viewModel.saveProvider(newProvider)

        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.errorMessage?.contains("Unable to save provider") == true)
    }

    // MARK: - Multiple Person Isolation

    @Test
    func loadProvidersOnlyReturnsSamePersonProviders() async throws {
        let person1 = try PersonTestHelper.makeTestPerson(name: "Person 1")
        let person2 = try PersonTestHelper.makeTestPerson(name: "Person 2")
        let mockRepo = MockProviderRepository()

        mockRepo.addProvider(Provider(name: "Dr. Smith"), personId: person1.id)
        mockRepo.addProvider(Provider(name: "Dr. Jones"), personId: person2.id)

        let viewModel = makeViewModel(person: person1, repository: mockRepo)
        await viewModel.loadProviders()

        #expect(viewModel.providers.count == 1)
        #expect(viewModel.providers.first?.name == "Dr. Smith")
    }
}
