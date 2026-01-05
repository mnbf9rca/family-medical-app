import CryptoKit
import Foundation
import Testing
@testable import FamilyMedicalApp

/// Tests for MedicalRecordFormViewModel using generic schema (ExampleSchema.comprehensiveExample)
/// to validate ViewModel behavior independent of specific record types.
@MainActor
struct MedicalRecordFormViewModelTests {
    // MARK: - Test Helpers

    /// Creates a test person for use in tests
    func makeTestPerson() throws -> Person {
        try Person(
            id: UUID(),
            name: "Test Person",
            dateOfBirth: Date(),
            labels: ["Self"],
            notes: nil
        )
    }

    /// Returns the comprehensive example schema that exercises all field types
    func makeTestSchema() -> RecordSchema {
        ExampleSchema.comprehensiveExample
    }

    /// Schema ID for the comprehensive example schema
    var testSchemaId: String { "comprehensive_example" }

    /// Required string field ID in the comprehensive schema (UUID string key for fieldValues)
    var requiredStringFieldId: String { ExampleSchema.FieldIds.exampleName.uuidString }

    /// Required date field ID in the comprehensive schema (UUID string key for fieldValues)
    var requiredDateFieldId: String { ExampleSchema.FieldIds.recordedDate.uuidString }

    // MARK: - Initialization Tests

    @Test
    func initializesForNewRecord() throws {
        let person = try makeTestPerson()
        let schema = makeTestSchema()

        let viewModel = MedicalRecordFormViewModel(
            person: person,
            schema: schema
        )

        #expect(viewModel.person.id == person.id)
        #expect(viewModel.schema.id == schema.id)
        #expect(viewModel.existingRecord == nil)
        #expect(viewModel.isEditing == false)
        #expect(viewModel.didSaveSuccessfully == false)
    }

    @Test
    func initializesDateFieldsWithTodayForNewRecord() throws {
        let person = try makeTestPerson()
        let schema = makeTestSchema()

        let viewModel = MedicalRecordFormViewModel(
            person: person,
            schema: schema
        )

        // Date fields should be pre-initialized with today's date
        let dateValue = viewModel.fieldValues[requiredDateFieldId]?.dateValue
        #expect(dateValue != nil)

        // Should be within the last second (essentially "now")
        if let date = dateValue {
            let timeDifference = abs(date.timeIntervalSinceNow)
            #expect(timeDifference < 1.0)
        }
    }

    @Test
    func initializesForEditWithExistingContent() throws {
        let person = try makeTestPerson()
        let schema = makeTestSchema()

        var content = RecordContent(schemaId: testSchemaId)
        content.setString(ExampleSchema.FieldIds.exampleName, "Test Value")
        content.setDate(ExampleSchema.FieldIds.recordedDate, Date())

        let record = MedicalRecord(
            personId: person.id,
            encryptedContent: Data()
        )

        let viewModel = MedicalRecordFormViewModel(
            person: person,
            schema: schema,
            existingRecord: record,
            existingContent: content
        )

        #expect(viewModel.isEditing == true)
        #expect(viewModel.fieldValues[requiredStringFieldId]?.stringValue == "Test Value")
        #expect(viewModel.fieldValues[requiredDateFieldId]?.dateValue != nil)
    }

    // MARK: - Validation Tests

