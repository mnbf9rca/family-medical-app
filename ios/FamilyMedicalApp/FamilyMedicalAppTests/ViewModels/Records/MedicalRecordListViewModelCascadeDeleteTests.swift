import CryptoKit
import Foundation
import Testing
@testable import FamilyMedicalApp

@MainActor
struct MedicalRecordListViewModelCascadeDeleteTests {
    // MARK: - Dependency Bag

    private struct Deps {
        let repo = MockMedicalRecordRepository()
        let content = MockRecordContentService()
        let keyProvider = MockPrimaryKeyProvider()
        let fmk = MockFamilyMemberKeyService()
        let queryService = MockDocumentReferenceQueryService()
        let blobService = MockDocumentBlobService()
        let fmkKey = SymmetricKey(size: .bits256)

        init(personId: UUID) {
            keyProvider.primaryKey = SymmetricKey(size: .bits256)
            fmk.setFMK(fmkKey, for: personId.uuidString)
        }
    }

    // MARK: - Helpers

    private func makeTestPerson() throws -> Person {
        try PersonTestHelper.makeTestPerson()
    }

    private func makeTestEnvelope() throws -> RecordContentEnvelope {
        try RecordContentEnvelope(
            ImmunizationRecord(vaccineCode: "COVID-19", occurrenceDate: Date())
        )
    }

