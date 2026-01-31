import CryptoKit
import Foundation
import Testing
@testable import FamilyMedicalApp

@Suite("ExportService Tests")
struct ExportServiceTests {
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

    // MARK: - Empty Export Tests

    @Test("Exports empty payload when no data exists")
    func exportsEmptyPayload() async throws {
        let service = makeService()

        let payload = try await service.exportData(primaryKey: testPrimaryKey)

        #expect(payload.isEmpty)
        #expect(payload.persons.isEmpty)
        #expect(payload.records.isEmpty)
        #expect(payload.attachments.isEmpty)
        #expect(payload.schemas.isEmpty)
        #expect(payload.metadata.personCount == 0)
    }

    // MARK: - Person Export Tests

    @Test("Exports persons correctly")
    func exportsPersons() async throws {
        let personRepository = MockPersonRepository()
        let fmkService = MockFamilyMemberKeyService()

        let person = try makeTestPerson(name: "Alice")
        personRepository.addPerson(person)
        fmkService.setFMK(SymmetricKey(size: .bits256), for: person.id.uuidString)

        let service = makeService(
            personRepository: personRepository,
            fmkService: fmkService
        )

        let payload = try await service.exportData(primaryKey: testPrimaryKey)

        #expect(payload.persons.count == 1)
        #expect(payload.persons[0].name == "Alice")
        #expect(payload.persons[0].id == person.id)
        #expect(payload.metadata.personCount == 1)
    }

    @Test("Exports multiple persons")
    func exportsMultiplePersons() async throws {
        let personRepository = MockPersonRepository()
        let fmkService = MockFamilyMemberKeyService()

        let alice = try makeTestPerson(name: "Alice")
        let bob = try makeTestPerson(name: "Bob")
        personRepository.addPerson(alice)
        personRepository.addPerson(bob)
        fmkService.setFMK(SymmetricKey(size: .bits256), for: alice.id.uuidString)
        fmkService.setFMK(SymmetricKey(size: .bits256), for: bob.id.uuidString)

        let service = makeService(
            personRepository: personRepository,
            fmkService: fmkService
        )

        let payload = try await service.exportData(primaryKey: testPrimaryKey)

        #expect(payload.persons.count == 2)
        #expect(payload.metadata.personCount == 2)
    }

    // MARK: - Medical Record Export Tests

    @Test("Exports medical records for persons")
    func exportsMedicalRecords() async throws {
        let personRepository = MockPersonRepository()
        let recordRepository = MockMedicalRecordRepository()
        let recordContentService = MockRecordContentService()
        let fmkService = MockFamilyMemberKeyService()

        let person = try makeTestPerson()
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

        let service = makeService(
            personRepository: personRepository,
            recordRepository: recordRepository,
            recordContentService: recordContentService,
            fmkService: fmkService
        )

        let payload = try await service.exportData(primaryKey: testPrimaryKey)

        #expect(payload.records.count == 1)
        #expect(payload.records[0].personId == person.id)
        #expect(payload.records[0].schemaId == "vaccine")
        #expect(payload.metadata.recordCount == 1)
    }

    // MARK: - Attachment Export Tests

    @Test("Exports attachments for records")
    func exportsAttachments() async throws {
        let personRepository = MockPersonRepository()
        let recordRepository = MockMedicalRecordRepository()
        let recordContentService = MockRecordContentService()
        let attachmentService = MockAttachmentService()
        let fmkService = MockFamilyMemberKeyService()

        let person = try makeTestPerson()
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
        let attachmentContent = Data("PDF content".utf8)
        attachmentService.addTestAttachment(attachment, content: attachmentContent, linkedToRecord: record.id)

        let service = makeService(
            personRepository: personRepository,
            recordRepository: recordRepository,
            recordContentService: recordContentService,
            attachmentService: attachmentService,
            fmkService: fmkService
        )

        let payload = try await service.exportData(primaryKey: testPrimaryKey)

        #expect(payload.attachments.count == 1)
        #expect(payload.attachments[0].fileName == "test.pdf")
        #expect(payload.attachments[0].contentData == attachmentContent)
        #expect(payload.metadata.attachmentCount == 1)
    }

    // MARK: - Schema Export Tests

    @Test("Exports custom schemas for persons")
    func exportsCustomSchemas() async throws {
        let personRepository = MockPersonRepository()
        let customSchemaRepository = MockCustomSchemaRepository()
        let fmkService = MockFamilyMemberKeyService()

        let person = try makeTestPerson()
        let fmk = SymmetricKey(size: .bits256)
        personRepository.addPerson(person)
        fmkService.setFMK(fmk, for: person.id.uuidString)

        let schema = try makeTestSchema()
        customSchemaRepository.addSchema(schema, forPerson: person.id)

        let service = makeService(
            personRepository: personRepository,
            customSchemaRepository: customSchemaRepository,
            fmkService: fmkService
        )

        let payload = try await service.exportData(primaryKey: testPrimaryKey)

        #expect(payload.schemas.count == 1)
        #expect(payload.schemas[0].schema.id == "custom-test")
        #expect(payload.schemas[0].personId == person.id)
        #expect(payload.metadata.schemaCount == 1)
    }
}
