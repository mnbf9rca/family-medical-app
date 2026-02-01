import CryptoKit
import Foundation
import Testing
@testable import FamilyMedicalApp

struct DemoDataSeederTests {
    // MARK: - Demo Persons Tests

    @Test
    func demoPersons_hasAtLeastOnePerson() {
        let persons = DemoDataSeeder.demoPersons
        #expect(persons.isEmpty == false)
    }

    @Test
    func demoPersons_haveRealisticNames() {
        let persons = DemoDataSeeder.demoPersons
        for person in persons {
            #expect(!person.name.isEmpty)
        }
    }

    @Test
    func demoPersons_includeVariousLabels() {
        let allLabels = DemoDataSeeder.demoPersons.flatMap(\.labels)
        // Should have at least Self, Spouse, and Child labels
        #expect(allLabels.contains("Self"))
        #expect(allLabels.contains("Spouse") || allLabels.contains("Household Member"))
        #expect(allLabels.contains("Child") || allLabels.contains("Dependent"))
    }

    // MARK: - Seed Demo Data Tests

    @Test
    func seedDemoData_savesPersonsToRepository() async throws {
        let mockPersonRepository = MockPersonRepository()
        let mockSchemaSeeder = MockSchemaSeeder()
        let mockFMKService = MockFamilyMemberKeyService()
        let sut = DemoDataSeeder(
            personRepository: mockPersonRepository,
            schemaSeeder: mockSchemaSeeder,
            fmkService: mockFMKService
        )

        let demoKey = SymmetricKey(size: .bits256)
        try await sut.seedDemoData(primaryKey: demoKey)

        #expect(mockPersonRepository.saveCallCount == DemoDataSeeder.demoPersons.count)
    }

    @Test
    func seedDemoData_seedsSchemasForEachPerson() async throws {
        let mockPersonRepository = MockPersonRepository()
        let mockSchemaSeeder = MockSchemaSeeder()
        let mockFMKService = MockFamilyMemberKeyService()
        let sut = DemoDataSeeder(
            personRepository: mockPersonRepository,
            schemaSeeder: mockSchemaSeeder,
            fmkService: mockFMKService
        )

        let demoKey = SymmetricKey(size: .bits256)
        try await sut.seedDemoData(primaryKey: demoKey)

        #expect(mockSchemaSeeder.seedCallCount == DemoDataSeeder.demoPersons.count)
    }

    @Test
    func seedDemoData_createsFMKForEachPerson() async throws {
        let mockPersonRepository = MockPersonRepository()
        let mockSchemaSeeder = MockSchemaSeeder()
        let mockFMKService = MockFamilyMemberKeyService()
        let sut = DemoDataSeeder(
            personRepository: mockPersonRepository,
            schemaSeeder: mockSchemaSeeder,
            fmkService: mockFMKService
        )

        let demoKey = SymmetricKey(size: .bits256)
        try await sut.seedDemoData(primaryKey: demoKey)

        // FMK service should have stored FMKs for each person
        #expect(mockFMKService.storedFMKs.count == DemoDataSeeder.demoPersons.count)
    }

    @Test
    func seedDemoData_handlesRepositoryFailure() async throws {
        let mockPersonRepository = MockPersonRepository()
        mockPersonRepository.shouldFailSave = true
        let mockSchemaSeeder = MockSchemaSeeder()
        let mockFMKService = MockFamilyMemberKeyService()
        let sut = DemoDataSeeder(
            personRepository: mockPersonRepository,
            schemaSeeder: mockSchemaSeeder,
            fmkService: mockFMKService
        )

        let demoKey = SymmetricKey(size: .bits256)

        await #expect(throws: RepositoryError.self) {
            try await sut.seedDemoData(primaryKey: demoKey)
        }
    }
}
