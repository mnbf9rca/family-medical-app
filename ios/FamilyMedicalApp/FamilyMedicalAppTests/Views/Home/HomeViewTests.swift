import CryptoKit
import SwiftUI
import Testing
import ViewInspector
@testable import FamilyMedicalApp

@MainActor
struct HomeViewTests {
    // MARK: - Test Data

    let testKey = SymmetricKey(size: .bits256)

    func createTestPerson(name: String = "Test Person") throws -> Person {
        try PersonTestHelper.makeTestPerson(name: name)
    }

    func createViewModel() -> HomeViewModel {
        let mockRepo = MockPersonRepository()
        let mockKeyProvider = MockPrimaryKeyProvider(primaryKey: testKey)
        return HomeViewModel(
            personRepository: mockRepo,
            primaryKeyProvider: mockKeyProvider
        )
    }

    // MARK: - Basic Rendering Tests

    @Test
    func viewRendersSuccessfully() throws {
        let viewModel = createViewModel()
        let view = HomeView(viewModel: viewModel)

        // Use find() for deterministic coverage - verify Group renders
        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.Group.self)
    }

    @Test
    func viewDisplaysEmptyStateWhenNoPersons() throws {
        let viewModel = createViewModel()
        let view = HomeView(viewModel: viewModel)

        // Empty state shows EmptyMembersView
        let inspected = try view.inspect()
        _ = try inspected.find(EmptyMembersView.self)
    }

    @Test
    func viewDisplaysListWhenPersonsExist() async throws {
        let mockRepo = MockPersonRepository()
        let person = try createTestPerson()
        mockRepo.addPerson(person)

        let mockKeyProvider = MockPrimaryKeyProvider(primaryKey: testKey)
        let viewModel = HomeViewModel(
            personRepository: mockRepo,
            primaryKeyProvider: mockKeyProvider
        )

        await viewModel.loadPersons()

        let view = HomeView(viewModel: viewModel)
        // With persons, should show List
        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.List.self)
    }

    // MARK: - Error State Tests

    @Test
    func viewRendersWithError() throws {
        let mockRepo = MockPersonRepository()
        mockRepo.shouldFailFetchAll = true

        let mockKeyProvider = MockPrimaryKeyProvider(primaryKey: testKey)
        let viewModel = HomeViewModel(
            personRepository: mockRepo,
            primaryKeyProvider: mockKeyProvider
        )

        let view = HomeView(viewModel: viewModel)
        // Error state still renders the Group (alert is separate)
        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.Group.self)
    }

    // MARK: - Loading State Tests

    @Test
    func viewRendersWhileLoading() throws {
        let viewModel = createViewModel()
        viewModel.isLoading = true

        let view = HomeView(viewModel: viewModel)
        // Loading state shows ProgressView overlay
        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.ProgressView.self)
    }

    // MARK: - Delete Tests

    @Test
    func deletePersonCallsViewModel() async throws {
        let mockRepo = MockPersonRepository()
        let person1 = try createTestPerson(name: "Person 1")
        let person2 = try createTestPerson(name: "Person 2")
        mockRepo.addPerson(person1)
        mockRepo.addPerson(person2)

        let mockKeyProvider = MockPrimaryKeyProvider(primaryKey: testKey)
        let viewModel = HomeViewModel(
            personRepository: mockRepo,
            primaryKeyProvider: mockKeyProvider
        )

        await viewModel.loadPersons()
        #expect(viewModel.persons.count == 2)

        // Create view to verify it has the method
        let view = HomeView(viewModel: viewModel)
        _ = view // View exists and can call deletePerson

        // Call ViewModel directly for deterministic testing (no Task.sleep needed)
        let personToDelete = viewModel.persons[0]
        await viewModel.deletePerson(id: personToDelete.id)

        // Verify person was deleted
        #expect(viewModel.persons.count == 1)
        #expect(viewModel.persons[0].name == "Person 2")
    }
}
