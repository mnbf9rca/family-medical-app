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
        let recordBackup = try makeRecordBackup(personId: personBackup.id)
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

    // MARK: - Record Validation Tests

    @Test("Throws corruptedFile when record has invalid record type")
    func throwsForInvalidRecordType() async throws {
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
        // Create record with invalid record type
        let recordBackup = MedicalRecordBackup(
            id: UUID(),
            personId: personBackup.id,
            recordType: "unknownType",
            schemaVersion: 1,
            contentJSON: Data("{}".utf8),
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
