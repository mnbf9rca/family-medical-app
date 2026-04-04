import CryptoKit
import Foundation
import Testing
@testable import FamilyMedicalApp

@Suite("ImportService Tests")
struct ImportServiceTests {
    // MARK: - Test Setup

    let testPrimaryKey = SymmetricKey(size: .bits256)

    func makeService(
        personRepository: MockPersonRepository = MockPersonRepository(),
        recordRepository: MockMedicalRecordRepository = MockMedicalRecordRepository(),
        recordContentService: MockRecordContentService = MockRecordContentService(),
        attachmentService: MockAttachmentService = MockAttachmentService(),
        fmkService: MockFamilyMemberKeyService = MockFamilyMemberKeyService()
    ) -> ImportService {
        ImportService(
            personRepository: personRepository,
            recordRepository: recordRepository,
            recordContentService: recordContentService,
            attachmentService: attachmentService,
            fmkService: fmkService
        )
    }

    func makeTestPayload(
        persons: [PersonBackup] = [],
        records: [MedicalRecordBackup] = [],
        attachments: [AttachmentBackup] = []
    ) -> BackupPayload {
        BackupPayload(
            exportedAt: Date(),
            appVersion: "1.0.0",
            metadata: BackupMetadata(
                personCount: persons.count,
                recordCount: records.count,
                attachmentCount: attachments.count
            ),
            persons: persons,
            records: records,
            attachments: attachments
        )
    }

    func makePersonBackup(name: String = "Test Person") -> PersonBackup {
        PersonBackup(
            id: UUID(),
            name: name,
            dateOfBirth: Date(),
            labels: ["child"],
            notes: "Test notes",
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    func makeRecordBackup(personId: UUID) throws -> MedicalRecordBackup {
        let immunization = ImmunizationRecord(vaccineCode: "COVID-19", occurrenceDate: Date())
        let contentJSON = try JSONEncoder().encode(immunization)
        return MedicalRecordBackup(
            id: UUID(),
            personId: personId,
            recordType: "immunization",
            schemaVersion: 1,
            contentJSON: contentJSON,
            createdAt: Date(),
            updatedAt: Date(),
            version: 1,
            previousVersionId: nil
        )
    }

    func makeAttachmentBackup(personId: UUID, recordId: UUID) -> AttachmentBackup {
        AttachmentBackup(
            id: UUID(),
            personId: personId,
            linkedRecordIds: [recordId],
            fileName: "test.pdf",
            mimeType: "application/pdf",
            content: Data("PDF content".utf8),
            thumbnail: nil,
            uploadedAt: Date()
        )
    }

    // MARK: - Empty Import Tests

    @Test("Imports empty payload without error")
    func importsEmptyPayload() async throws {
        let service = makeService()
        let payload = makeTestPayload()

        try await service.importData(payload, primaryKey: testPrimaryKey)

        // No errors thrown means success
    }

    // MARK: - Person Import Tests

    @Test("Imports persons correctly")
    func importsPersons() async throws {
        let personRepository = MockPersonRepository()
        let fmkService = MockFamilyMemberKeyService()
        let service = makeService(personRepository: personRepository, fmkService: fmkService)

        let personBackup = makePersonBackup(name: "Alice")
        let payload = makeTestPayload(persons: [personBackup])

        try await service.importData(payload, primaryKey: testPrimaryKey)

        #expect(personRepository.saveCallCount == 1)
        let saved = personRepository.getAllPersons()
        #expect(saved.count == 1)
        #expect(saved[0].name == "Alice")
        #expect(saved[0].id == personBackup.id)
    }

    @Test("Imports multiple persons")
    func importsMultiplePersons() async throws {
        let personRepository = MockPersonRepository()
        let fmkService = MockFamilyMemberKeyService()
        let service = makeService(personRepository: personRepository, fmkService: fmkService)

        let alice = makePersonBackup(name: "Alice")
        let bob = makePersonBackup(name: "Bob")
        let payload = makeTestPayload(persons: [alice, bob])

        try await service.importData(payload, primaryKey: testPrimaryKey)

        #expect(personRepository.saveCallCount == 2)
        #expect(personRepository.getAllPersons().count == 2)
    }

    @Test("Creates FMK for imported persons")
    func createsFMKForImportedPersons() async throws {
        let personRepository = MockPersonRepository()
        let fmkService = MockFamilyMemberKeyService()
        let service = makeService(personRepository: personRepository, fmkService: fmkService)

        let personBackup = makePersonBackup()
        let payload = makeTestPayload(persons: [personBackup])

        try await service.importData(payload, primaryKey: testPrimaryKey)

        #expect(fmkService.generateCalls == 1)
        #expect(fmkService.storeCallsCount == 1)
    }

    // MARK: - Record Import Tests

    @Test("Imports medical records for persons")
    func importsMedicalRecords() async throws {
        let personRepository = MockPersonRepository()
        let recordRepository = MockMedicalRecordRepository()
        let recordContentService = MockRecordContentService()
        let fmkService = MockFamilyMemberKeyService()

        let service = makeService(
            personRepository: personRepository,
            recordRepository: recordRepository,
            recordContentService: recordContentService,
            fmkService: fmkService
        )

        let personBackup = makePersonBackup()
        let recordBackup = try makeRecordBackup(personId: personBackup.id)
        let payload = makeTestPayload(persons: [personBackup], records: [recordBackup])

        try await service.importData(payload, primaryKey: testPrimaryKey)

        #expect(recordRepository.saveCallCount == 1)
        #expect(recordContentService.encryptCallCount == 1)
        let records = recordRepository.getAllRecords()
        #expect(records.count == 1)
        #expect(records[0].personId == personBackup.id)
    }

    // MARK: - Error Handling Tests

    @Test("Throws error when person save fails")
    func throwsOnPersonSaveFailure() async throws {
        let personRepository = MockPersonRepository()
        personRepository.shouldFailSave = true

        let service = makeService(personRepository: personRepository)

        let personBackup = makePersonBackup()
        let payload = makeTestPayload(persons: [personBackup])

        await #expect(throws: BackupError.self) {
            try await service.importData(payload, primaryKey: testPrimaryKey)
        }
    }

    @Test("Throws error when FMK generation fails")
    func throwsOnFMKGenerationFailure() async throws {
        let personRepository = MockPersonRepository()
        let fmkService = MockFamilyMemberKeyService()
        fmkService.shouldFailStore = true

        let service = makeService(personRepository: personRepository, fmkService: fmkService)

        let personBackup = makePersonBackup()
        let payload = makeTestPayload(persons: [personBackup])

        await #expect(throws: BackupError.self) {
            try await service.importData(payload, primaryKey: testPrimaryKey)
        }
    }

    @Test("Throws error when record save fails")
    func throwsOnRecordSaveFailure() async throws {
        let personRepository = MockPersonRepository()
        let recordRepository = MockMedicalRecordRepository()
        let fmkService = MockFamilyMemberKeyService()
        recordRepository.shouldFailSave = true

        let service = makeService(
            personRepository: personRepository,
            recordRepository: recordRepository,
            fmkService: fmkService
        )

        let personBackup = makePersonBackup()
        let recordBackup = try makeRecordBackup(personId: personBackup.id)
        let payload = makeTestPayload(persons: [personBackup], records: [recordBackup])

        await #expect(throws: BackupError.self) {
            try await service.importData(payload, primaryKey: testPrimaryKey)
        }
    }
}
