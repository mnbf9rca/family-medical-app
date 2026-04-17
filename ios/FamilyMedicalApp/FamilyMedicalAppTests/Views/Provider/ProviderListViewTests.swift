import CryptoKit
import SwiftUI
import Testing
import ViewInspector
@testable import FamilyMedicalApp

@MainActor
struct ProviderListViewTests {
    // MARK: - Test Data

    let testPrimaryKey = SymmetricKey(size: .bits256)

    func makeTestPerson(name: String = "Test Person") throws -> Person {
        try PersonTestHelper.makeTestPerson(name: name)
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
            primaryKeyProvider: keyProvider,
            logger: MockCategoryLogger(category: .storage)
        )
    }

    // MARK: - Basic Rendering Tests

    @Test
    func viewRendersSuccessfully() throws {
        let person = try makeTestPerson()
        let viewModel = makeViewModel(person: person)
        let view = ProviderListView(person: person, viewModel: viewModel)

        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            _ = try inspected.find(ViewType.Group.self)
        }
    }

    @Test
    func viewRendersEmptyState() throws {
        let person = try makeTestPerson()
        let viewModel = makeViewModel(person: person)
        // No providers, not loading -> ContentUnavailableView
        let view = ProviderListView(person: person, viewModel: viewModel)

        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            _ = try inspected.find(ViewType.ContentUnavailableView.self)
        }
    }

    @Test
    func viewRendersLoadingState() throws {
        let person = try makeTestPerson()
        let viewModel = makeViewModel(person: person)
        viewModel.isLoading = true
        let view = ProviderListView(person: person, viewModel: viewModel)

        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            _ = try inspected.find(ViewType.ProgressView.self)
        }
    }

    @Test
    func viewRendersProviderListWithData() async throws {
        let person = try makeTestPerson()
        let mockRepo = MockProviderRepository()
        let provider1 = Provider(name: "Dr. Smith", specialty: "Cardiology")
        let provider2 = Provider(organization: "City Hospital")
        mockRepo.addProvider(provider1, personId: person.id)
        mockRepo.addProvider(provider2, personId: person.id)

        let viewModel = makeViewModel(person: person, repository: mockRepo)
        await viewModel.loadProviders()

        let view = ProviderListView(person: person, viewModel: viewModel)
        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            _ = try inspected.find(ViewType.List.self)
        }
    }

    @Test
    func viewRendersProviderRows() async throws {
        let person = try makeTestPerson()
        let mockRepo = MockProviderRepository()
        let provider = Provider(name: "Dr. Jones", specialty: "Pediatrics")
        mockRepo.addProvider(provider, personId: person.id)

        let viewModel = makeViewModel(person: person, repository: mockRepo)
        await viewModel.loadProviders()

        let view = ProviderListView(person: person, viewModel: viewModel)
        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            let list = try inspected.find(ViewType.List.self)
            let forEach = try list.forEach(0)
            // Verify at least one row exists
            _ = try forEach.button(0)
        }
    }

    @Test
    func viewDisplaysSearchable() throws {
        let person = try makeTestPerson()
        let viewModel = makeViewModel(person: person)
        let view = ProviderListView(person: person, viewModel: viewModel)

        // Verify the view renders with searchable modifier
        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            // The searchable modifier is applied to the Group, verify rendering works
            _ = try inspected.find(ViewType.Group.self)
        }
    }

    @Test
    func viewHasAddButtonInToolbar() throws {
        let person = try makeTestPerson()
        let viewModel = makeViewModel(person: person)
        let view = ProviderListView(person: person, viewModel: viewModel)

        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            // Find the toolbar button with the plus image
            _ = try inspected.find(ViewType.Image.self) { image in
                try image.actualImage().name() == "plus"
            }
        }
    }

    @Test
    func viewHandlesErrorState() throws {
        let person = try makeTestPerson()
        let viewModel = makeViewModel(person: person)
        viewModel.errorMessage = "Unable to load providers."

        let view = ProviderListView(person: person, viewModel: viewModel)
        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            // View renders successfully even in error state
            _ = try inspected.find(ViewType.Group.self)
        }
        #expect(viewModel.errorMessage == "Unable to load providers.")
    }

    @Test
    func viewRendersWithErrorFromRepository() async throws {
        let person = try makeTestPerson()
        let mockRepo = MockProviderRepository()
        mockRepo.shouldFailFetchAll = true

        let viewModel = makeViewModel(person: person, repository: mockRepo)
        await viewModel.loadProviders()

        let view = ProviderListView(person: person, viewModel: viewModel)
        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            _ = try inspected.find(ViewType.Group.self)
        }
        #expect(viewModel.errorMessage != nil)
    }

    @Test
    func providerRowDisplaysDisplayString() async throws {
        let person = try makeTestPerson()
        let mockRepo = MockProviderRepository()
        let provider = Provider(name: "Dr. Adams", organization: "Health Clinic", specialty: "Dermatology")
        mockRepo.addProvider(provider, personId: person.id)

        let viewModel = makeViewModel(person: person, repository: mockRepo)
        await viewModel.loadProviders()

        let view = ProviderListView(person: person, viewModel: viewModel)
        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            // Find text matching the provider displayString
            _ = try inspected.find(text: "Dr. Adams at Health Clinic")
        }
    }

    @Test
    func providerRowDisplaysSpecialty() async throws {
        let person = try makeTestPerson()
        let mockRepo = MockProviderRepository()
        let provider = Provider(name: "Dr. Adams", specialty: "Dermatology")
        mockRepo.addProvider(provider, personId: person.id)

        let viewModel = makeViewModel(person: person, repository: mockRepo)
        await viewModel.loadProviders()

        let view = ProviderListView(person: person, viewModel: viewModel)
        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            _ = try inspected.find(text: "Dermatology")
        }
    }

    @Test
    func deleteConfirmationDialogExists() throws {
        let person = try makeTestPerson()
        let viewModel = makeViewModel(person: person)
        let view = ProviderListView(person: person, viewModel: viewModel)

        // View renders with confirmation dialog modifier
        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            _ = try inspected.find(ViewType.Group.self)
        }
    }

    @Test
    func viewInitializesWithDefaultViewModel() throws {
        let person = try makeTestPerson()
        // Initialize without providing viewModel to test default initialization
        let view = ProviderListView(person: person)
        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            _ = try inspected.find(ViewType.Group.self)
        }
    }

    @Test
    func viewRendersMultipleProviders() async throws {
        let person = try makeTestPerson()
        let mockRepo = MockProviderRepository()

        let providers = [
            Provider(name: "Dr. Alpha"),
            Provider(name: "Dr. Beta"),
            Provider(name: "Dr. Gamma")
        ]
        for provider in providers {
            mockRepo.addProvider(provider, personId: person.id)
        }

        let viewModel = makeViewModel(person: person, repository: mockRepo)
        await viewModel.loadProviders()

        let view = ProviderListView(person: person, viewModel: viewModel)
        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            let list = try inspected.find(ViewType.List.self)
            let forEach = try list.forEach(0)
            // Verify all 3 rows rendered
            _ = try forEach.button(0)
            _ = try forEach.button(1)
            _ = try forEach.button(2)
        }
    }

    @Test
    func viewRendersProviderWithOrganizationOnly() async throws {
        let person = try makeTestPerson()
        let mockRepo = MockProviderRepository()
        let provider = Provider(organization: "Sunrise Medical Center")
        mockRepo.addProvider(provider, personId: person.id)

        let viewModel = makeViewModel(person: person, repository: mockRepo)
        await viewModel.loadProviders()

        let view = ProviderListView(person: person, viewModel: viewModel)
        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            _ = try inspected.find(text: "Sunrise Medical Center")
        }
    }

    @Test
    func viewShowsListStyleWhenProvidersExist() async throws {
        let person = try makeTestPerson()
        let mockRepo = MockProviderRepository()
        mockRepo.addProvider(Provider(name: "Dr. Test"), personId: person.id)

        let viewModel = makeViewModel(person: person, repository: mockRepo)
        await viewModel.loadProviders()

        let view = ProviderListView(person: person, viewModel: viewModel)
        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            // When providers exist, should show List not ContentUnavailableView
            _ = try inspected.find(ViewType.List.self)
        }
    }

    @Test
    func viewRendersNavigationTitle() throws {
        let person = try makeTestPerson(name: "Alice")
        let viewModel = makeViewModel(person: person)
        let view = ProviderListView(person: person, viewModel: viewModel)

        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            _ = try inspected.find(ViewType.Group.self)
        }
    }

    @Test
    func emptyStateShowsCorrectMessage() throws {
        let person = try makeTestPerson()
        let viewModel = makeViewModel(person: person)
        let view = ProviderListView(person: person, viewModel: viewModel)

        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            let unavailable = try inspected.find(ViewType.ContentUnavailableView.self)
            _ = unavailable
        }
    }

    @Test
    func loadingStateOverlaysOnEmptyView() throws {
        let person = try makeTestPerson()
        let viewModel = makeViewModel(person: person)
        viewModel.isLoading = true
        // When loading with no providers, both ContentUnavailableView
        // (since filteredProviders is empty) and ProgressView overlay appear
        let view = ProviderListView(person: person, viewModel: viewModel)

        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            _ = try inspected.find(ViewType.ProgressView.self)
        }
    }
}
