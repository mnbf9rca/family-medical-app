import CryptoKit
import Foundation
import Testing
@testable import FamilyMedicalApp

@Suite("ImportService Validation Tests")
struct ImportServiceValidationTests {
    // MARK: - Test Setup

    let testPrimaryKey = SymmetricKey(size: .bits256)

    func makeService(
        personRepository: MockPersonRepository = MockPersonRepository(),
        recordRepository: MockMedicalRecordRepository = MockMedicalRecordRepository(),
        recordContentService: MockRecordContentService = MockRecordContentService(),
        attachmentService: MockAttachmentService = MockAttachmentService(),
        customSchemaRepository: MockCustomSchemaRepository = MockCustomSchemaRepository(),
        fmkService: MockFamilyMemberKeyService = MockFamilyMemberKeyService()
    ) -> ImportService {
        ImportService(
            personRepository: personRepository,
            recordRepository: recordRepository,
            recordContentService: recordContentService,
            attachmentService: attachmentService,
            customSchemaRepository: customSchemaRepository,
            fmkService: fmkService
        )
    }

    func makeTestPayload(
        persons: [PersonBackup] = [],
        records: [MedicalRecordBackup] = [],
        attachments: [AttachmentBackup] = [],
        schemas: [SchemaBackup] = []
    ) -> BackupPayload {
        BackupPayload(
            exportedAt: Date(),
            appVersion: "1.0.0",
            metadata: BackupMetadata(
                personCount: persons.count,
                recordCount: records.count,
                attachmentCount: attachments.count,
                schemaCount: schemas.count
            ),
            persons: persons,
            records: records,
            attachments: attachments,
            schemas: schemas
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

    func makeRecordBackup(personId: UUID, schemaId: String = "vaccine") -> MedicalRecordBackup {
        MedicalRecordBackup(
            id: UUID(),
            personId: personId,
            schemaId: schemaId,
            fields: ["vaccine-name": FieldValueBackup(type: "string", value: .string("COVID-19"))],
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

    func makeSchemaBackup(personId: UUID) throws -> SchemaBackup {
        let schema = try RecordSchema(
            id: "custom-test",
            displayName: "Test Schema",
            iconSystemName: "star",
            fields: []
        )
        return SchemaBackup(personId: personId, schema: schema)
    }

    // MARK: - Attachment ID Preservation Tests

    @Test("Preserves attachment ID during import")
    func preservesAttachmentId() async throws {
        let personRepository = MockPersonRepository()
        let recordRepository = MockMedicalRecordRepository()
        let attachmentService = MockAttachmentService()
        let fmkService = MockFamilyMemberKeyService()

        let service = makeService(
            personRepository: personRepository,
            recordRepository: recordRepository,
            attachmentService: attachmentService,
            fmkService: fmkService
        )

        let personBackup = makePersonBackup()
        let recordBackup = makeRecordBackup(personId: personBackup.id)
        let attachmentBackup = makeAttachmentBackup(personId: personBackup.id, recordId: recordBackup.id)
        let payload = makeTestPayload(
            persons: [personBackup],
            records: [recordBackup],
            attachments: [attachmentBackup]
        )

        try await service.importData(payload, primaryKey: testPrimaryKey)

        // Verify the backup ID was passed to AttachmentService
        #expect(attachmentService.addAttachmentCalls.count == 1)
        let call = attachmentService.addAttachmentCalls[0]
        #expect(call.id == attachmentBackup.id)
    }

    @Test("Throws error when attachment has no linked record")
    func throwsForAttachmentWithNoLinkedRecord() async throws {
        let personRepository = MockPersonRepository()
        let attachmentService = MockAttachmentService()
        let fmkService = MockFamilyMemberKeyService()

        let service = makeService(
            personRepository: personRepository,
            attachmentService: attachmentService,
            fmkService: fmkService
        )

        let personBackup = makePersonBackup()
        // Create attachment with empty linkedRecordIds
        let attachmentBackup = AttachmentBackup(
            id: UUID(),
            personId: personBackup.id,
            linkedRecordIds: [], // No linked records!
            fileName: "test.pdf",
            mimeType: "application/pdf",
            content: Data("PDF content".utf8),
            thumbnail: nil,
            uploadedAt: Date()
        )
        let payload = makeTestPayload(
            persons: [personBackup],
            attachments: [attachmentBackup]
        )

        await #expect(throws: BackupError.self) {
            try await service.importData(payload, primaryKey: testPrimaryKey)
        }
    }

    // MARK: - Record Field Validation Tests

    @Test("Throws corruptedFile when record has invalid field type")
    func throwsForInvalidFieldType() async throws {
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
        // Create record with invalid field type
        let recordBackup = MedicalRecordBackup(
            id: UUID(),
            personId: personBackup.id,
            schemaId: "vaccine",
            fields: ["badField": FieldValueBackup(type: "unknownType", value: .string("value"))],
            createdAt: Date(),
            updatedAt: Date(),
            version: 1,
            previousVersionId: nil
        )
        let payload = makeTestPayload(persons: [personBackup], records: [recordBackup])

        await #expect(throws: BackupError.corruptedFile) {
            try await service.importData(payload, primaryKey: testPrimaryKey)
        }
    }

    @Test("Throws corruptedFile when record field has type mismatch")
    func throwsForFieldTypeMismatch() async throws {
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
        // Create record with type mismatch (int type but string value)
        let recordBackup = MedicalRecordBackup(
            id: UUID(),
            personId: personBackup.id,
            schemaId: "vaccine",
            fields: ["dose": FieldValueBackup(type: "int", value: .string("one"))],
            createdAt: Date(),
            updatedAt: Date(),
            version: 1,
            previousVersionId: nil
        )
        let payload = makeTestPayload(persons: [personBackup], records: [recordBackup])

        await #expect(throws: BackupError.corruptedFile) {
            try await service.importData(payload, primaryKey: testPrimaryKey)
        }
    }
}
