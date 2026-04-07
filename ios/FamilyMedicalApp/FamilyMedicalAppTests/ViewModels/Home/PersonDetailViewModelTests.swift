import CryptoKit
import Foundation
import Testing
@testable import FamilyMedicalApp

@MainActor
struct PersonDetailViewModelTests {
    // MARK: - Test Data

    let testPrimaryKey = SymmetricKey(size: .bits256)
    let testFMK = SymmetricKey(size: .bits256)

    func createTestPerson() throws -> Person {
        try PersonTestHelper.makeTestPerson()
    }

    func createTestRecord(person: Person, recordType: RecordType) throws -> MedicalRecord {
        // Create test envelope
        let envelope: RecordContentEnvelope = switch recordType {
        case .immunization:
            try RecordContentEnvelope(
                ImmunizationRecord(vaccineCode: "Test", occurrenceDate: Date())
            )
        case .condition:
            try RecordContentEnvelope(
                ConditionRecord(conditionName: "Test", onsetDate: Date())
            )
        case .medicationStatement:
            try RecordContentEnvelope(
                MedicationStatementRecord(medicationName: "Test")
            )
        default:
            RecordContentEnvelope(
                recordType: recordType,
                schemaVersion: 1,
                content: Data("{\"notes\":null,\"tags\":[]}".utf8)
            )
        }

        // Encrypt it
        let service = MockRecordContentService()
        let encryptedData = try service.encrypt(envelope, using: testFMK)

        return MedicalRecord(
            id: UUID(),
            personId: person.id,
            encryptedContent: encryptedData
        )
    }

    // MARK: - Load Record Counts Tests

    @Test
    func loadRecordCountsSucceedsWithMultipleRecordTypes() async throws {
        let person = try createTestPerson()

        // Create test records with different types
        let mockRecordRepo = MockMedicalRecordRepository()
        let mockContentService = MockRecordContentService()

        let vaccineRecord = try createTestRecord(person: person, recordType: .immunization)
        let conditionRecord = try createTestRecord(person: person, recordType: .condition)
        let medicationRecord = try createTestRecord(person: person, recordType: .medicationStatement)

        mockRecordRepo.addRecord(vaccineRecord)
        mockRecordRepo.addRecord(conditionRecord)
        mockRecordRepo.addRecord(medicationRecord)

        // Set up content service to return the correct envelopes
        let vaccineEnvelope = try RecordContentEnvelope(
            ImmunizationRecord(vaccineCode: "Test", occurrenceDate: Date())
        )
        let conditionEnvelope = try RecordContentEnvelope(
            ConditionRecord(conditionName: "Test", onsetDate: Date())
        )
        let medicationEnvelope = try RecordContentEnvelope(
            MedicationStatementRecord(medicationName: "Test")
        )
        mockContentService.setEnvelope(vaccineEnvelope, for: vaccineRecord.encryptedContent)
        mockContentService.setEnvelope(conditionEnvelope, for: conditionRecord.encryptedContent)
        mockContentService.setEnvelope(medicationEnvelope, for: medicationRecord.encryptedContent)

        let mockKeyProvider = MockPrimaryKeyProvider(primaryKey: testPrimaryKey)
        let mockFMKService = MockFamilyMemberKeyService()
        mockFMKService.setFMK(testFMK, for: person.id.uuidString)

        let viewModel = PersonDetailViewModel(
            person: person,
            medicalRecordRepository: mockRecordRepo,
            recordContentService: mockContentService,
            primaryKeyProvider: mockKeyProvider,
            fmkService: mockFMKService,
            providerRepository: MockProviderRepository()
        )

        await viewModel.loadRecordCounts()

        #expect(viewModel.recordCounts[.immunization] == 1)
        #expect(viewModel.recordCounts[.condition] == 1)
        #expect(viewModel.recordCounts[.medicationStatement] == 1)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.isLoading == false)
    }

    @Test
    func loadRecordCountsGroupsMultipleRecordsOfSameType() async throws {
        let person = try createTestPerson()

        let mockRecordRepo = MockMedicalRecordRepository()
        let mockContentService = MockRecordContentService()

        // Create 3 immunization records
        for _ in 0 ..< 3 {
            let record = try createTestRecord(person: person, recordType: .immunization)
            mockRecordRepo.addRecord(record)
            let envelope = try RecordContentEnvelope(
                ImmunizationRecord(vaccineCode: "Test", occurrenceDate: Date())
            )
            mockContentService.setEnvelope(envelope, for: record.encryptedContent)
        }

        let mockKeyProvider = MockPrimaryKeyProvider(primaryKey: testPrimaryKey)
        let mockFMKService = MockFamilyMemberKeyService()
        mockFMKService.setFMK(testFMK, for: person.id.uuidString)

        let viewModel = PersonDetailViewModel(
            person: person,
            medicalRecordRepository: mockRecordRepo,
            recordContentService: mockContentService,
            primaryKeyProvider: mockKeyProvider,
            fmkService: mockFMKService,
            providerRepository: MockProviderRepository()
        )

        await viewModel.loadRecordCounts()

        #expect(viewModel.recordCounts[.immunization] == 3)
        #expect(viewModel.recordCounts.count == 1) // Only one record type
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    func loadRecordCountsReturnsEmptyWhenNoRecords() async throws {
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
            fmkService: mockFMKService,
            providerRepository: MockProviderRepository()
        )

        await viewModel.loadRecordCounts()

        #expect(viewModel.recordCounts.isEmpty)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.isLoading == false)
    }

