import CryptoKit
import Foundation
import Testing
@testable import FamilyMedicalApp

@MainActor
struct MedicalRecordListViewModelTests {
    // MARK: - Test Helpers

    func makeTestPerson() throws -> Person {
        try PersonTestHelper.makeTestPerson()
    }

    func makeTestEnvelope(recordType: RecordType = .immunization) throws -> RecordContentEnvelope {
        switch recordType {
        case .immunization:
            try RecordContentEnvelope(
                ImmunizationRecord(vaccineCode: "COVID-19", occurrenceDate: Date())
            )
        case .medicationStatement:
            try RecordContentEnvelope(
                MedicationStatementRecord(medicationName: "Aspirin")
            )
        default:
            RecordContentEnvelope(
                recordType: recordType,
                schemaVersion: 1,
                content: Data("{\"notes\":null,\"tags\":[]}".utf8)
            )
        }
    }

    // MARK: - Initialization Tests

    @Test
    func initializesWithPersonAndRecordType() throws {
        let person = try makeTestPerson()
        let viewModel = MedicalRecordListViewModel(
            person: person,
            recordType: .immunization
        )

        #expect(viewModel.person.id == person.id)
        #expect(viewModel.recordType == .immunization)
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
        let fmk = SymmetricKey(size: .bits256)
        mockFMKService.setFMK(fmk, for: person.id.uuidString)

        // Create test record
        let envelope = try makeTestEnvelope(recordType: .immunization)
        let encryptedData = try mockContentService.encrypt(envelope, using: fmk)
        let record1 = MedicalRecord(
            personId: person.id,
            encryptedContent: encryptedData
        )
        mockRepo.addRecord(record1)

        let viewModel = MedicalRecordListViewModel(
            person: person,
            recordType: .immunization,
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
    func loadRecordsFiltersByRecordType() async throws {
        let person = try makeTestPerson()
        let mockRepo = MockMedicalRecordRepository()
        let mockContentService = MockRecordContentService()
        let mockPrimaryKeyProvider = MockPrimaryKeyProvider()
        let mockFMKService = MockFamilyMemberKeyService()

        mockPrimaryKeyProvider.primaryKey = SymmetricKey(size: .bits256)
        let fmk = SymmetricKey(size: .bits256)
        mockFMKService.setFMK(fmk, for: person.id.uuidString)

        // Add immunization record
        let immunizationEnvelope = try makeTestEnvelope(recordType: .immunization)
        let immunizationData = try mockContentService.encrypt(immunizationEnvelope, using: fmk)
        let vaccineRecord = MedicalRecord(
            personId: person.id,
            encryptedContent: immunizationData
        )
        mockRepo.addRecord(vaccineRecord)

        // Add medication record
        let medicationEnvelope = try makeTestEnvelope(recordType: .medicationStatement)
        let medicationData = try mockContentService.encrypt(medicationEnvelope, using: fmk)
        let medRecord = MedicalRecord(
            personId: person.id,
            encryptedContent: medicationData
        )
        mockRepo.addRecord(medRecord)

        let viewModel = MedicalRecordListViewModel(
            person: person,
            recordType: .immunization,
            medicalRecordRepository: mockRepo,
            recordContentService: mockContentService,
            primaryKeyProvider: mockPrimaryKeyProvider,
            fmkService: mockFMKService
        )

        await viewModel.loadRecords()

        // Should only have immunization record
        #expect(viewModel.records.count == 1)
        #expect(viewModel.records.first?.recordType == .immunization)
    }

    @Test
    func loadRecordsSetsErrorWhenPrimaryKeyNotAvailable() async throws {
        let person = try makeTestPerson()
        let mockPrimaryKeyProvider = MockPrimaryKeyProvider()

        // Simulate missing primary key
        mockPrimaryKeyProvider.shouldFail = true

        let viewModel = MedicalRecordListViewModel(
            person: person,
            recordType: .immunization,
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
            recordType: .immunization,
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

        let record = MedicalRecord(
            personId: person.id,
            encryptedContent: Data()
        )

        let viewModel = MedicalRecordListViewModel(
            person: person,
            recordType: .immunization,
            medicalRecordRepository: mockRepo,
            primaryKeyProvider: mockPrimaryKeyProvider
        )

        // Manually add to records for testing
        let envelope = try makeTestEnvelope()
        viewModel.records = [DecryptedRecord(record: record, envelope: envelope)]

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

        let record = MedicalRecord(
            personId: person.id,
            encryptedContent: Data()
        )

        let viewModel = MedicalRecordListViewModel(
            person: person,
            recordType: .immunization,
            medicalRecordRepository: mockRepo
        )

        let envelope = try makeTestEnvelope()
        viewModel.records = [DecryptedRecord(record: record, envelope: envelope)]

        await viewModel.deleteRecord(id: record.id)

        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.records.count == 1) // Should not remove on failure
    }

    // MARK: - Cascade Delete Tests

    @Test
    func cascadeDeleteSkipsBlobDeletionWhenPrefetchFails() async throws {
        let person = try makeTestPerson()
        let mockRepo = MockMedicalRecordRepository()
        let mockContentService = MockRecordContentService()
        let mockPrimaryKeyProvider = MockPrimaryKeyProvider()
        let mockFMKService = MockFamilyMemberKeyService()
        let mockDocRefService = MockDocumentReferenceQueryService()
        let mockBlobService = MockDocumentBlobService()

        let primaryKey = SymmetricKey(size: .bits256)
        mockPrimaryKeyProvider.primaryKey = primaryKey
        let fmk = SymmetricKey(size: .bits256)
        mockFMKService.setFMK(fmk, for: person.id.uuidString)

        // Make allDocuments() throw to simulate prefetch failure
        mockDocRefService.allDocumentsError = ModelError.documentContentCorrupted

        // Create a parent record
        let parentEnvelope = try makeTestEnvelope(recordType: .immunization)
        let parentEncrypted = try mockContentService.encrypt(parentEnvelope, using: fmk)
        let parentRecord = MedicalRecord(personId: person.id, encryptedContent: parentEncrypted)
        mockRepo.addRecord(parentRecord)

        // Create an attachment to pass to cascadeDelete
        let attachment = PersistedDocumentReference(
            recordId: UUID(),
            content: DocumentReferenceRecord(
                title: "scan.jpg",
                mimeType: "image/jpeg",
                fileSize: 1_024,
                contentHMAC: Data(repeating: 0xAB, count: 32)
            ),
            createdAt: Date(),
            updatedAt: Date()
        )

        let viewModel = MedicalRecordListViewModel(
            person: person,
            recordType: .immunization,
            medicalRecordRepository: mockRepo,
            recordContentService: mockContentService,
            primaryKeyProvider: mockPrimaryKeyProvider,
            fmkService: mockFMKService,
            documentReferenceQueryService: mockDocRefService,
            blobService: mockBlobService
        )

        let envelope = try makeTestEnvelope()
        viewModel.records = [DecryptedRecord(record: parentRecord, envelope: envelope)]

        await viewModel.deleteRecord(
            id: parentRecord.id,
            strategy: .cascadeDelete,
            attachments: [attachment]
        )

        // Parent record deleted
        #expect(viewModel.records.isEmpty)
        // Attachment record also deleted (via medicalRecordRepository.delete)
        #expect(mockRepo.deleteCallCount == 2)
        // Blob deletion skipped because prefetch failed
        #expect(mockBlobService.deleteCalls.isEmpty)
    }

    @Test
    func cascadeDeleteDeletesBlobsWhenPrefetchSucceeds() async throws {
        let person = try makeTestPerson()
        let mockRepo = MockMedicalRecordRepository()
        let mockContentService = MockRecordContentService()
        let mockPrimaryKeyProvider = MockPrimaryKeyProvider()
        let mockFMKService = MockFamilyMemberKeyService()
        let mockDocRefService = MockDocumentReferenceQueryService()
        let mockBlobService = MockDocumentBlobService()

        let primaryKey = SymmetricKey(size: .bits256)
        mockPrimaryKeyProvider.primaryKey = primaryKey
        let fmk = SymmetricKey(size: .bits256)
        mockFMKService.setFMK(fmk, for: person.id.uuidString)

        // Prefetch succeeds with empty list (no other refs)
        mockDocRefService.allDocumentsResult = []

        let parentEnvelope = try makeTestEnvelope(recordType: .immunization)
        let parentEncrypted = try mockContentService.encrypt(parentEnvelope, using: fmk)
        let parentRecord = MedicalRecord(personId: person.id, encryptedContent: parentEncrypted)
        mockRepo.addRecord(parentRecord)

        let hmac = Data(repeating: 0xAB, count: 32)
        let attachment = PersistedDocumentReference(
            recordId: UUID(),
            content: DocumentReferenceRecord(
                title: "scan.jpg",
                mimeType: "image/jpeg",
                fileSize: 1_024,
                contentHMAC: hmac
            ),
            createdAt: Date(),
            updatedAt: Date()
        )

        let viewModel = MedicalRecordListViewModel(
            person: person,
            recordType: .immunization,
            medicalRecordRepository: mockRepo,
            recordContentService: mockContentService,
            primaryKeyProvider: mockPrimaryKeyProvider,
            fmkService: mockFMKService,
            documentReferenceQueryService: mockDocRefService,
            blobService: mockBlobService
        )

        let envelope = try makeTestEnvelope()
        viewModel.records = [DecryptedRecord(record: parentRecord, envelope: envelope)]

        await viewModel.deleteRecord(
            id: parentRecord.id,
            strategy: .cascadeDelete,
            attachments: [attachment]
        )

        // Blob deletion proceeds when prefetch succeeds
        #expect(mockBlobService.deleteCalls.count == 1)
        let call = try #require(mockBlobService.deleteCalls.first)
        #expect(call.contentHMAC == hmac)
        #expect(call.personId == person.id)
        #expect(call.isReferencedElsewhere == false)
    }
}
