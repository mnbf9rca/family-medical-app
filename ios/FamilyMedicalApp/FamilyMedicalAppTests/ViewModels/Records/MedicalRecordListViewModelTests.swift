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
        #expect(viewModel.schema == nil)
        #expect(viewModel.records.isEmpty)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
    }

    // MARK: - Load Records Tests

    @Test
    func loadRecordsSucceedsWithValidData() async throws {
        let person = try makeTestPerson()
        let mockRepo = MockMedicalRecordRepository()
        let mockContentService = MockRecordContentService()
        let mockPrimaryKeyProvider = MockPrimaryKeyProvider()
        let mockFMKService = MockFamilyMemberKeyService()

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
            fmkService: mockFMKService
        )

        await viewModel.loadRecords()

        #expect(viewModel.records.count == 1)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.isLoading == false)
    }

    @Test
    func loadRecordsFiltersbySchemaType() async throws {
        let person = try makeTestPerson()
        let mockRepo = MockMedicalRecordRepository()
        let mockContentService = MockRecordContentService()
        let mockPrimaryKeyProvider = MockPrimaryKeyProvider()
        let mockFMKService = MockFamilyMemberKeyService()

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
            fmkService: mockFMKService
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
    }

    @Test
    func loadRecordsSetsErrorWhenRepositoryFails() async throws {
        let person = try makeTestPerson()
        let mockRepo = MockMedicalRecordRepository()
        let mockPrimaryKeyProvider = MockPrimaryKeyProvider()
        let mockFMKService = MockFamilyMemberKeyService()

        mockPrimaryKeyProvider.primaryKey = SymmetricKey(size: .bits256)
        mockFMKService.setFMK(SymmetricKey(size: .bits256), for: person.id.uuidString)

        // Simulate repository failure
        mockRepo.shouldFailFetch = true

        let viewModel = MedicalRecordListViewModel(
            person: person,
            schemaType: .vaccine,
            medicalRecordRepository: mockRepo,
            primaryKeyProvider: mockPrimaryKeyProvider,
            fmkService: mockFMKService
        )

        await viewModel.loadRecords()

        #expect(viewModel.errorMessage != nil)
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

    // MARK: - Schema Service Tests

    @Test
    func loadRecordsUsesSchemaFromService() async throws {
        let person = try makeTestPerson()
        let mockRepo = MockMedicalRecordRepository()
        let mockContentService = MockRecordContentService()
        let mockPrimaryKeyProvider = MockPrimaryKeyProvider()
        let mockFMKService = MockFamilyMemberKeyService()
        let mockSchemaService = MockSchemaService()

        mockPrimaryKeyProvider.primaryKey = SymmetricKey(size: .bits256)
        mockFMKService.setFMK(SymmetricKey(size: .bits256), for: person.id.uuidString)

        // Store a MODIFIED schema in the mock service (user renamed "Vaccine" to "Immunization")
        let customSchema = RecordSchema(
            unsafeId: "vaccine",
            displayName: "Immunization Record",
            iconSystemName: "cross.vial",
            fields: RecordSchema.builtIn(.vaccine).fields,
            isBuiltIn: true,
            description: nil
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

        // ViewModel should use the user's schema, not the hardcoded default
        #expect(viewModel.schema?.displayName == "Immunization Record")
        #expect(viewModel.schema?.iconSystemName == "cross.vial")
        #expect(mockSchemaService.schemaCallCount == 1)
    }

    @Test
    func loadRecordsSetsErrorWhenSchemaServiceFails() async throws {
        let person = try makeTestPerson()
        let mockRepo = MockMedicalRecordRepository()
        let mockContentService = MockRecordContentService()
        let mockPrimaryKeyProvider = MockPrimaryKeyProvider()
        let mockFMKService = MockFamilyMemberKeyService()
        let mockSchemaService = MockSchemaService()

        mockPrimaryKeyProvider.primaryKey = SymmetricKey(size: .bits256)
        mockFMKService.setFMK(SymmetricKey(size: .bits256), for: person.id.uuidString)

        // Schema service will throw
        mockSchemaService.shouldFailFetch = true

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

        // Schema fetch failure is fatal - records should not load
        #expect(viewModel.schema == nil)
        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.records.isEmpty)
        #expect(viewModel.isLoading == false)
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
