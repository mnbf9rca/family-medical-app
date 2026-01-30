import CryptoKit
import Foundation
import Testing
@testable import FamilyMedicalApp

@Suite("ExportService Extended Tests")
struct ExportServiceExtendedTests {
    // MARK: - Test Setup

    let testPrimaryKey = SymmetricKey(size: .bits256)

    func makeService(
        personRepository: MockPersonRepository = MockPersonRepository(),
        recordRepository: MockMedicalRecordRepository = MockMedicalRecordRepository(),
        recordContentService: MockRecordContentService = MockRecordContentService(),
        attachmentService: MockAttachmentService = MockAttachmentService(),
        customSchemaRepository: MockCustomSchemaRepository = MockCustomSchemaRepository(),
        fmkService: MockFamilyMemberKeyService = MockFamilyMemberKeyService()
    ) -> ExportService {
        ExportService(
            personRepository: personRepository,
            recordRepository: recordRepository,
            recordContentService: recordContentService,
            attachmentService: attachmentService,
            customSchemaRepository: customSchemaRepository,
            fmkService: fmkService
        )
    }

    func makeTestPerson(name: String = "Test Person") throws -> Person {
        try Person(
            id: UUID(),
            name: name,
            dateOfBirth: Date(),
            labels: ["child"],
            notes: "Test notes"
        )
    }

    func makeTestRecordContent(schemaId: String = "vaccine") -> RecordContent {
        RecordContent(
            schemaId: schemaId,
            fields: ["vaccine-name": .string("COVID-19")]
        )
    }

    func makeTestAttachment() throws -> FamilyMedicalApp.Attachment {
        try FamilyMedicalApp.Attachment(
            id: UUID(),
            fileName: "test.pdf",
            mimeType: "application/pdf",
            contentHMAC: Data(repeating: 0x01, count: 32),
            encryptedSize: 1_024,
            thumbnailData: nil,
            uploadedAt: Date()
        )
    }

    func makeTestSchema() throws -> RecordSchema {
        try RecordSchema(
            id: "custom-test",
            displayName: "Test Schema",
            iconSystemName: "star",
            fields: []
        )
    }

    // MARK: - Full Export Tests

    @Test("Full export includes all data types")
    func fullExportIncludesAllData() async throws {
        let personRepository = MockPersonRepository()
        let recordRepository = MockMedicalRecordRepository()
        let recordContentService = MockRecordContentService()
        let attachmentService = MockAttachmentService()
        let customSchemaRepository = MockCustomSchemaRepository()
        let fmkService = MockFamilyMemberKeyService()

        let person = try makeTestPerson(name: "Full Test")
        let fmk = SymmetricKey(size: .bits256)
        personRepository.addPerson(person)
        fmkService.setFMK(fmk, for: person.id.uuidString)

        let content = makeTestRecordContent()
        let encryptedContent = try recordContentService.encrypt(content, using: fmk)
        let record = MedicalRecord(
            id: UUID(),
            personId: person.id,
            encryptedContent: encryptedContent,
            createdAt: Date(),
            updatedAt: Date(),
            version: 1,
            previousVersionId: nil
        )
        recordRepository.addRecord(record)

        let attachment = try makeTestAttachment()
        attachmentService.addTestAttachment(
            attachment,
            content: Data("content".utf8),
            linkedToRecord: record.id
        )

        let schema = try makeTestSchema()
        customSchemaRepository.addSchema(schema, forPerson: person.id)

        let service = makeService(
            personRepository: personRepository,
            recordRepository: recordRepository,
            recordContentService: recordContentService,
            attachmentService: attachmentService,
            customSchemaRepository: customSchemaRepository,
            fmkService: fmkService
        )

        let payload = try await service.exportData(primaryKey: testPrimaryKey)

        #expect(payload.persons.count == 1)
        #expect(payload.records.count == 1)
        #expect(payload.attachments.count == 1)
        #expect(payload.schemas.count == 1)
        #expect(!payload.isEmpty)
    }

    // MARK: - Error Handling Tests