    @Test
    func validatePassesForValidData() throws {
        let person = try makeTestPerson()
        let schema = makeTestSchema()

        let viewModel = MedicalRecordFormViewModel(
            person: person,
            schema: schema
        )

        // Set required fields
        viewModel.fieldValues[requiredStringFieldId] = .string("Test Value")
        viewModel.fieldValues[requiredDateFieldId] = .date(Date())

        let result = viewModel.validate()

        #expect(result == true)
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    func validateFailsForMissingRequiredField() throws {
        let person = try makeTestPerson()
        let schema = makeTestSchema()

        let viewModel = MedicalRecordFormViewModel(
            person: person,
            schema: schema
        )

        // Missing required string field (date is pre-initialized)
        let result = viewModel.validate()

        #expect(result == false)
        #expect(viewModel.errorMessage != nil)
    }

    @Test
    func validateFailsForInvalidStringLength() throws {
        let person = try makeTestPerson()
        let schema = makeTestSchema()

        let viewModel = MedicalRecordFormViewModel(
            person: person,
            schema: schema
        )

        // Set required fields but with invalid string (empty violates minLength(1))
        viewModel.fieldValues[requiredStringFieldId] = .string("")
        viewModel.fieldValues[requiredDateFieldId] = .date(Date())

        let result = viewModel.validate()

        #expect(result == false)
        #expect(viewModel.errorMessage != nil)
    }

    // MARK: - Save Tests

    @Test
    func saveCreatesNewRecordWhenNotEditing() async throws {
        let person = try makeTestPerson()
        let schema = makeTestSchema()
        let mockRepo = MockMedicalRecordRepository()
        let mockContentService = MockRecordContentService()
        let mockPrimaryKeyProvider = MockPrimaryKeyProvider()
        let mockFMKService = MockFamilyMemberKeyService()

        mockPrimaryKeyProvider.primaryKey = SymmetricKey(size: .bits256)
        mockFMKService.setFMK(SymmetricKey(size: .bits256), for: person.id.uuidString)

        let viewModel = MedicalRecordFormViewModel(
            person: person,
            schema: schema,
            medicalRecordRepository: mockRepo,
            recordContentService: mockContentService,
            primaryKeyProvider: mockPrimaryKeyProvider,
            fmkService: mockFMKService
        )

        // Set valid data
        viewModel.fieldValues[requiredStringFieldId] = .string("Test Value")
        viewModel.fieldValues[requiredDateFieldId] = .date(Date())

        await viewModel.save()

        #expect(viewModel.didSaveSuccessfully == true)
        #expect(viewModel.errorMessage == nil)
        #expect(mockRepo.saveCallCount == 1)
    }

    @Test
    func saveUpdatesExistingRecordWhenEditing() async throws {
        let person = try makeTestPerson()
        let schema = makeTestSchema()
        let mockRepo = MockMedicalRecordRepository()
        let mockContentService = MockRecordContentService()
        let mockPrimaryKeyProvider = MockPrimaryKeyProvider()
        let mockFMKService = MockFamilyMemberKeyService()

        mockPrimaryKeyProvider.primaryKey = SymmetricKey(size: .bits256)
        mockFMKService.setFMK(SymmetricKey(size: .bits256), for: person.id.uuidString)

        let existingRecord = MedicalRecord(
            id: UUID(),
            personId: person.id,
            encryptedContent: Data(),
            version: 1
        )

        var existingContent = RecordContent(schemaId: testSchemaId)
        existingContent.setString(ExampleSchema.FieldIds.exampleName, "Original Value")
        existingContent.setDate(ExampleSchema.FieldIds.recordedDate, Date())

        let viewModel = MedicalRecordFormViewModel(
            person: person,
            schema: schema,
            existingRecord: existingRecord,
            existingContent: existingContent,
            medicalRecordRepository: mockRepo,
            recordContentService: mockContentService,
            primaryKeyProvider: mockPrimaryKeyProvider,
            fmkService: mockFMKService
        )

        // Modify data
        viewModel.fieldValues[requiredStringFieldId] = .string("Updated Value")

        await viewModel.save()

        #expect(viewModel.didSaveSuccessfully == true)
        #expect(mockRepo.saveCallCount == 1)
    }

    @Test
    func saveFailsWhenValidationFails() async throws {
        let person = try makeTestPerson()
        let schema = makeTestSchema()
        let mockRepo = MockMedicalRecordRepository()

        let viewModel = MedicalRecordFormViewModel(
            person: person,
            schema: schema,
            medicalRecordRepository: mockRepo
        )

        // Missing required string field (date is pre-initialized)
        await viewModel.save()

        #expect(viewModel.didSaveSuccessfully == false)
        #expect(viewModel.errorMessage != nil)
        #expect(mockRepo.saveCallCount == 0)
    }

    @Test
    func saveSetsErrorWhenEncryptionFails() async throws {
        let person = try makeTestPerson()
        let schema = makeTestSchema()
        let mockRepo = MockMedicalRecordRepository()
        let mockContentService = MockRecordContentService()
        let mockPrimaryKeyProvider = MockPrimaryKeyProvider()
        let mockFMKService = MockFamilyMemberKeyService()

        mockPrimaryKeyProvider.primaryKey = SymmetricKey(size: .bits256)
        mockFMKService.setFMK(SymmetricKey(size: .bits256), for: person.id.uuidString)
        mockContentService.shouldFailEncrypt = true

        let viewModel = MedicalRecordFormViewModel(
            person: person,
            schema: schema,
            medicalRecordRepository: mockRepo,
            recordContentService: mockContentService,
            primaryKeyProvider: mockPrimaryKeyProvider,
            fmkService: mockFMKService
        )

        // Set valid data
        viewModel.fieldValues[requiredStringFieldId] = .string("Test Value")
        viewModel.fieldValues[requiredDateFieldId] = .date(Date())

        await viewModel.save()

        #expect(viewModel.didSaveSuccessfully == false)
        #expect(viewModel.errorMessage != nil)
    }

    // MARK: - Additional Validation Tests

    @Test
    func validateReturnsTrueWhenAllRequiredFieldsPresent() throws {
        let person = try makeTestPerson()
        let schema = makeTestSchema()
        let viewModel = MedicalRecordFormViewModel(person: person, schema: schema)

        // Set required fields
        viewModel.fieldValues[requiredStringFieldId] = .string("Test Value")
        viewModel.fieldValues[requiredDateFieldId] = .date(Date())

        let result = viewModel.validate()

        #expect(result == true)
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    func validateReturnsFalseWhenRequiredFieldMissing() throws {
        let person = try makeTestPerson()
        let schema = makeTestSchema()
        let viewModel = MedicalRecordFormViewModel(person: person, schema: schema)

        // Only set one required field (string)
        viewModel.fieldValues[requiredStringFieldId] = .string("Test Value")
        // Date fields are pre-initialized with today's date, so clear it to test missing field
        viewModel.fieldValues.removeValue(forKey: requiredDateFieldId)

        let result = viewModel.validate()

        #expect(result == false)
        #expect(viewModel.errorMessage != nil)
    }

    @Test
    func validateSetsAppropriateErrorMessage() throws {
        let person = try makeTestPerson()
        let schema = makeTestSchema()
        let viewModel = MedicalRecordFormViewModel(person: person, schema: schema)

        // Missing required string field
        let result = viewModel.validate()

        #expect(result == false)
        #expect(viewModel.errorMessage?.contains("required") == true)
    }

    @Test
    func validateClearsErrorMessageOnSuccess() throws {
        let person = try makeTestPerson()
        let schema = makeTestSchema()
        let viewModel = MedicalRecordFormViewModel(person: person, schema: schema)

        // First cause a validation error
        _ = viewModel.validate()
        #expect(viewModel.errorMessage != nil)

        // Then set valid data and validate again
        viewModel.fieldValues[requiredStringFieldId] = .string("Test Value")
        viewModel.fieldValues[requiredDateFieldId] = .date(Date())
        let result = viewModel.validate()

        #expect(result == true)
        #expect(viewModel.errorMessage == nil)
    }

    // MARK: - Title Computed Property Tests

    @Test
    func titleForNewRecordShowsAdd() throws {
        let person = try makeTestPerson()
        let schema = makeTestSchema()

        let viewModel = MedicalRecordFormViewModel(person: person, schema: schema)

        #expect(viewModel.title == "Add Comprehensive Example")
    }

    @Test
    func titleForExistingRecordShowsEdit() throws {
        let person = try makeTestPerson()
        let schema = makeTestSchema()
        let existingRecord = MedicalRecord(personId: person.id, encryptedContent: Data())

        let viewModel = MedicalRecordFormViewModel(
            person: person,
            schema: schema,
            existingRecord: existingRecord
        )

        #expect(viewModel.title == "Edit Comprehensive Example")
    }
}
