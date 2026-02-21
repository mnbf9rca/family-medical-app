import CryptoKit
import Foundation
import Testing
@testable import FamilyMedicalApp

@MainActor
struct MedicalRecordListViewModelTests {
    // MARK: - Test Field IDs

    /// Test UUID for generic test fields
    private static let testFieldId = UUID()

    // MARK: - Test Helpers

    func makeTestPerson() throws -> Person {
        try PersonTestHelper.makeTestPerson()
    }

    func makeTestRecord(personId: UUID, schemaId: String, dateFieldId: UUID, date: Date) -> MedicalRecord {
        var content = RecordContent(schemaId: schemaId)
        content.setDate(dateFieldId, date)
        content.setString(Self.testFieldId, "test value")

        // Create unique encrypted content for each record (use schemaId for uniqueness)
        let encryptedData = Data("encrypted-\(schemaId)".utf8)

        return MedicalRecord(
            personId: personId,
            encryptedContent: encryptedData
        )
    }

    // MARK: - Initialization Tests

    @Test
    func initializesWithPersonAndSchemaType() throws {
        let person = try makeTestPerson()
        let viewModel = MedicalRecordListViewModel(
            person: person,
            schemaType: .vaccine
        )

        #expect(viewModel.person.id == person.id)
        #expect(viewModel.schemaType == .vaccine)
        #expect(viewModel.records.isEmpty)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.schema == nil)
    }

    // MARK: - Load Records Tests

    @Test
    func loadRecordsSucceedsWithValidData() async throws {
        let person = try makeTestPerson()
        let mockRepo = MockMedicalRecordRepository()
        let mockContentService = MockRecordContentService()
        let mockPrimaryKeyProvider = MockPrimaryKeyProvider()
        let mockFMKService = MockFamilyMemberKeyService()
        let mockSchemaService = MockSchemaService()

        // Set up mocks
        mockPrimaryKeyProvider.primaryKey = SymmetricKey(size: .bits256)
        mockFMKService.setFMK(SymmetricKey(size: .bits256), for: person.id.uuidString)

        // Create test records
        let record1 = makeTestRecord(
            personId: person.id,
            schemaId: "vaccine",
            dateFieldId: BuiltInFieldIds.Vaccine.dateAdministered,
            date: Date()
        )
        mockRepo.addRecord(record1)

        // Mock decryption
        var content1 = RecordContent(schemaId: "vaccine")
        content1.setDate(BuiltInFieldIds.Vaccine.dateAdministered, Date())
        mockContentService.setContent(content1, for: record1.encryptedContent)

        let viewModel = MedicalRecordListViewModel(
            person: person,
            schemaType: .vaccine,
            medicalRecordRepository: mockRepo,
            recordContentService: mockContentService,
            primaryKeyProvider: mockPrimaryKeyProvider,
            fmkService: mockFMKService,
            schemaService: mockSchemaService
        )

        await viewModel.loadRecords()

        #expect(viewModel.records.count == 1)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.schema != nil)
    }

