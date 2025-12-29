import CryptoKit
import Foundation
import Testing
@testable import FamilyMedicalApp

@MainActor
struct HomeViewModelTests {
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

    // MARK: - Load Persons Tests

    @Test
    func loadPersonsSucceedsWithValidData() async throws {
        let person1 = try createTestPerson(name: "Alice")
        let person2 = try createTestPerson(name: "Bob")

        let mockRepo = MockPersonRepository()
        mockRepo.addPerson(person1)
        mockRepo.addPerson(person2)

        let mockKeyProvider = MockPrimaryKeyProvider(primaryKey: testKey)
        let viewModel = HomeViewModel(
            personRepository: mockRepo,
            primaryKeyProvider: mockKeyProvider
        )

        await viewModel.loadPersons()

        #expect(viewModel.persons.count == 2)
        #expect(viewModel.persons.contains { $0.name == "Alice" })
        #expect(viewModel.persons.contains { $0.name == "Bob" })
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.isLoading == false)
    }

    @Test
    func loadPersonsReturnsEmptyArrayWhenNoData() async {
        let mockRepo = MockPersonRepository()
        let mockKeyProvider = MockPrimaryKeyProvider(primaryKey: testKey)
        let viewModel = HomeViewModel(
            personRepository: mockRepo,
            primaryKeyProvider: mockKeyProvider
        )

        await viewModel.loadPersons()

        #expect(viewModel.persons.isEmpty)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.isLoading == false)
    }

    @Test
    func loadPersonsSetsErrorWhenRepositoryFails() async {
        let mockRepo = MockPersonRepository()
        mockRepo.shouldFailFetchAll = true

        let mockKeyProvider = MockPrimaryKeyProvider(primaryKey: testKey)
        let viewModel = HomeViewModel(
            personRepository: mockRepo,
            primaryKeyProvider: mockKeyProvider
        )

        await viewModel.loadPersons()

        #expect(viewModel.persons.isEmpty)
        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.errorMessage?.contains("Failed to load") == true)
        #expect(viewModel.isLoading == false)
    }

    @Test
    func loadPersonsSetsErrorWhenPrimaryKeyNotAvailable() async {
        let mockRepo = MockPersonRepository()
        let mockKeyProvider = MockPrimaryKeyProvider(primaryKey: nil)
        let viewModel = HomeViewModel(
            personRepository: mockRepo,
            primaryKeyProvider: mockKeyProvider
        )

        await viewModel.loadPersons()

        #expect(viewModel.persons.isEmpty)
        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.isLoading == false)
    }

    @Test
    func loadPersonsSetsLoadingStateCorrectly() async {
        let mockRepo = MockPersonRepository()
        let mockKeyProvider = MockPrimaryKeyProvider(primaryKey: testKey)
        let viewModel = HomeViewModel(
            personRepository: mockRepo,
            primaryKeyProvider: mockKeyProvider
        )

        // Before loading
        #expect(viewModel.isLoading == false)

        // Start loading
        let loadTask = Task {
            await viewModel.loadPersons()
        }

        // Give the task a moment to start
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms

        await loadTask.value

        // After loading
        #expect(viewModel.isLoading == false)
    }

    // MARK: - Create Person Tests

    @Test
    func createPersonSucceedsAndReloadsData() async throws {
        let mockRepo = MockPersonRepository()
        let mockKeyProvider = MockPrimaryKeyProvider(primaryKey: testKey)
        let viewModel = HomeViewModel(
            personRepository: mockRepo,
            primaryKeyProvider: mockKeyProvider
        )

        let newPerson = try createTestPerson(name: "New Person")
        await viewModel.createPerson(newPerson)

        #expect(viewModel.persons.count == 1)
        #expect(viewModel.persons.first?.name == "New Person")
        #expect(viewModel.errorMessage == nil)
        #expect(mockRepo.saveCallCount == 1)
        #expect(mockRepo.fetchAllCallCount == 1) // Should reload after save
    }

    @Test
    func createPersonSetsErrorWhenSaveFails() async throws {
        let mockRepo = MockPersonRepository()
        mockRepo.shouldFailSave = true

        let mockKeyProvider = MockPrimaryKeyProvider(primaryKey: testKey)
        let viewModel = HomeViewModel(
            personRepository: mockRepo,
            primaryKeyProvider: mockKeyProvider
        )

        let newPerson = try createTestPerson()
        await viewModel.createPerson(newPerson)

        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.errorMessage?.contains("Failed to create") == true)
        #expect(viewModel.isLoading == false)
    }

    @Test
    func createPersonSetsErrorWhenPrimaryKeyNotAvailable() async throws {
        let mockRepo = MockPersonRepository()
        let mockKeyProvider = MockPrimaryKeyProvider(primaryKey: nil)
        let viewModel = HomeViewModel(
            personRepository: mockRepo,
            primaryKeyProvider: mockKeyProvider
        )

        let newPerson = try createTestPerson()
        await viewModel.createPerson(newPerson)

        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.isLoading == false)
        #expect(mockRepo.saveCallCount == 0) // Should not call save if key unavailable
    }

    // MARK: - Delete Person Tests

    @Test
    func deletePersonSucceedsAndReloadsData() async throws {
        let person = try createTestPerson()
        let mockRepo = MockPersonRepository()
        mockRepo.addPerson(person)

        let mockKeyProvider = MockPrimaryKeyProvider(primaryKey: testKey)
        let viewModel = HomeViewModel(
            personRepository: mockRepo,
            primaryKeyProvider: mockKeyProvider
        )

        // Load initial data
        await viewModel.loadPersons()
        #expect(viewModel.persons.count == 1)

        // Delete the person
        await viewModel.deletePerson(id: person.id)

        #expect(viewModel.persons.isEmpty)
        #expect(viewModel.errorMessage == nil)
        #expect(mockRepo.deleteCallCount == 1)
        #expect(mockRepo.fetchAllCallCount == 2) // Initial load + reload after delete
    }

    @Test
    func deletePersonSetsErrorWhenDeleteFails() async throws {
        let person = try createTestPerson()
        let mockRepo = MockPersonRepository()
        mockRepo.addPerson(person)
        mockRepo.shouldFailDelete = true

        let mockKeyProvider = MockPrimaryKeyProvider(primaryKey: testKey)
        let viewModel = HomeViewModel(
            personRepository: mockRepo,
            primaryKeyProvider: mockKeyProvider
        )

        await viewModel.deletePerson(id: person.id)

        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.errorMessage?.contains("Failed to delete") == true)
        #expect(viewModel.isLoading == false)
    }

    @Test
    func deletePersonHandlesNonExistentId() async {
        let mockRepo = MockPersonRepository()
        let mockKeyProvider = MockPrimaryKeyProvider(primaryKey: testKey)
        let viewModel = HomeViewModel(
            personRepository: mockRepo,
            primaryKeyProvider: mockKeyProvider
        )

        // Try to delete non-existent person
        let randomId = UUID()
        await viewModel.deletePerson(id: randomId)

        // Should reload (which returns empty) but not error
        #expect(viewModel.persons.isEmpty)
        #expect(viewModel.errorMessage == nil)
        #expect(mockRepo.deleteCallCount == 1)
    }

    // MARK: - Error Message Tests

    @Test
    func errorMessageClearsOnSuccessfulLoad() async {
        let mockRepo = MockPersonRepository()
        mockRepo.shouldFailFetchAll = true

        let mockKeyProvider = MockPrimaryKeyProvider(primaryKey: testKey)
        let viewModel = HomeViewModel(
            personRepository: mockRepo,
            primaryKeyProvider: mockKeyProvider
        )

        // First load fails
        await viewModel.loadPersons()
        #expect(viewModel.errorMessage != nil)

        // Fix the repository and reload
        mockRepo.shouldFailFetchAll = false
        await viewModel.loadPersons()

        // Error should be cleared
        #expect(viewModel.errorMessage == nil)
    }
}
