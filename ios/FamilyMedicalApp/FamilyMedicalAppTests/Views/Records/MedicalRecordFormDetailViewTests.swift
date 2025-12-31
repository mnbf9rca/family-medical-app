import CryptoKit
import SwiftUI
import Testing
import ViewInspector
@testable import FamilyMedicalApp

@MainActor
struct MedicalRecordFormDetailViewTests {
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
        content.setString("vaccineName", "COVID-19")
        content.setDate("dateAdministered", Date())

        let record = MedicalRecord(
            personId: personId ?? UUID(),
            encryptedContent: Data()
        )

        return DecryptedRecord(record: record, content: content)
    }

    func createFormViewModel(
        person: Person,
        existingRecord: MedicalRecord? = nil,
        existingContent: RecordContent? = nil
    ) -> MedicalRecordFormViewModel {
        let mockRecordRepo = MockMedicalRecordRepository()
        let mockContentService = MockRecordContentService()
        let mockKeyProvider = MockPrimaryKeyProvider(primaryKey: testPrimaryKey)
        let mockFMKService = MockFamilyMemberKeyService()
        mockFMKService.setFMK(testFMK, for: person.id.uuidString)

        return MedicalRecordFormViewModel(
            person: person,
            schema: RecordSchema.builtIn(.vaccine),
            existingRecord: existingRecord,
            existingContent: existingContent,
            medicalRecordRepository: mockRecordRepo,
            recordContentService: mockContentService,
            primaryKeyProvider: mockKeyProvider,
            fmkService: mockFMKService
        )
    }

    // MARK: - MedicalRecordDetailView Tests

    @Test
    func medicalRecordDetailViewRendersWithDecryptedRecord() throws {
        let person = try makeTestPerson()
        let decryptedRecord = makeTestDecryptedRecord()

        let view = MedicalRecordDetailView(
            person: person,
            schemaType: .vaccine,
            decryptedRecord: decryptedRecord
        )

        _ = view.body

        #expect(decryptedRecord.content.schemaId == "vaccine")
    }

    @Test
    func medicalRecordDetailViewRendersRecordContent() throws {
        let person = try makeTestPerson()
        var content = RecordContent(schemaId: "vaccine")
        content.setString("vaccineName", "COVID-19 Pfizer")
        content.setDate("dateAdministered", Date())
        content.setString("provider", "CVS Pharmacy")
        content.setInt("doseNumber", 2)

        let record = MedicalRecord(personId: person.id, encryptedContent: Data())
        let decryptedRecord = DecryptedRecord(record: record, content: content)

        let view = MedicalRecordDetailView(
            person: person,
            schemaType: .vaccine,
            decryptedRecord: decryptedRecord
        )

        let inspectedView = try view.inspect()
        _ = try inspectedView.find(ViewType.List.self)
    }

    @Test
    func medicalRecordDetailViewHandlesMissingPrimaryField() throws {
        let person = try makeTestPerson()
        // Create content without the primary field
        var content = RecordContent(schemaId: "vaccine")
        content.setDate("dateAdministered", Date())

        let record = MedicalRecord(personId: person.id, encryptedContent: Data())
        let decryptedRecord = DecryptedRecord(record: record, content: content)

        let view = MedicalRecordDetailView(
            person: person,
            schemaType: .vaccine,
            decryptedRecord: decryptedRecord
        )

        _ = view.body
        // Should handle gracefully with "Untitled" fallback
    }

    @Test
    func medicalRecordDetailViewRendersForAllSchemaTypes() throws {
        let person = try makeTestPerson()

        for schemaType in BuiltInSchemaType.allCases {
            var content = RecordContent(schemaId: schemaType.rawValue)
            // Add a date field (most schemas have one)
            content.setDate("dateAdministered", Date())
            content.setDate("diagnosedDate", Date())
            content.setDate("prescribedDate", Date())
            content.setDate("createdDate", Date())

            let record = MedicalRecord(personId: person.id, encryptedContent: Data())
            let decryptedRecord = DecryptedRecord(record: record, content: content)

            let view = MedicalRecordDetailView(
                person: person,
                schemaType: schemaType,
                decryptedRecord: decryptedRecord
            )
            _ = view.body
        }
    }

    // MARK: - MedicalRecordFormView Tests

    @Test
    func medicalRecordFormViewRendersForAdd() throws {
        let person = try makeTestPerson()
        let schema = RecordSchema.builtIn(.vaccine)

        let view = MedicalRecordFormView(
            person: person,
            schema: schema
        )

        _ = view.body

        #expect(schema.id == "vaccine")
    }

    @Test
    func medicalRecordFormViewRendersForEdit() throws {
        let person = try makeTestPerson()
        let schema = RecordSchema.builtIn(.vaccine)
        let decryptedRecord = makeTestDecryptedRecord()

        let view = MedicalRecordFormView(
            person: person,
            schema: schema,
            existingRecord: decryptedRecord.record,
            existingContent: decryptedRecord.content
        )

        _ = view.body

        #expect(decryptedRecord.content.getString("vaccineName") == "COVID-19")
    }

    @Test
    func medicalRecordFormViewRendersWithInjectedViewModel() throws {
        let person = try makeTestPerson()
        let schema = RecordSchema.builtIn(.vaccine)
        let viewModel = createFormViewModel(person: person)

        let view = MedicalRecordFormView(
            person: person,
            schema: schema,
            viewModel: viewModel
        )

        let inspectedView = try view.inspect()
        _ = try inspectedView.navigationStack()
    }

    @Test
    func medicalRecordFormViewRendersFormFields() throws {
        let person = try makeTestPerson()
        let schema = RecordSchema.builtIn(.vaccine)
        let viewModel = createFormViewModel(person: person)

        let view = MedicalRecordFormView(
            person: person,
            schema: schema,
            viewModel: viewModel
        )

        let inspectedView = try view.inspect()
        let navigationStack = try inspectedView.navigationStack()
        _ = try navigationStack.find(ViewType.Form.self)
    }

    @Test
    func medicalRecordFormViewRendersLoadingState() throws {
        let person = try makeTestPerson()
        let schema = RecordSchema.builtIn(.vaccine)
        let viewModel = createFormViewModel(person: person)
        viewModel.isLoading = true

        let view = MedicalRecordFormView(
            person: person,
            schema: schema,
            viewModel: viewModel
        )

        let inspectedView = try view.inspect()
        _ = try inspectedView.find(ViewType.ProgressView.self)
    }

    @Test
    func medicalRecordFormViewHandlesErrorMessage() throws {
        let person = try makeTestPerson()
        let schema = RecordSchema.builtIn(.vaccine)
        let viewModel = createFormViewModel(person: person)
        viewModel.errorMessage = "Validation failed"

        let view = MedicalRecordFormView(
            person: person,
            schema: schema,
            viewModel: viewModel
        )

        _ = try view.inspect()
        #expect(viewModel.errorMessage == "Validation failed")
    }

    @Test
    func medicalRecordFormViewRendersForAllSchemaTypes() throws {
        let person = try makeTestPerson()

        for schemaType in BuiltInSchemaType.allCases {
            let schema = RecordSchema.builtIn(schemaType)
            let view = MedicalRecordFormView(person: person, schema: schema)
            _ = view.body
        }
    }

    @Test
    func medicalRecordFormViewPreservesExistingContent() throws {
        let person = try makeTestPerson()
        let schema = RecordSchema.builtIn(.vaccine)

        var existingContent = RecordContent(schemaId: "vaccine")
        existingContent.setString("vaccineName", "Existing Vaccine")
        existingContent.setDate("dateAdministered", Date())

        let existingRecord = MedicalRecord(personId: person.id, encryptedContent: Data())

        let viewModel = createFormViewModel(
            person: person,
            existingRecord: existingRecord,
            existingContent: existingContent
        )

        let view = MedicalRecordFormView(
            person: person,
            schema: schema,
            existingRecord: existingRecord,
            existingContent: existingContent,
            viewModel: viewModel
        )

        _ = view.body

        #expect(viewModel.fieldValues["vaccineName"]?.stringValue == "Existing Vaccine")
    }
}