    @Test
    func loadRecordsUsesCustomSchemaFromService() async throws {
        let person = try makeTestPerson()
        let mockRepo = MockMedicalRecordRepository()
        let mockContentService = MockRecordContentService()
        let mockPrimaryKeyProvider = MockPrimaryKeyProvider()
        let mockFMKService = MockFamilyMemberKeyService()
        let mockSchemaService = MockSchemaService()

        // Set up mocks
        mockPrimaryKeyProvider.primaryKey = SymmetricKey(size: .bits256)
        mockFMKService.setFMK(SymmetricKey(size: .bits256), for: person.id.uuidString)

        // Create test record
        let record = makeTestRecord(
            personId: person.id,
            schemaId: "vaccine",
            dateFieldId: BuiltInFieldIds.Vaccine.dateAdministered,
            date: Date()
        )
        mockRepo.addRecord(record)

        // Mock decryption
        var content = RecordContent(schemaId: "vaccine")
        content.setDate(BuiltInFieldIds.Vaccine.dateAdministered, Date())
        mockContentService.setContent(content, for: record.encryptedContent)

        // Store custom schema with modified displayName
        let customSchema = RecordSchema(
            unsafeId: "vaccine",
            displayName: "Immunization",
            iconSystemName: "cross.vial",
            fields: RecordSchema.builtIn(.vaccine).fields,
            isBuiltIn: true
        )
        mockSchemaService.addSchema(customSchema, forPerson: person.id)

        let viewModel = MedicalRecordListViewModel(
            person: person,
            schemaType: .vaccine,
            medicalRecordRepository: mockRepo,
            recordContentService: mockContentService,
            primaryKeyProvider: mockPrimaryKeyProvider,
            fmkService: mockFMKService,
            schemaService: mockSchemaService
        )

        await viewModel.loadRecords()

        #expect(viewModel.schema?.displayName == "Immunization")
    }

    @Test
    func loadRecordsFiltersbySchemaType() async throws {
        let person = try makeTestPerson()
        let mockRepo = MockMedicalRecordRepository()
        let mockContentService = MockRecordContentService()
        let mockPrimaryKeyProvider = MockPrimaryKeyProvider()
        let mockFMKService = MockFamilyMemberKeyService()
        let mockSchemaService = MockSchemaService()

        mockPrimaryKeyProvider.primaryKey = SymmetricKey(size: .bits256)
        mockFMKService.setFMK(SymmetricKey(size: .bits256), for: person.id.uuidString)

        // Add vaccine record
        let vaccineRecord = makeTestRecord(
            personId: person.id,
            schemaId: "vaccine",
            dateFieldId: BuiltInFieldIds.Vaccine.dateAdministered,
            date: Date()
        )
        mockRepo.addRecord(vaccineRecord)

        // Add medication record
        let medRecord = makeTestRecord(
            personId: person.id,
            schemaId: "medication",
            dateFieldId: BuiltInFieldIds.Medication.startDate,
            date: Date()
        )
        mockRepo.addRecord(medRecord)

        // Mock decryption to return correct schema
        var vaccineContent = RecordContent(schemaId: "vaccine")
        vaccineContent.setDate(BuiltInFieldIds.Vaccine.dateAdministered, Date())
        mockContentService.setContent(vaccineContent, for: vaccineRecord.encryptedContent)

        var medContent = RecordContent(schemaId: "medication")
        medContent.setDate(BuiltInFieldIds.Medication.startDate, Date())
        mockContentService.setContent(medContent, for: medRecord.encryptedContent)

        let viewModel = MedicalRecordListViewModel(
            person: person,
            schemaType: .vaccine,
            medicalRecordRepository: mockRepo,
            recordContentService: mockContentService,
            primaryKeyProvider: mockPrimaryKeyProvider,
            fmkService: mockFMKService,
            schemaService: mockSchemaService
        )

        await viewModel.loadRecords()

        // Should only have vaccine record
        #expect(viewModel.records.count == 1)
        #expect(viewModel.records.first?.content.schemaId == "vaccine")
    }

