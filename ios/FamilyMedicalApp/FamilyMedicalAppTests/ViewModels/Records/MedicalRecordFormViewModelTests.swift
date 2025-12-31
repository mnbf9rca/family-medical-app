import CryptoKit
import Foundation
import Testing
@testable import FamilyMedicalApp

@MainActor
struct MedicalRecordFormViewModelTests {
    // MARK: - Test Helpers

    func makeTestPerson() throws -> Person {
        try Person(
            id: UUID(),
            name: "Test Person",
            dateOfBirth: Date(),
            labels: ["Self"],
            notes: nil
        )
    }

    func makeVaccineSchema() -> RecordSchema {
        RecordSchema.builtIn(.vaccine)
    }

    // MARK: - Initialization Tests

    @Test
    func initializesForNewRecord() throws {
        let person = try makeTestPerson()
        let schema = makeVaccineSchema()

        let viewModel = MedicalRecordFormViewModel(
            person: person,
            schema: schema
        )

        #expect(viewModel.person.id == person.id)
        #expect(viewModel.schema.id == schema.id)
        #expect(viewModel.existingRecord == nil)
        #expect(viewModel.fieldValues.isEmpty)
        #expect(viewModel.isEditing == false)
        #expect(viewModel.didSaveSuccessfully == false)
    }

    @Test
    func initializesForEditWithExistingContent() throws {
        let person = try makeTestPerson()
        let schema = makeVaccineSchema()

        var content = RecordContent(schemaId: "vaccine")
        content.setString("vaccineName", "COVID-19")
        content.setDate("dateAdministered", Date())

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
        #expect(viewModel.fieldValues["vaccineName"]?.stringValue == "COVID-19")
        #expect(viewModel.fieldValues["dateAdministered"]?.dateValue != nil)
    }

    // MARK: - Validation Tests

    @Test
    func validatePassesForValidData() throws {
        let person = try makeTestPerson()
        let schema = makeVaccineSchema()

        let viewModel = MedicalRecordFormViewModel(
            person: person,
            schema: schema
        )

        // Set required fields
        viewModel.fieldValues["vaccineName"] = .string("COVID-19")
        viewModel.fieldValues["dateAdministered"] = .date(Date())

        let result = viewModel.validate()

        #expect(result == true)
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    func validateFailsForMissingRequiredField() throws {
        let person = try makeTestPerson()
        let schema = makeVaccineSchema()

        let viewModel = MedicalRecordFormViewModel(
            person: person,
            schema: schema
        )

        // Missing required fields
        let result = viewModel.validate()

        #expect(result == false)
        #expect(viewModel.errorMessage != nil)
    }

    @Test
    func validateFailsForInvalidStringLength() throws {
        let person = try makeTestPerson()
        let schema = makeVaccineSchema()

        let viewModel = MedicalRecordFormViewModel(
            person: person,
            schema: schema
        )

        // Set required fields
        viewModel.fieldValues["vaccineName"] = .string("") // Empty string
        viewModel.fieldValues["dateAdministered"] = .date(Date())

        let result = viewModel.validate()

        #expect(result == false)
        #expect(viewModel.errorMessage != nil)
    }

    // MARK: - Save Tests

    @Test
    func saveCreatesNewRecordWhenNotEditing() async throws {
        let person = try makeTestPerson()
        let schema = makeVaccineSchema()
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
        viewModel.fieldValues["vaccineName"] = .string("COVID-19")
        viewModel.fieldValues["dateAdministered"] = .date(Date())

        await viewModel.save()

        #expect(viewModel.didSaveSuccessfully == true)
        #expect(viewModel.errorMessage == nil)
        #expect(mockRepo.saveCallCount == 1)
    }

    @Test
    func saveUpdatesExistingRecordWhenEditing() async throws {
        let person = try makeTestPerson()
        let schema = makeVaccineSchema()
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

        var existingContent = RecordContent(schemaId: "vaccine")
        existingContent.setString("vaccineName", "COVID-19")
        existingContent.setDate("dateAdministered", Date())

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
        viewModel.fieldValues["vaccineName"] = .string("COVID-19 Moderna")

        await viewModel.save()

        #expect(viewModel.didSaveSuccessfully == true)
        #expect(mockRepo.saveCallCount == 1)
    }

    @Test
    func saveFailsWhenValidationFails() async throws {
        let person = try makeTestPerson()
        let schema = makeVaccineSchema()
        let mockRepo = MockMedicalRecordRepository()

        let viewModel = MedicalRecordFormViewModel(
            person: person,
            schema: schema,
            medicalRecordRepository: mockRepo
        )

        // Missing required fields
        await viewModel.save()

        #expect(viewModel.didSaveSuccessfully == false)
        #expect(viewModel.errorMessage != nil)
        #expect(mockRepo.saveCallCount == 0)
    }

    @Test
    func saveSetsErrorWhenEncryptionFails() async throws {
        let person = try makeTestPerson()
        let schema = makeVaccineSchema()
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
        viewModel.fieldValues["vaccineName"] = .string("COVID-19")
        viewModel.fieldValues["dateAdministered"] = .date(Date())

        await viewModel.save()

        #expect(viewModel.didSaveSuccessfully == false)
        #expect(viewModel.errorMessage != nil)
    }

    // MARK: - Validation Tests

    @Test
    func validateReturnsTrueWhenAllRequiredFieldsPresent() throws {
        let person = try makeTestPerson()
        let schema = makeVaccineSchema()
        let viewModel = MedicalRecordFormViewModel(person: person, schema: schema)

        // Set required fields
        viewModel.fieldValues["vaccineName"] = .string("COVID-19")
        viewModel.fieldValues["dateAdministered"] = .date(Date())

        let result = viewModel.validate()

        #expect(result == true)
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    func validateReturnsFalseWhenRequiredFieldMissing() throws {
        let person = try makeTestPerson()
        let schema = makeVaccineSchema()
        let viewModel = MedicalRecordFormViewModel(person: person, schema: schema)

        // Only set one required field
        viewModel.fieldValues["vaccineName"] = .string("COVID-19")
        // dateAdministered is required but missing

        let result = viewModel.validate()

        #expect(result == false)
        #expect(viewModel.errorMessage != nil)
    }

    @Test
    func validateSetsAppropriateErrorMessage() throws {
        let person = try makeTestPerson()
        let schema = makeVaccineSchema()
        let viewModel = MedicalRecordFormViewModel(person: person, schema: schema)

        // Missing required field
        let result = viewModel.validate()

        #expect(result == false)
        #expect(viewModel.errorMessage?.contains("required") == true)
    }

    // MARK: - ModelError UserFacingMessage Tests

    @Test
    func modelErrorProducesUserFriendlyMessages() {
        let error1 = ModelError.fieldRequired(fieldName: "vaccine name")
        #expect(error1.userFacingMessage == "vaccine name is required.")

        let error2 = ModelError.stringTooLong(fieldName: "name", maxLength: 100)
        #expect(error2.userFacingMessage.contains("100") == true)

        let error3 = ModelError.numberOutOfRange(fieldName: "dose", min: 1, max: nil)
        #expect(error3.userFacingMessage.contains("at least 1") == true)
    }
}