    @Test("Throws error when person fetch fails")
    func throwsOnPersonFetchFailure() async throws {
        let personRepository = MockPersonRepository()
        personRepository.shouldFailFetchAll = true

        let service = makeService(personRepository: personRepository)

        await #expect(throws: BackupError.self) {
            _ = try await service.exportData(primaryKey: testPrimaryKey)
        }
    }

    @Test("Throws error when record fetch fails")
    func throwsOnRecordFetchFailure() async throws {
        let personRepository = MockPersonRepository()
        let recordRepository = MockMedicalRecordRepository()
        let fmkService = MockFamilyMemberKeyService()

        let person = try makeTestPerson()
        personRepository.addPerson(person)
        fmkService.setFMK(SymmetricKey(size: .bits256), for: person.id.uuidString)
        recordRepository.shouldFailFetch = true

        let service = makeService(
            personRepository: personRepository,
            recordRepository: recordRepository,
            fmkService: fmkService
        )

        await #expect(throws: BackupError.self) {
            _ = try await service.exportData(primaryKey: testPrimaryKey)
        }
    }

    @Test("Throws error when FMK retrieval fails")
    func throwsOnFMKRetrievalFailure() async throws {
        let personRepository = MockPersonRepository()
        let fmkService = MockFamilyMemberKeyService()

        let person = try makeTestPerson()
        personRepository.addPerson(person)
        fmkService.shouldFailRetrieve = true

        let service = makeService(
            personRepository: personRepository,
            fmkService: fmkService
        )

        await #expect(throws: BackupError.self) {
            _ = try await service.exportData(primaryKey: testPrimaryKey)
        }
    }

    // MARK: - Metadata Tests

    @Test("Export metadata contains correct counts")
    func exportMetadataContainsCorrectCounts() async throws {
        let personRepository = MockPersonRepository()
        let recordRepository = MockMedicalRecordRepository()
        let recordContentService = MockRecordContentService()
        let fmkService = MockFamilyMemberKeyService()

        let person1 = try makeTestPerson(name: "Person 1")
        let person2 = try makeTestPerson(name: "Person 2")
        let fmk1 = SymmetricKey(size: .bits256)
        let fmk2 = SymmetricKey(size: .bits256)
        personRepository.addPerson(person1)
        personRepository.addPerson(person2)
        fmkService.setFMK(fmk1, for: person1.id.uuidString)
        fmkService.setFMK(fmk2, for: person2.id.uuidString)

        // Add 2 records for person1
        for _ in 0 ..< 2 {
            let content = makeTestRecordContent()
            let encryptedContent = try recordContentService.encrypt(content, using: fmk1)
            let record = MedicalRecord(
                id: UUID(),
                personId: person1.id,
                encryptedContent: encryptedContent,
                createdAt: Date(),
                updatedAt: Date(),
                version: 1,
                previousVersionId: nil
            )
            recordRepository.addRecord(record)
        }

        // Add 1 record for person2
        let content = makeTestRecordContent()
        let encryptedContent = try recordContentService.encrypt(content, using: fmk2)
        let record = MedicalRecord(
            id: UUID(),
            personId: person2.id,
            encryptedContent: encryptedContent,
            createdAt: Date(),
            updatedAt: Date(),
            version: 1,
            previousVersionId: nil
        )
        recordRepository.addRecord(record)

        let service = makeService(
            personRepository: personRepository,
            recordRepository: recordRepository,
            recordContentService: recordContentService,
            fmkService: fmkService
        )

        let payload = try await service.exportData(primaryKey: testPrimaryKey)

        #expect(payload.metadata.personCount == 2)
        #expect(payload.metadata.recordCount == 3)
    }

    @Test("Export includes app version")
    func exportIncludesAppVersion() async throws {
        let service = makeService()

        let payload = try await service.exportData(primaryKey: testPrimaryKey)

        #expect(!payload.appVersion.isEmpty)
    }

    @Test("Export includes timestamp")
    func exportIncludesTimestamp() async throws {
        let beforeExport = Date()
        let service = makeService()

        let payload = try await service.exportData(primaryKey: testPrimaryKey)

        let afterExport = Date()
        #expect(payload.exportedAt >= beforeExport)
        #expect(payload.exportedAt <= afterExport)
    }
}