    @Test
    func loadRecordsSetsErrorWhenPrimaryKeyNotAvailable() async throws {
        let person = try makeTestPerson()
        let mockPrimaryKeyProvider = MockPrimaryKeyProvider()

        // Simulate missing primary key
        mockPrimaryKeyProvider.shouldFail = true

        let viewModel = MedicalRecordListViewModel(
            person: person,
            schemaType: .vaccine,
            primaryKeyProvider: mockPrimaryKeyProvider
        )

        await viewModel.loadRecords()

        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.records.isEmpty)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.schema == nil)
    }

    @Test
    func loadRecordsSetsErrorWhenRepositoryFails() async throws {
        let person = try makeTestPerson()
        let mockRepo = MockMedicalRecordRepository()
        let mockPrimaryKeyProvider = MockPrimaryKeyProvider()
        let mockFMKService = MockFamilyMemberKeyService()
        let mockSchemaService = MockSchemaService()

        mockPrimaryKeyProvider.primaryKey = SymmetricKey(size: .bits256)
        mockFMKService.setFMK(SymmetricKey(size: .bits256), for: person.id.uuidString)

        // Simulate repository failure
        mockRepo.shouldFailFetch = true

        let viewModel = MedicalRecordListViewModel(
            person: person,
            schemaType: .vaccine,
            medicalRecordRepository: mockRepo,
            primaryKeyProvider: mockPrimaryKeyProvider,
            fmkService: mockFMKService,
            schemaService: mockSchemaService
        )

        await viewModel.loadRecords()

        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.records.isEmpty)
        #expect(viewModel.isLoading == false)
    }

    @Test
    func loadRecordsSetsErrorWhenSchemaServiceFails() async throws {
        let person = try makeTestPerson()
        let mockPrimaryKeyProvider = MockPrimaryKeyProvider()
        let mockFMKService = MockFamilyMemberKeyService()
        let mockSchemaService = MockSchemaService()

        mockPrimaryKeyProvider.primaryKey = SymmetricKey(size: .bits256)
        mockFMKService.setFMK(SymmetricKey(size: .bits256), for: person.id.uuidString)

        // Simulate schema service failure
        mockSchemaService.shouldFailFetch = true

        let viewModel = MedicalRecordListViewModel(
            person: person,
            schemaType: .vaccine,
            primaryKeyProvider: mockPrimaryKeyProvider,
            fmkService: mockFMKService,
            schemaService: mockSchemaService
        )

        await viewModel.loadRecords()

        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.schema == nil)
        #expect(viewModel.records.isEmpty)
        #expect(viewModel.isLoading == false)
    }

    // MARK: - Delete Record Tests

    @Test
    func deleteRecordSucceeds() async throws {
        let person = try makeTestPerson()
        let mockRepo = MockMedicalRecordRepository()
        let mockPrimaryKeyProvider = MockPrimaryKeyProvider()

        mockPrimaryKeyProvider.primaryKey = SymmetricKey(size: .bits256)

        let record = makeTestRecord(
            personId: person.id,
            schemaId: "vaccine",
            dateFieldId: BuiltInFieldIds.Vaccine.dateAdministered,
            date: Date()
        )

        let viewModel = MedicalRecordListViewModel(
            person: person,
            schemaType: .vaccine,
            medicalRecordRepository: mockRepo,
            primaryKeyProvider: mockPrimaryKeyProvider
        )

        // Manually add to records for testing
        let content = RecordContent(schemaId: "vaccine")
        viewModel.records = [DecryptedRecord(record: record, content: content)]

        await viewModel.deleteRecord(id: record.id)

        #expect(viewModel.records.isEmpty)
        #expect(viewModel.errorMessage == nil)
        #expect(mockRepo.deleteCallCount == 1)
    }

    @Test
    func deleteRecordSetsErrorOnFailure() async throws {
        let person = try makeTestPerson()
        let mockRepo = MockMedicalRecordRepository()

        // Simulate delete failure
        mockRepo.shouldFailDelete = true

        let record = makeTestRecord(
            personId: person.id,
            schemaId: "vaccine",
            dateFieldId: BuiltInFieldIds.Vaccine.dateAdministered,
            date: Date()
        )

        let viewModel = MedicalRecordListViewModel(
            person: person,
            schemaType: .vaccine,
            medicalRecordRepository: mockRepo
        )

        let content = RecordContent(schemaId: "vaccine")
        viewModel.records = [DecryptedRecord(record: record, content: content)]

        await viewModel.deleteRecord(id: record.id)

        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.records.count == 1) // Should not remove on failure
    }
}