    @Test
    func loadRecordCountsSetsErrorWhenPrimaryKeyNotAvailable() async throws {
        let person = try createTestPerson()

        let mockRecordRepo = MockMedicalRecordRepository()
        let mockContentService = MockRecordContentService()
        let mockKeyProvider = MockPrimaryKeyProvider(primaryKey: nil) // No key
        let mockFMKService = MockFamilyMemberKeyService()

        let viewModel = PersonDetailViewModel(
            person: person,
            medicalRecordRepository: mockRecordRepo,
            recordContentService: mockContentService,
            primaryKeyProvider: mockKeyProvider,
            fmkService: mockFMKService,
            providerRepository: MockProviderRepository()
        )

        await viewModel.loadRecordCounts()

        #expect(viewModel.recordCounts.isEmpty)
        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.errorMessage?.contains("Unable to load") == true)
        #expect(viewModel.isLoading == false)
    }

    @Test
    func loadRecordCountsSetsErrorWhenFMKNotAvailable() async throws {
        let person = try createTestPerson()

        let mockRecordRepo = MockMedicalRecordRepository()
        let mockContentService = MockRecordContentService()
        let mockKeyProvider = MockPrimaryKeyProvider(primaryKey: testPrimaryKey)
        let mockFMKService = MockFamilyMemberKeyService()
        // Don't set FMK - will fail to retrieve

        let viewModel = PersonDetailViewModel(
            person: person,
            medicalRecordRepository: mockRecordRepo,
            recordContentService: mockContentService,
            primaryKeyProvider: mockKeyProvider,
            fmkService: mockFMKService,
            providerRepository: MockProviderRepository()
        )

        await viewModel.loadRecordCounts()

        #expect(viewModel.recordCounts.isEmpty)
        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.isLoading == false)
    }

    @Test
    func loadRecordCountsSetsErrorWhenRepositoryFails() async throws {
        let person = try createTestPerson()

        let mockRecordRepo = MockMedicalRecordRepository()
        mockRecordRepo.shouldFailFetch = true

        let mockContentService = MockRecordContentService()
        let mockKeyProvider = MockPrimaryKeyProvider(primaryKey: testPrimaryKey)
        let mockFMKService = MockFamilyMemberKeyService()
        mockFMKService.setFMK(testFMK, for: person.id.uuidString)

        let viewModel = PersonDetailViewModel(
            person: person,
            medicalRecordRepository: mockRecordRepo,
            recordContentService: mockContentService,
            primaryKeyProvider: mockKeyProvider,
            fmkService: mockFMKService,
            providerRepository: MockProviderRepository()
        )

        await viewModel.loadRecordCounts()

        #expect(viewModel.recordCounts.isEmpty)
        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.isLoading == false)
    }

    @Test
    func loadRecordCountsSetsErrorWhenDecryptionFails() async throws {
        let person = try createTestPerson()

        let mockRecordRepo = MockMedicalRecordRepository()
        let mockContentService = MockRecordContentService()
        mockContentService.shouldFailDecrypt = true

        let record = try createTestRecord(person: person, recordType: .immunization)
        mockRecordRepo.addRecord(record)

        let mockKeyProvider = MockPrimaryKeyProvider(primaryKey: testPrimaryKey)
        let mockFMKService = MockFamilyMemberKeyService()
        mockFMKService.setFMK(testFMK, for: person.id.uuidString)

        let viewModel = PersonDetailViewModel(
            person: person,
            medicalRecordRepository: mockRecordRepo,
            recordContentService: mockContentService,
            primaryKeyProvider: mockKeyProvider,
            fmkService: mockFMKService,
            providerRepository: MockProviderRepository()
        )

        await viewModel.loadRecordCounts()

        // Decryption errors are logged per-record, not fatal
        #expect(viewModel.recordCounts.isEmpty)
        #expect(viewModel.isLoading == false)
    }

    // MARK: - Provider Count Tests

    @Test
    func loadRecordCountsIncludesProviderCount() async throws {
        let person = try createTestPerson()

        let mockRecordRepo = MockMedicalRecordRepository()
        let mockContentService = MockRecordContentService()
        let mockKeyProvider = MockPrimaryKeyProvider(primaryKey: testPrimaryKey)
        let mockFMKService = MockFamilyMemberKeyService()
        mockFMKService.setFMK(testFMK, for: person.id.uuidString)

        let mockProviderRepo = MockProviderRepository()
        mockProviderRepo.addProvider(
            Provider(name: "Dr. Smith"),
            personId: person.id
        )
        mockProviderRepo.addProvider(
            Provider(organization: "City Hospital"),
            personId: person.id
        )

        let viewModel = PersonDetailViewModel(
            person: person,
            medicalRecordRepository: mockRecordRepo,
            recordContentService: mockContentService,
            primaryKeyProvider: mockKeyProvider,
            fmkService: mockFMKService,
            providerRepository: mockProviderRepo
        )

        await viewModel.loadRecordCounts()

        #expect(viewModel.providerCount == 2)
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    func loadRecordCountsProviderCountZeroWhenNoProviders() async throws {
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
            fmkService: mockFMKService,
            providerRepository: MockProviderRepository()
        )

        await viewModel.loadRecordCounts()

        #expect(viewModel.providerCount == 0)
        #expect(viewModel.errorMessage == nil)
    }
}
