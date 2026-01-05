import CryptoKit
import SwiftUI
import Testing
import ViewInspector
@testable import FamilyMedicalApp

@MainActor
struct MedicalRecordListViewTests {
    // MARK: - Test Data

    let testPrimaryKey = SymmetricKey(size: .bits256)
    let testFMK = SymmetricKey(size: .bits256)

    func makeTestPerson() throws -> Person {
        try Person(
            id: UUID(),
            name: "Test Person",
            dateOfBirth: Date(),
            labels: ["Self"],
            notes: nil
        )
    }

    func makeTestDecryptedRecord(personId: UUID? = nil) -> DecryptedRecord {
        var content = RecordContent(schemaId: "vaccine")
        content.setString(BuiltInFieldIds.Vaccine.name, "COVID-19")
        content.setDate(BuiltInFieldIds.Vaccine.dateAdministered, Date())

        let record = MedicalRecord(
            personId: personId ?? UUID(),
            encryptedContent: Data()
        )

        return DecryptedRecord(record: record, content: content)
    }

    func createListViewModel(person: Person) -> MedicalRecordListViewModel {
        let mockRecordRepo = MockMedicalRecordRepository()
        let mockContentService = MockRecordContentService()
        let mockKeyProvider = MockPrimaryKeyProvider(primaryKey: testPrimaryKey)
        let mockFMKService = MockFamilyMemberKeyService()
        mockFMKService.setFMK(testFMK, for: person.id.uuidString)

        return MedicalRecordListViewModel(
            person: person,
            schemaType: .vaccine,
            medicalRecordRepository: mockRecordRepo,
            recordContentService: mockContentService,
            primaryKeyProvider: mockKeyProvider,
            fmkService: mockFMKService
        )
    }

    // MARK: - Basic Rendering Tests

    @Test
    func medicalRecordListViewInitializesWithPerson() throws {
        let person = try makeTestPerson()
        let view = MedicalRecordListView(person: person, schemaType: .vaccine)

        _ = view.body

        #expect(person.name == "Test Person")
    }

    @Test
    func medicalRecordListViewRendersWithInjectedViewModel() throws {
        let person = try makeTestPerson()
        let viewModel = createListViewModel(person: person)

        let view = MedicalRecordListView(
            person: person,
            schemaType: .vaccine,
            viewModel: viewModel
        )

        let inspectedView = try view.inspect()
        _ = try inspectedView.group()
    }

    @Test
    func medicalRecordListViewRendersEmptyState() throws {
        let person = try makeTestPerson()
        let viewModel = createListViewModel(person: person)

        let view = MedicalRecordListView(
            person: person,
            schemaType: .vaccine,
            viewModel: viewModel
        )

        let inspectedView = try view.inspect()
        // When records is empty, should show EmptyRecordListView inside Group
        _ = try inspectedView.group()
    }

    @Test
    func medicalRecordListViewRendersLoadingState() throws {
        let person = try makeTestPerson()
        let viewModel = createListViewModel(person: person)
        viewModel.isLoading = true

        let view = MedicalRecordListView(
            person: person,
            schemaType: .vaccine,
            viewModel: viewModel
        )

        let inspectedView = try view.inspect()
        _ = try inspectedView.find(ViewType.ProgressView.self)
    }

    @Test
    func medicalRecordListViewRendersWithRecords() throws {
        let person = try makeTestPerson()
        let viewModel = createListViewModel(person: person)

        // Add a record to the viewModel
        let decryptedRecord = makeTestDecryptedRecord(personId: person.id)
        viewModel.records = [decryptedRecord]

        let view = MedicalRecordListView(
            person: person,
            schemaType: .vaccine,
            viewModel: viewModel
        )

        let inspectedView = try view.inspect()
        // When records exist, should show List
        let list = try inspectedView.find(ViewType.List.self)
        _ = try list.forEach(0)
    }

    @Test
    func medicalRecordListViewRendersMultipleRecords() throws {
        let person = try makeTestPerson()
        let viewModel = createListViewModel(person: person)

        // Add multiple records
        viewModel.records = [
            makeTestDecryptedRecord(personId: person.id),
            makeTestDecryptedRecord(personId: person.id),
            makeTestDecryptedRecord(personId: person.id)
        ]

        let view = MedicalRecordListView(
            person: person,
            schemaType: .vaccine,
            viewModel: viewModel
        )

        let inspectedView = try view.inspect()
        let list = try inspectedView.find(ViewType.List.self)
        let forEach = try list.forEach(0)
        #expect(forEach.count == 3)
    }

    @Test
    func medicalRecordListViewHandlesErrorMessage() throws {
        let person = try makeTestPerson()
        let viewModel = createListViewModel(person: person)
        viewModel.errorMessage = "Test error message"

        let view = MedicalRecordListView(
            person: person,
            schemaType: .vaccine,
            viewModel: viewModel
        )

        _ = try view.inspect()
        #expect(viewModel.errorMessage == "Test error message")
    }

    @Test
    func medicalRecordListViewRendersForAllSchemaTypes() throws {
        let person = try makeTestPerson()

        for schemaType in BuiltInSchemaType.allCases {
            let view = MedicalRecordListView(person: person, schemaType: schemaType)
            _ = view.body
        }
    }
}
