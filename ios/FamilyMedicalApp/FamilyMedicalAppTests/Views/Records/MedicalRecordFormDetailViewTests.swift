import CryptoKit
import Dependencies
import SwiftUI
import Testing
import ViewInspector
@testable import FamilyMedicalApp

/// Tests for MedicalRecordDetailView and MedicalRecordFormView using generic schema
/// (ExampleSchema.comprehensiveExample) to validate view behavior independent of specific record types.
@MainActor
struct MedicalRecordFormDetailViewTests {
    // MARK: - Test Data

    let testPrimaryKey = SymmetricKey(size: .bits256)
    let testFMK = SymmetricKey(size: .bits256)

    /// Returns the comprehensive example schema that exercises all field types
    var testSchema: RecordSchema { ExampleSchema.comprehensiveExample }

    /// Schema ID for the comprehensive example schema
    var testSchemaId: String { "comprehensive_example" }

    /// Required string field UUID in the comprehensive schema
    var requiredStringFieldId: UUID { ExampleSchema.FieldIds.exampleName }

    /// Required string field ID as string key for fieldValues dictionary access
    var requiredStringFieldKey: String { ExampleSchema.FieldIds.exampleName.uuidString }

    /// Required date field UUID in the comprehensive schema
    var requiredDateFieldId: UUID { ExampleSchema.FieldIds.recordedDate }

    func makeTestPerson() throws -> Person {
        try PersonTestHelper.makeTestPerson()
    }

    func makeTestDecryptedRecord(personId: UUID? = nil) -> DecryptedRecord {
        var content = RecordContent(schemaId: testSchemaId)
        content.setString(requiredStringFieldId, "Test Record")
        content.setDate(requiredDateFieldId, Date())

        let record = MedicalRecord(
            personId: personId ?? UUID(),
            encryptedContent: Data()
        )

        return DecryptedRecord(record: record, content: content)
    }

    /// Fixed test date for deterministic testing
    let testDate = Date(timeIntervalSinceReferenceDate: 1_234_567_890)

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

