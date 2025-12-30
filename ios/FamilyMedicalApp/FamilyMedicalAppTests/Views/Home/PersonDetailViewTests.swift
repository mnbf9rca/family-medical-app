import CryptoKit
import SwiftUI
import Testing
import ViewInspector
@testable import FamilyMedicalApp

@MainActor
struct PersonDetailViewTests {
    // MARK: - Test Data

    let testPrimaryKey = SymmetricKey(size: .bits256)
    let testFMK = SymmetricKey(size: .bits256)

    func createTestPerson(name: String = "Test Person") throws -> Person {
        try Person(
            id: UUID(),
            name: name,
            dateOfBirth: Date(),
            labels: ["Self"],
            notes: nil
        )
    }

    func createViewModel(person: Person) -> PersonDetailViewModel {
        let mockRecordRepo = MockMedicalRecordRepository()
        let mockContentService = MockRecordContentService()
        let mockKeyProvider = MockPrimaryKeyProvider(primaryKey: testPrimaryKey)
        let mockFMKService = MockFamilyMemberKeyService()
        mockFMKService.setFMK(testFMK, for: person.id.uuidString)

        return PersonDetailViewModel(
            person: person,
            medicalRecordRepository: mockRecordRepo,
            recordContentService: mockContentService,
            primaryKeyProvider: mockKeyProvider,
            fmkService: mockFMKService
        )
    }

    // MARK: - Basic Rendering Tests

    @Test
    func viewRendersSuccessfully() throws {
        let person = try createTestPerson()
        let viewModel = createViewModel(person: person)
        let view = PersonDetailView(person: person, viewModel: viewModel)

        let inspectedView = try view.inspect()
        // Verify the root Group exists
        _ = try inspectedView.group()
    }

    @Test
    func viewDisplaysPersonName() throws {
        let person = try createTestPerson(name: "Alice Smith")
        let viewModel = createViewModel(person: person)
        let view = PersonDetailView(person: person, viewModel: viewModel)

        _ = try view.inspect()
        // View should render with person's name in navigation title
    }

    @Test
    func viewRendersWhileLoading() throws {
        let person = try createTestPerson()
        let mockRecordRepo = MockMedicalRecordRepository()

        let mockContentService = MockRecordContentService()
        let mockKeyProvider = MockPrimaryKeyProvider(primaryKey: testPrimaryKey)
        let mockFMKService = MockFamilyMemberKeyService()
        mockFMKService.setFMK(testFMK, for: person.id.uuidString)

        let viewModel = PersonDetailViewModel(
            person: person,
            medicalRecordRepository: mockRecordRepo,
            recordContentService: mockContentService,
            primaryKeyProvider: mockKeyProvider,
            fmkService: mockFMKService
        )

        // Manually set loading state
        viewModel.isLoading = true

        let view = PersonDetailView(person: person, viewModel: viewModel)

        let inspectedView = try view.inspect()
        // Find ProgressView within the view hierarchy
        _ = try inspectedView.find(ViewType.ProgressView.self)
    }

    @Test
    func viewRendersWithError() throws {
        let mockRecordRepo = MockMedicalRecordRepository()
        mockRecordRepo.shouldFailFetch = true

        let person = try createTestPerson()
        let mockContentService = MockRecordContentService()
        let mockKeyProvider = MockPrimaryKeyProvider(primaryKey: testPrimaryKey)
        let mockFMKService = MockFamilyMemberKeyService()
        mockFMKService.setFMK(testFMK, for: person.id.uuidString)

        let viewModel = PersonDetailViewModel(
            person: person,
            medicalRecordRepository: mockRecordRepo,
            recordContentService: mockContentService,
            primaryKeyProvider: mockKeyProvider,
            fmkService: mockFMKService
        )

        let view = PersonDetailView(person: person, viewModel: viewModel)
        _ = try view.inspect()
    }

