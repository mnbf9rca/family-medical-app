import CryptoKit
import Foundation
import Testing
@testable import FamilyMedicalApp

@Suite("ImportService Extended Tests")
struct ImportServiceExtendedTests {
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

    // MARK: - Attachment Import Tests

    @Test("Imports attachments for records")
    func importsAttachments() async throws {
        let personRepository = MockPersonRepository()
        let recordRepository = MockMedicalRecordRepository()
        let recordContentService = MockRecordContentService()
        let attachmentService = MockAttachmentService()
        let fmkService = MockFamilyMemberKeyService()

        let service = makeService(
            personRepository: personRepository,
            recordRepository: recordRepository,
            recordContentService: recordContentService,
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

        #expect(attachmentService.addAttachmentCalls.count == 1)
        #expect(attachmentService.addAttachmentCalls[0].fileName == "test.pdf")
    }

    // MARK: - Full Import Tests

    @Test("Full import includes all data types")
    func fullImportIncludesAllData() async throws {
        let personRepository = MockPersonRepository()
        let recordRepository = MockMedicalRecordRepository()
        let recordContentService = MockRecordContentService()
        let attachmentService = MockAttachmentService()
        let customSchemaRepository = MockCustomSchemaRepository()
        let fmkService = MockFamilyMemberKeyService()

        let service = makeService(
            personRepository: personRepository,
            recordRepository: recordRepository,
            recordContentService: recordContentService,
            attachmentService: attachmentService,
            customSchemaRepository: customSchemaRepository,
            fmkService: fmkService
        )

        let personBackup = makePersonBackup(name: "Full Test")
        let recordBackup = makeRecordBackup(personId: personBackup.id)
        let attachmentBackup = makeAttachmentBackup(personId: personBackup.id, recordId: recordBackup.id)
        let schemaBackup = try makeSchemaBackup(personId: personBackup.id)

        let payload = makeTestPayload(
            persons: [personBackup],
            records: [recordBackup],
            attachments: [attachmentBackup],
            schemas: [schemaBackup]
        )

        try await service.importData(payload, primaryKey: testPrimaryKey)

        #expect(personRepository.saveCallCount == 1)
        #expect(recordRepository.saveCallCount == 1)
        #expect(attachmentService.addAttachmentCalls.count == 1)
        #expect(customSchemaRepository.saveCallCount == 1)
    }

    // MARK: - Error Handling Tests

    @Test("Throws error when attachment save fails")
    func throwsOnAttachmentSaveFailure() async throws {
        let personRepository = MockPersonRepository()
        let recordRepository = MockMedicalRecordRepository()
        let attachmentService = MockAttachmentService()
        let fmkService = MockFamilyMemberKeyService()
        attachmentService.shouldFailAddAttachment = true

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

        await #expect(throws: BackupError.self) {
            try await service.importData(payload, primaryKey: testPrimaryKey)
        }
    }

    @Test("Throws error when schema save fails")
    func throwsOnSchemaSaveFailure() async throws {
        let personRepository = MockPersonRepository()
        let customSchemaRepository = MockCustomSchemaRepository()
        let fmkService = MockFamilyMemberKeyService()
        customSchemaRepository.shouldFailSave = true

        let service = makeService(
            personRepository: personRepository,
            customSchemaRepository: customSchemaRepository,
            fmkService: fmkService
        )

        let personBackup = makePersonBackup()
        let schemaBackup = try makeSchemaBackup(personId: personBackup.id)
        let payload = makeTestPayload(persons: [personBackup], schemas: [schemaBackup])

        await #expect(throws: BackupError.self) {
            try await service.importData(payload, primaryKey: testPrimaryKey)
        }
    }

    @Test("Throws error when record has no matching person FMK")
    func throwsWhenRecordHasNoPersonFMK() async throws {
        let personRepository = MockPersonRepository()
        let recordRepository = MockMedicalRecordRepository()
        let fmkService = MockFamilyMemberKeyService()

        let service = makeService(
            personRepository: personRepository,
            recordRepository: recordRepository,
            fmkService: fmkService
        )

        // Record references a person that isn't being imported
        let unrelatedPersonId = UUID()
        let recordBackup = makeRecordBackup(personId: unrelatedPersonId)
        let payload = makeTestPayload(records: [recordBackup])

        await #expect(throws: BackupError.self) {
            try await service.importData(payload, primaryKey: testPrimaryKey)
        }
    }

    @Test("Throws error when attachment has no matching person FMK")
    func throwsWhenAttachmentHasNoPersonFMK() async throws {
        let personRepository = MockPersonRepository()
        let attachmentService = MockAttachmentService()
        let fmkService = MockFamilyMemberKeyService()

        let service = makeService(
            personRepository: personRepository,
            attachmentService: attachmentService,
            fmkService: fmkService
        )

        // Attachment references a person that isn't being imported
        let unrelatedPersonId = UUID()
        let recordId = UUID()
        let attachmentBackup = makeAttachmentBackup(personId: unrelatedPersonId, recordId: recordId)
        let payload = makeTestPayload(attachments: [attachmentBackup])

        await #expect(throws: BackupError.self) {
            try await service.importData(payload, primaryKey: testPrimaryKey)
        }
    }

    @Test("Throws error when schema has no matching person FMK")
    func throwsWhenSchemaHasNoPersonFMK() async throws {
        let personRepository = MockPersonRepository()
        let customSchemaRepository = MockCustomSchemaRepository()
        let fmkService = MockFamilyMemberKeyService()

        let service = makeService(
            personRepository: personRepository,
            customSchemaRepository: customSchemaRepository,
            fmkService: fmkService
        )

        // Schema references a person that isn't being imported
        let unrelatedPersonId = UUID()
        let schemaBackup = try makeSchemaBackup(personId: unrelatedPersonId)
        let payload = makeTestPayload(schemas: [schemaBackup])

        await #expect(throws: BackupError.self) {
            try await service.importData(payload, primaryKey: testPrimaryKey)
        }
    }

    @Test("Throws error when record content encryption fails")
    func throwsOnRecordEncryptionFailure() async throws {
        let personRepository = MockPersonRepository()
        let recordRepository = MockMedicalRecordRepository()
        let recordContentService = MockRecordContentService()
        let fmkService = MockFamilyMemberKeyService()
        recordContentService.shouldFailEncrypt = true

        let service = makeService(
            personRepository: personRepository,
            recordRepository: recordRepository,
            recordContentService: recordContentService,
            fmkService: fmkService
        )

        let personBackup = makePersonBackup()
        let recordBackup = makeRecordBackup(personId: personBackup.id)
        let payload = makeTestPayload(persons: [personBackup], records: [recordBackup])

        await #expect(throws: BackupError.self) {
            try await service.importData(payload, primaryKey: testPrimaryKey)
        }
    }
}
