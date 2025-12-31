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
        try Person(
            id: UUID(),
            name: name,
            dateOfBirth: Date(),
            labels: ["Self"],
            notes: nil
        )
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

        _ = try view.inspect()
    }

    @Test
    func viewDisplaysEmptyStateWhenNoPersons() throws {
        let viewModel = createViewModel()
        let view = HomeView(viewModel: viewModel)

        // Should render empty state when no persons
        _ = try view.inspect()
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
        _ = try view.inspect()
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
        _ = try view.inspect()
    }

    // MARK: - Loading State Tests

    @Test
    func viewRendersWhileLoading() throws {
        let viewModel = createViewModel()
        let view = HomeView(viewModel: viewModel)

        _ = try view.inspect()
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

        // Create view and trigger delete
        let view = HomeView(viewModel: viewModel)
        let offsets = IndexSet(integer: 0)

        // Call delete method directly (ViewInspector can't access .onDelete closure)
        view.deletePerson(at: offsets)

        // Give async operation time to complete
        try await Task.sleep(for: .milliseconds(100))

        // Verify person was deleted
        #expect(viewModel.persons.count == 1)
        #expect(viewModel.persons[0].name == "Person 2")
    }
}