    private func makeAttachment(
        title: String,
        hmac: Data,
        sourceRecordId: UUID
    ) -> PersistedDocumentReference {
        let docRef = DocumentReferenceRecord(
            title: title,
            mimeType: "application/pdf",
            fileSize: 2_048,
            contentHMAC: hmac,
            sourceRecordId: sourceRecordId
        )
        return PersistedDocumentReference(
            recordId: UUID(),
            content: docRef,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    private func makeViewModel(
        person: Person,
        deps: Deps
    ) -> MedicalRecordListViewModel {
        MedicalRecordListViewModel(
            person: person,
            recordType: .immunization,
            medicalRecordRepository: deps.repo,
            recordContentService: deps.content,
            primaryKeyProvider: deps.keyProvider,
            fmkService: deps.fmk,
            documentReferenceQueryService: deps.queryService,
            blobService: deps.blobService
        )
    }

    // MARK: - prepareDelete

    @Test
    func prepareDelete_returnsEmptyArrayWhenNoAttachments() async throws {
        let person = try makeTestPerson()
        let deps = Deps(personId: person.id)
        deps.queryService.attachmentsResult = []
        let viewModel = makeViewModel(person: person, deps: deps)

        let attachments = await viewModel.prepareDelete(recordId: UUID())

        #expect(attachments.isEmpty)
    }

    @Test
    func prepareDelete_returnsAttachmentsWhenPresent() async throws {
        let person = try makeTestPerson()
        let deps = Deps(personId: person.id)
        let parentId = UUID()
        deps.queryService.attachmentsResult = [
            makeAttachment(title: "photo.jpg", hmac: Data(repeating: 0xBB, count: 32), sourceRecordId: parentId)
        ]
        let viewModel = makeViewModel(person: person, deps: deps)

        let attachments = await viewModel.prepareDelete(recordId: parentId)

        #expect(attachments.count == 1)
    }

    // MARK: - DeletionStrategy.noAttachments

    @Test
    func deleteWithStrategy_noAttachments_justDeletesRecord() async throws {
        let person = try makeTestPerson()
        let deps = Deps(personId: person.id)
        deps.queryService.attachmentsResult = []
        let record = MedicalRecord(personId: person.id, encryptedContent: Data())
        let envelope = try makeTestEnvelope()
        let viewModel = makeViewModel(person: person, deps: deps)
        viewModel.records = [DecryptedRecord(record: record, envelope: envelope)]

        await viewModel.deleteRecord(id: record.id, strategy: .noAttachments)

        #expect(viewModel.records.isEmpty)
        #expect(deps.repo.deleteCallCount == 1)
    }

    @Test
    func deleteWithStrategy_noAttachments_triggersCascadeWhenAttachmentsExist() async throws {
        let person = try makeTestPerson()
        let deps = Deps(personId: person.id)
        let parentRecord = MedicalRecord(personId: person.id, encryptedContent: Data())
        let hmac = Data(repeating: 0xEE, count: 32)
        let attachment = makeAttachment(title: "scan.pdf", hmac: hmac, sourceRecordId: parentRecord.id)
        deps.queryService.attachmentsResult = [attachment]

        let envelope = try makeTestEnvelope()
        let viewModel = makeViewModel(person: person, deps: deps)
        viewModel.records = [DecryptedRecord(record: parentRecord, envelope: envelope)]

        await viewModel.deleteRecord(id: parentRecord.id, strategy: .noAttachments)

        // Should NOT have deleted the record — cascade dialog should be triggered
        #expect(deps.repo.deleteCallCount == 0)
        #expect(viewModel.pendingCascadeRecordId == parentRecord.id)
        #expect(viewModel.pendingCascadeAttachments.count == 1)
        #expect(!viewModel.records.isEmpty)
    }

    // MARK: - DeletionStrategy.cascadeDelete

    @Test
    func deleteWithStrategy_cascadeDelete_deletesRecordAndAttachments() async throws {
        let person = try makeTestPerson()
        let deps = Deps(personId: person.id)
        deps.queryService.isHmacReferencedResult = false

        let parentRecord = MedicalRecord(personId: person.id, encryptedContent: Data())
        let hmac = Data(repeating: 0xCC, count: 32)
        let attachments = [makeAttachment(title: "scan.pdf", hmac: hmac, sourceRecordId: parentRecord.id)]

        let envelope = try makeTestEnvelope()
        let viewModel = makeViewModel(person: person, deps: deps)
        viewModel.records = [DecryptedRecord(record: parentRecord, envelope: envelope)]

        await viewModel.deleteRecord(id: parentRecord.id, strategy: .cascadeDelete, attachments: attachments)

        #expect(viewModel.records.isEmpty)
        #expect(deps.repo.deleteCallCount == 2)
        #expect(deps.blobService.deleteCalls.count == 1)
        #expect(deps.blobService.deleteCalls.first == hmac)
    }

    // MARK: - DeletionStrategy.keepStandalone

    @Test
    func deleteWithStrategy_keepStandalone_updatesSourceRecordIdAndDeletesParent() async throws {
        let person = try makeTestPerson()
        let deps = Deps(personId: person.id)
        let parentRecord = MedicalRecord(personId: person.id, encryptedContent: Data())
        let attachment = makeAttachment(
            title: "report.pdf",
            hmac: Data(repeating: 0xDD, count: 32),
            sourceRecordId: parentRecord.id
        )
        let attachments = [attachment]

        // Seed the repo with the attachment record so detachAttachments can fetch it
        let existingAttachmentRecord = MedicalRecord(
            id: attachment.recordId,
            personId: person.id,
            encryptedContent: Data(),
            version: 3,
            previousVersionId: nil
        )
        deps.repo.addRecord(existingAttachmentRecord)

        let envelope = try makeTestEnvelope()
        let viewModel = makeViewModel(person: person, deps: deps)
        viewModel.records = [DecryptedRecord(record: parentRecord, envelope: envelope)]

        await viewModel.deleteRecord(id: parentRecord.id, strategy: .keepStandalone, attachments: attachments)

        #expect(viewModel.records.isEmpty)
        #expect(deps.repo.saveCallCount == 1)
        #expect(deps.repo.deleteCallCount == 1)

        let savedRecords = deps.repo.getAllRecords()
        #expect(savedRecords.count == 1)
        let savedEnvelope = try deps.content.decrypt(savedRecords[0].encryptedContent, using: deps.fmkKey)
        let savedDoc = try savedEnvelope.decode(DocumentReferenceRecord.self)
        #expect(savedDoc.sourceRecordId == nil)
        #expect(savedDoc.title == "report.pdf")
    }

    @Test
    func detachAttachments_preservesVersionChain() async throws {
        let person = try makeTestPerson()
        let deps = Deps(personId: person.id)
        let parentRecord = MedicalRecord(personId: person.id, encryptedContent: Data())
        let attachment = makeAttachment(
            title: "versioned.pdf",
            hmac: Data(repeating: 0xAA, count: 32),
            sourceRecordId: parentRecord.id
        )

        // Seed existing record with version 5 and a known previousVersionId
        let priorVersionId = UUID()
        let existingAttachmentRecord = MedicalRecord(
            id: attachment.recordId,
            personId: person.id,
            encryptedContent: Data(),
            version: 5,
            previousVersionId: priorVersionId
        )
        deps.repo.addRecord(existingAttachmentRecord)

        let envelope = try makeTestEnvelope()
        let viewModel = makeViewModel(person: person, deps: deps)
        viewModel.records = [DecryptedRecord(record: parentRecord, envelope: envelope)]

        await viewModel.deleteRecord(
            id: parentRecord.id,
            strategy: .keepStandalone,
            attachments: [attachment]
        )

        let savedRecords = deps.repo.getAllRecords()
        #expect(savedRecords.count == 1)
        let saved = savedRecords[0]
        #expect(saved.version == 6)
        #expect(saved.previousVersionId == priorVersionId)
    }

    @Test
    func detachAttachments_skipsWhenRecordNotFound() async throws {
        let person = try makeTestPerson()
        let deps = Deps(personId: person.id)
        let parentRecord = MedicalRecord(personId: person.id, encryptedContent: Data())
        let attachment = makeAttachment(
            title: "missing.pdf",
            hmac: Data(repeating: 0xFF, count: 32),
            sourceRecordId: parentRecord.id
        )
        // Do NOT add the attachment record to the repo

        let envelope = try makeTestEnvelope()
        let viewModel = makeViewModel(person: person, deps: deps)
        viewModel.records = [DecryptedRecord(record: parentRecord, envelope: envelope)]

        await viewModel.deleteRecord(
            id: parentRecord.id,
            strategy: .keepStandalone,
            attachments: [attachment]
        )

        // Parent should still be deleted, but no save should have happened
        #expect(deps.repo.saveCallCount == 0)
        #expect(deps.repo.deleteCallCount == 1)
        #expect(viewModel.records.isEmpty)
    }
}
