import CryptoKit
import Foundation
import Testing
@testable import FamilyMedicalApp

@MainActor
struct HomeViewModelTests {
    // MARK: - Test Data

    let testKey = SymmetricKey(size: .bits256)

    // MARK: - Test Context

    /// Test context holding the view model and its mock dependencies
    struct TestContext {
        let viewModel: HomeViewModel
        let mockRepo: MockPersonRepository
        let mockFmkService: MockFamilyMemberKeyService
        let mockSeeder: MockSchemaSeeder
    }

    func createTestPerson(name: String = "Test Person") throws -> Person {
        try PersonTestHelper.makeTestPerson(name: name)
    }

    func makeViewModel(
        personRepository: MockPersonRepository? = nil,
        primaryKeyProvider: MockPrimaryKeyProvider? = nil,
        fmkService: MockFamilyMemberKeyService? = nil,
        schemaSeeder: MockSchemaSeeder? = nil
    ) -> TestContext {
        let repo = personRepository ?? MockPersonRepository()
        let keyProvider = primaryKeyProvider ?? MockPrimaryKeyProvider(primaryKey: testKey)
        let fmk = fmkService ?? MockFamilyMemberKeyService()
        let seeder = schemaSeeder ?? MockSchemaSeeder()

        let viewModel = HomeViewModel(
            personRepository: repo,
            primaryKeyProvider: keyProvider,
            fmkService: fmk,
            schemaSeeder: seeder
        )

        return TestContext(viewModel: viewModel, mockRepo: repo, mockFmkService: fmk, mockSeeder: seeder)
    }

    // MARK: - Load Persons Tests

    @Test
    func loadPersonsSucceedsWithValidData() async throws {
        let person1 = try createTestPerson(name: "Alice")
        let person2 = try createTestPerson(name: "Bob")

        let mockRepo = MockPersonRepository()
        mockRepo.addPerson(person1)
        mockRepo.addPerson(person2)

        let ctx = makeViewModel(personRepository: mockRepo)

        await ctx.viewModel.loadPersons()

        #expect(ctx.viewModel.persons.count == 2)
        #expect(ctx.viewModel.persons.contains { $0.name == "Alice" })
        #expect(ctx.viewModel.persons.contains { $0.name == "Bob" })
        #expect(ctx.viewModel.errorMessage == nil)
        #expect(ctx.viewModel.isLoading == false)
    }

    @Test
    func loadPersonsReturnsEmptyArrayWhenNoData() async {
        let ctx = makeViewModel()

        await ctx.viewModel.loadPersons()

        #expect(ctx.viewModel.persons.isEmpty)
        #expect(ctx.viewModel.errorMessage == nil)
        #expect(ctx.viewModel.isLoading == false)
    }

    @Test
    func loadPersonsSetsErrorWhenRepositoryFails() async {
        let mockRepo = MockPersonRepository()
        mockRepo.shouldFailFetchAll = true

        let ctx = makeViewModel(personRepository: mockRepo)

        await ctx.viewModel.loadPersons()

        #expect(ctx.viewModel.persons.isEmpty)
        #expect(ctx.viewModel.errorMessage != nil)
        #expect(ctx.viewModel.errorMessage?.contains("Unable to load") == true)
        #expect(ctx.viewModel.isLoading == false)
    }

    @Test
    func loadPersonsSetsErrorWhenPrimaryKeyNotAvailable() async {
        let mockKeyProvider = MockPrimaryKeyProvider(primaryKey: nil)
        let ctx = makeViewModel(primaryKeyProvider: mockKeyProvider)

        await ctx.viewModel.loadPersons()

        #expect(ctx.viewModel.persons.isEmpty)
        #expect(ctx.viewModel.errorMessage != nil)
        #expect(ctx.viewModel.isLoading == false)
    }

    @Test
    func loadPersonsSetsLoadingStateCorrectly() async {
        let ctx = makeViewModel()

        // Before loading
        #expect(ctx.viewModel.isLoading == false)

        // Load and verify final state (intermediate isLoading=true state
        // cannot be reliably tested without introducing flakiness)
        await ctx.viewModel.loadPersons()

        // After loading
        #expect(ctx.viewModel.isLoading == false)
    }

    // MARK: - Create Person Tests

    @Test
    func createPersonSucceedsAndReloadsData() async throws {
        let mockFmk = MockFamilyMemberKeyService()
        let ctx = makeViewModel(fmkService: mockFmk)

        let newPerson = try createTestPerson(name: "New Person")

        // Pre-store FMK so retrieveFMK succeeds after person save
        mockFmk.setFMK(testKey, for: newPerson.id.uuidString)

        await ctx.viewModel.createPerson(newPerson)

        #expect(ctx.viewModel.persons.count == 1)
        #expect(ctx.viewModel.persons.first?.name == "New Person")
        #expect(ctx.viewModel.errorMessage == nil)
        #expect(ctx.mockRepo.saveCallCount == 1)
        #expect(ctx.mockRepo.fetchAllCallCount == 1) // Should reload after save
        #expect(ctx.mockSeeder.seedCallCount == 1) // Should seed schemas
        #expect(ctx.mockSeeder.lastSeededPersonId == newPerson.id)
    }

