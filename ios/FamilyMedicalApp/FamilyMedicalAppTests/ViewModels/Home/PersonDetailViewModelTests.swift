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
        try Person(
            id: UUID(),
            name: "Test Person",
            dateOfBirth: Date(),
            labels: ["Self"],
            notes: nil
        )
    }

    func createTestRecord(person: Person, schemaId: String) throws -> MedicalRecord {
        // Create test content
        let content = RecordContent(schemaId: schemaId)

        // Encrypt it
        let service = MockRecordContentService()
        let encryptedData = try service.encrypt(content, using: testFMK)

        return try MedicalRecord(
            id: UUID(),
            personId: person.id,
            encryptedContent: encryptedData
        )
    }

    // MARK: - Load Record Counts Tests

    @Test
    func loadRecordCountsSucceedsWithMultipleRecordTypes() async throws {
        let person = try createTestPerson()

        // Create test records with different schema IDs
        let mockRecordRepo = MockMedicalRecordRepository()
        let mockContentService = MockRecordContentService()

        let vaccineRecord = try createTestRecord(person: person, schemaId: "vaccine")
        let conditionRecord = try createTestRecord(person: person, schemaId: "condition")
        let medicationRecord = try createTestRecord(person: person, schemaId: "medication")

        mockRecordRepo.addRecord(vaccineRecord)
        mockRecordRepo.addRecord(conditionRecord)
        mockRecordRepo.addRecord(medicationRecord)

        // Set up content service to return the correct content
        mockContentService.setContent(
            RecordContent(schemaId: "vaccine"),
            for: vaccineRecord.encryptedContent
        )
        mockContentService.setContent(
            RecordContent(schemaId: "condition"),
            for: conditionRecord.encryptedContent
        )
        mockContentService.setContent(
            RecordContent(schemaId: "medication"),
            for: medicationRecord.encryptedContent
        )

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

        #expect(viewModel.recordCounts["vaccine"] == 1)
        #expect(viewModel.recordCounts["condition"] == 1)
        #expect(viewModel.recordCounts["medication"] == 1)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.isLoading == false)
    }

    @Test
    func loadRecordCountsGroupsMultipleRecordsOfSameType() async throws {
        let person = try createTestPerson()

        let mockRecordRepo = MockMedicalRecordRepository()
        let mockContentService = MockRecordContentService()

        // Create 3 vaccine records
        for _ in 0 ..< 3 {
            let record = try createTestRecord(person: person, schemaId: "vaccine")
            mockRecordRepo.addRecord(record)
            mockContentService.setContent(
                RecordContent(schemaId: "vaccine"),
                for: record.encryptedContent
            )
        }

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

        #expect(viewModel.recordCounts["vaccine"] == 3)
        #expect(viewModel.recordCounts.count == 1) // Only one schema type
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
            fmkService: mockFMKService
        )

        await viewModel.loadRecordCounts()

        #expect(viewModel.recordCounts.isEmpty)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.isLoading == false)
    }

    @Test
    func loadRecordCountsHandlesRecordsWithoutSchemaId() async throws {
        let person = try createTestPerson()

        let mockRecordRepo = MockMedicalRecordRepository()
        let mockContentService = MockRecordContentService()

        // Create a record with no schema ID
        var content = RecordContent()
        content.schemaId = nil // Freeform record
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

        // Records without schema ID should not be counted
        #expect(viewModel.recordCounts.isEmpty)
        #expect(viewModel.errorMessage == nil)
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
            fmkService: mockFMKService
        )

        await viewModel.loadRecordCounts()

        #expect(viewModel.recordCounts.isEmpty)
        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.errorMessage?.contains("Failed to load") == true)
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
            fmkService: mockFMKService
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
            fmkService: mockFMKService
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

        let record = try createTestRecord(person: person, schemaId: "vaccine")
        mockRecordRepo.addRecord(record)

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

        #expect(viewModel.recordCounts.isEmpty)
        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.isLoading == false)
    }
}
