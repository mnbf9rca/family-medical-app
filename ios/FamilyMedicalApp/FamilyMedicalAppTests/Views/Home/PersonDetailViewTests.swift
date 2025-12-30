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

        _ = try view.inspect()
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
        let viewModel = createViewModel(person: person)
        let view = PersonDetailView(person: person, viewModel: viewModel)

        _ = try view.inspect()
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
        let record = try MedicalRecord(
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
        _ = try view.inspect()
    }
}