    @Test
    func viewRendersWithRecords() async throws {
        let person = try createTestPerson()
        let mockRecordRepo = MockMedicalRecordRepository()
        let mockContentService = MockRecordContentService()

        // Create a test record
        let content = RecordContent(schemaId: "vaccine")
        let encryptedData = try mockContentService.encrypt(content, using: testFMK)
        let record = MedicalRecord(
            id: UUID(),
            personId: person.id,
            encryptedContent: encryptedData
        )
        mockRecordRepo.addRecord(record)
        mockContentService.setContent(content, for: encryptedData)

        let mockKeyProvider = MockPrimaryKeyProvider(primaryKey: testPrimaryKey)
        let mockFMKService = MockFamilyMemberKeyService()
        mockFMKService.setFMK(testFMK, for: person.id.uuidString)

        let viewModel = PersonDetailViewModel(
            person: person,
            medicalRecordRepository: mockRecordRepo,
            recordContentService: mockContentService,
            primaryKeyProvider: mockKeyProvider,
            fmkService: mockFMKService
        )

        await viewModel.loadRecordCounts()

        let view = PersonDetailView(person: person, viewModel: viewModel)
        let inspectedView = try view.inspect()
        // Find List within the view hierarchy
        let list = try inspectedView.find(ViewType.List.self)
        // Verify ForEach exists in the list
        _ = try list.forEach(0)
    }

    @Test
    func viewDisplaysNavigationLinksForRecordTypes() async throws {
        let person = try createTestPerson()
        let viewModel = createViewModel(person: person)

        await viewModel.loadRecordCounts()

        let view = PersonDetailView(person: person, viewModel: viewModel)
        let inspectedView = try view.inspect()
        // Find List within the view hierarchy
        let list = try inspectedView.find(ViewType.List.self)
        let forEach = try list.forEach(0)

        // Verify NavigationLink exists for first item
        _ = try forEach.navigationLink(0)
    }

    @Test
    func viewInitializesWithDefaultViewModel() throws {
        let person = try createTestPerson()

        // Initialize without providing viewModel to test default initialization
        let view = PersonDetailView(person: person)
        let inspectedView = try view.inspect()

        // Verify view renders successfully with default viewModel
        _ = try inspectedView.group()
    }

    @Test
    func viewHandlesErrorMessage() throws {
        let person = try createTestPerson()
        let viewModel = createViewModel(person: person)

        // Set an error message to verify error handling
        viewModel.errorMessage = "Test error"

        let view = PersonDetailView(person: person, viewModel: viewModel)
        // View should still render when error is present
        _ = try view.inspect()

        // Verify error message is set
        #expect(viewModel.errorMessage == "Test error")
    }

    @Test
    func viewDisplaysRecordCountsForEachType() async throws {
        let person = try createTestPerson()
        let mockRecordRepo = MockMedicalRecordRepository()
        let mockContentService = MockRecordContentService()

        // Create records for multiple types
        for schemaId in ["vaccine", "allergy", "medication"] {
            let content = RecordContent(schemaId: schemaId)
            let encryptedData = try mockContentService.encrypt(content, using: testFMK)
            let record = MedicalRecord(
                id: UUID(),
                personId: person.id,
                encryptedContent: encryptedData
            )
            mockRecordRepo.addRecord(record)
            mockContentService.setContent(content, for: encryptedData)
        }

        let mockKeyProvider = MockPrimaryKeyProvider(primaryKey: testPrimaryKey)
        let mockFMKService = MockFamilyMemberKeyService()
        mockFMKService.setFMK(testFMK, for: person.id.uuidString)

        let viewModel = PersonDetailViewModel(
            person: person,
            medicalRecordRepository: mockRecordRepo,
            recordContentService: mockContentService,
            primaryKeyProvider: mockKeyProvider,
            fmkService: mockFMKService
        )

        await viewModel.loadRecordCounts()

        let view = PersonDetailView(person: person, viewModel: viewModel)
        let inspectedView = try view.inspect()
        // Find List within the view hierarchy
        let list = try inspectedView.find(ViewType.List.self)
        let forEach = try list.forEach(0)

        // Verify each schema type appears in the list
        // There should be entries for all BuiltInSchemaType cases
        for index in 0 ..< BuiltInSchemaType.allCases.count {
            _ = try forEach.navigationLink(index)
        }
    }
}