    @Test
    func createPersonSeedsSchemas() async throws {
        let mockFmk = MockFamilyMemberKeyService()
        let ctx = makeViewModel(fmkService: mockFmk)

        let newPerson = try createTestPerson(name: "Test Person")

        // Pre-store FMK so retrieveFMK succeeds after person save
        mockFmk.setFMK(testKey, for: newPerson.id.uuidString)

        await ctx.viewModel.createPerson(newPerson)

        // Verify schema seeding was called with correct Person ID
        #expect(ctx.mockSeeder.seedCallCount == 1)
        #expect(ctx.mockSeeder.lastSeededPersonId == newPerson.id)
    }

    @Test
    func createPersonSetsErrorWhenSaveFails() async throws {
        let mockRepo = MockPersonRepository()
        mockRepo.shouldFailSave = true

        let ctx = makeViewModel(personRepository: mockRepo)

        let newPerson = try createTestPerson()
        await ctx.viewModel.createPerson(newPerson)

        #expect(ctx.viewModel.errorMessage != nil)
        #expect(ctx.viewModel.errorMessage?.contains("Unable to save") == true)
        #expect(ctx.viewModel.isLoading == false)
        #expect(ctx.mockSeeder.seedCallCount == 0) // Should not seed if save fails
    }

    @Test
    func createPersonSetsErrorWhenSeedingFails() async throws {
        let mockFmk = MockFamilyMemberKeyService()
        let mockSeeder = MockSchemaSeeder()
        mockSeeder.shouldFailSeed = true

        let ctx = makeViewModel(fmkService: mockFmk, schemaSeeder: mockSeeder)

        let newPerson = try createTestPerson()

        // Pre-store FMK so retrieveFMK succeeds after person save
        mockFmk.setFMK(testKey, for: newPerson.id.uuidString)

        await ctx.viewModel.createPerson(newPerson)

        // Save succeeds but seeding fails - should show error
        #expect(ctx.mockRepo.saveCallCount == 1)
        #expect(ctx.viewModel.errorMessage != nil)
        #expect(ctx.viewModel.errorMessage?.contains("Unable to save") == true)
        #expect(ctx.viewModel.isLoading == false)
    }

    @Test
    func createPersonSetsErrorWhenPrimaryKeyNotAvailable() async throws {
        let mockKeyProvider = MockPrimaryKeyProvider(primaryKey: nil)
        let ctx = makeViewModel(primaryKeyProvider: mockKeyProvider)

        let newPerson = try createTestPerson()
        await ctx.viewModel.createPerson(newPerson)

        #expect(ctx.viewModel.errorMessage != nil)
        #expect(ctx.viewModel.isLoading == false)
        #expect(ctx.mockRepo.saveCallCount == 0) // Should not call save if key unavailable
        #expect(ctx.mockSeeder.seedCallCount == 0) // Should not seed if key unavailable
    }

    // MARK: - Delete Person Tests

    @Test
    func deletePersonSucceedsAndReloadsData() async throws {
        let person = try createTestPerson()
        let mockRepo = MockPersonRepository()
        mockRepo.addPerson(person)

        let ctx = makeViewModel(personRepository: mockRepo)

        // Load initial data
        await ctx.viewModel.loadPersons()
        #expect(ctx.viewModel.persons.count == 1)

        // Delete the person
        await ctx.viewModel.deletePerson(id: person.id)

        #expect(ctx.viewModel.persons.isEmpty)
        #expect(ctx.viewModel.errorMessage == nil)
        #expect(ctx.mockRepo.deleteCallCount == 1)
        #expect(ctx.mockRepo.fetchAllCallCount == 2) // Initial load + reload after delete
    }

    @Test
    func deletePersonSetsErrorWhenDeleteFails() async throws {
        let person = try createTestPerson()
        let mockRepo = MockPersonRepository()
        mockRepo.addPerson(person)
        mockRepo.shouldFailDelete = true

        let ctx = makeViewModel(personRepository: mockRepo)

        await ctx.viewModel.deletePerson(id: person.id)

        #expect(ctx.viewModel.errorMessage != nil)
        #expect(ctx.viewModel.errorMessage?.contains("Unable to remove") == true)
        #expect(ctx.viewModel.isLoading == false)
    }

    @Test
    func deletePersonHandlesNonExistentId() async {
        let ctx = makeViewModel()

        // Try to delete non-existent person
        let randomId = UUID()
        await ctx.viewModel.deletePerson(id: randomId)

        // Should reload (which returns empty) but not error
        #expect(ctx.viewModel.persons.isEmpty)
        #expect(ctx.viewModel.errorMessage == nil)
        #expect(ctx.mockRepo.deleteCallCount == 1)
    }

    // MARK: - Error Message Tests

    @Test
    func errorMessageClearsOnSuccessfulLoad() async {
        let mockRepo = MockPersonRepository()
        mockRepo.shouldFailFetchAll = true

        let ctx = makeViewModel(personRepository: mockRepo)

        // First load fails
        await ctx.viewModel.loadPersons()
        #expect(ctx.viewModel.errorMessage != nil)

        // Fix the repository and reload
        mockRepo.shouldFailFetchAll = false
        await ctx.viewModel.loadPersons()

        // Error should be cleared
        #expect(ctx.viewModel.errorMessage == nil)
    }
}