        // Use withDependencies to provide test values for @Dependency properties
        return withDependencies {
            $0.date = .constant(testDate)
        } operation: {
            MedicalRecordFormViewModel(
                person: person,
                schema: testSchema,
                existingRecord: existingRecord,
                existingContent: existingContent,
                medicalRecordRepository: mockRecordRepo,
                recordContentService: mockContentService,
                primaryKeyProvider: mockKeyProvider,
                fmkService: mockFMKService
            )
        }
    }

    // MARK: - MedicalRecordDetailView Integration Tests
    // Note: MedicalRecordDetailView requires BuiltInSchemaType, so these are integration tests
    // that verify all built-in schemas render correctly.

    @Test
    func medicalRecordDetailViewRendersForAllSchemaTypes() throws {
        let person = try makeTestPerson()

        for schemaType in BuiltInSchemaType.allCases {
            var content = RecordContent(schemaId: schemaType.rawValue)
            // Add date fields that various schemas might have
            content.setDate(BuiltInFieldIds.Vaccine.dateAdministered, Date())
            content.setDate(BuiltInFieldIds.Condition.diagnosedDate, Date())
            content.setDate(BuiltInFieldIds.Medication.startDate, Date())

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

    @Test
    func medicalRecordDetailViewRendersContent() throws {
        let person = try makeTestPerson()
        // Use vaccine schema for this integration test
        var content = RecordContent(schemaId: "vaccine")
        content.setString(BuiltInFieldIds.Vaccine.name, "Test Vaccine")
        content.setDate(BuiltInFieldIds.Vaccine.dateAdministered, Date())
        content.setString(BuiltInFieldIds.Vaccine.provider, "Test Provider")
        content.setInt(BuiltInFieldIds.Vaccine.doseNumber, 2)

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
        content.setDate(BuiltInFieldIds.Vaccine.dateAdministered, Date())

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
    func medicalRecordDetailViewRendersWithCallbacks() throws {
        let person = try makeTestPerson()
        var content = RecordContent(schemaId: "vaccine")
        content.setString(BuiltInFieldIds.Vaccine.name, "Test Vaccine")
        content.setDate(BuiltInFieldIds.Vaccine.dateAdministered, Date())

        let record = MedicalRecord(personId: person.id, encryptedContent: Data())
        let decryptedRecord = DecryptedRecord(record: record, content: content)

        var deleteCallbackProvided = false
        var updateCallbackProvided = false

        let view = MedicalRecordDetailView(
            person: person,
            schemaType: .vaccine,
            decryptedRecord: decryptedRecord,
            onDelete: {
                deleteCallbackProvided = true
            },
            onRecordUpdated: {
                updateCallbackProvided = true
            }
        )

        _ = view.body

        // Callbacks are provided but not triggered during render
        #expect(deleteCallbackProvided == false)
        #expect(updateCallbackProvided == false)
    }

    @Test
    func medicalRecordDetailViewRendersWithoutCallbacks() throws {
        let person = try makeTestPerson()
        var content = RecordContent(schemaId: "vaccine")
        content.setString(BuiltInFieldIds.Vaccine.name, "Test Vaccine")
        content.setDate(BuiltInFieldIds.Vaccine.dateAdministered, Date())

        let record = MedicalRecord(personId: person.id, encryptedContent: Data())
        let decryptedRecord = DecryptedRecord(record: record, content: content)

        // View should render without callbacks (nil defaults)
        let view = MedicalRecordDetailView(
            person: person,
            schemaType: .vaccine,
            decryptedRecord: decryptedRecord
        )

        _ = view.body
    }

    // MARK: - MedicalRecordFormView Tests (using generic schema)

    @Test
    func medicalRecordFormViewRendersForAdd() throws {
        let person = try makeTestPerson()

        let view = withDependencies {
            $0.date = .constant(testDate)
        } operation: {
            MedicalRecordFormView(
                person: person,
                schema: testSchema
            )
        }

        _ = view.body

        #expect(testSchema.id == testSchemaId)
    }

    @Test
    func medicalRecordFormViewRendersForEdit() throws {
        let person = try makeTestPerson()
        let decryptedRecord = makeTestDecryptedRecord()

        let view = withDependencies {
            $0.date = .constant(testDate)
        } operation: {
            MedicalRecordFormView(
                person: person,
                schema: testSchema,
                existingRecord: decryptedRecord.record,
                existingContent: decryptedRecord.content
            )
        }

        _ = view.body

        #expect(decryptedRecord.content.getString(requiredStringFieldId) == "Test Record")
    }

    @Test
    func medicalRecordFormViewRendersWithInjectedViewModel() throws {
        let person = try makeTestPerson()
        let viewModel = createFormViewModel(person: person)

        let view = MedicalRecordFormView(
            person: person,
            schema: testSchema,
            viewModel: viewModel
        )

        let inspectedView = try view.inspect()
        _ = try inspectedView.navigationStack()
    }

    @Test
    func medicalRecordFormViewRendersFormFields() throws {
        let person = try makeTestPerson()
        let viewModel = createFormViewModel(person: person)

        let view = MedicalRecordFormView(
            person: person,
            schema: testSchema,
            viewModel: viewModel
        )

        let inspectedView = try view.inspect()
        let navigationStack = try inspectedView.navigationStack()
        _ = try navigationStack.find(ViewType.Form.self)
    }

    @Test
    func medicalRecordFormViewRendersLoadingState() throws {
        let person = try makeTestPerson()
        let viewModel = createFormViewModel(person: person)
        viewModel.isLoading = true

        let view = MedicalRecordFormView(
            person: person,
            schema: testSchema,
            viewModel: viewModel
        )

        let inspectedView = try view.inspect()
        _ = try inspectedView.find(ViewType.ProgressView.self)
    }

    @Test
    func medicalRecordFormViewHandlesErrorMessage() throws {
        let person = try makeTestPerson()
        let viewModel = createFormViewModel(person: person)
        viewModel.errorMessage = "Validation failed"

        let view = MedicalRecordFormView(
            person: person,
            schema: testSchema,
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
            let view = withDependencies {
                $0.date = .constant(testDate)
            } operation: {
                MedicalRecordFormView(person: person, schema: schema)
            }
            _ = view.body
        }
    }

    @Test
    func medicalRecordFormViewPreservesExistingContent() throws {
        let person = try makeTestPerson()

        var existingContent = RecordContent(schemaId: testSchemaId)
        existingContent.setString(requiredStringFieldId, "Existing Record")
        existingContent.setDate(requiredDateFieldId, Date())

        let existingRecord = MedicalRecord(personId: person.id, encryptedContent: Data())

        let viewModel = createFormViewModel(
            person: person,
            existingRecord: existingRecord,
            existingContent: existingContent
        )

        let view = MedicalRecordFormView(
            person: person,
            schema: testSchema,
            existingRecord: existingRecord,
            existingContent: existingContent,
            viewModel: viewModel
        )

        _ = view.body

        #expect(viewModel.fieldValues[requiredStringFieldKey]?.stringValue == "Existing Record")
    }
}
