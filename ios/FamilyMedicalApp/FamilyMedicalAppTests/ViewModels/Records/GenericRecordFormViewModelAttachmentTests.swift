import CryptoKit
import Foundation
import Testing
@testable import FamilyMedicalApp

@MainActor
struct GenericRecordFormViewModelAttachmentTests {
    // MARK: - Test Helpers

    func makeTestPerson() throws -> Person {
        try PersonTestHelper.makeTestPerson()
    }

    // MARK: - createDocumentPickerIfNeeded

    @Test
    func createDocumentPickerIfNeeded_createsPickerForNonDocumentReferenceType() async throws {
        let person = try makeTestPerson()
        let deps = FormViewModelDeps(personId: person.id)
        let vm = FormTestSupport.makeViewModel(person: person, recordType: .immunization, deps: deps)

        await vm.createDocumentPickerIfNeeded()

        #expect(vm.documentPickerViewModel != nil)
    }

    @Test
    func createDocumentPickerIfNeeded_doesNotCreatePickerForDocumentReferenceType() async throws {
        let person = try makeTestPerson()
        let deps = FormViewModelDeps(personId: person.id)
        let vm = FormTestSupport.makeViewModel(person: person, recordType: .documentReference, deps: deps)

        await vm.createDocumentPickerIfNeeded()

        #expect(vm.documentPickerViewModel == nil)
    }

    @Test
    func createDocumentPickerIfNeeded_doesNotRecreateIfAlreadyExists() async throws {
        let person = try makeTestPerson()
        let deps = FormViewModelDeps(personId: person.id)
        let vm = FormTestSupport.makeViewModel(person: person, recordType: .immunization, deps: deps)

        await vm.createDocumentPickerIfNeeded()
        let first = vm.documentPickerViewModel
        await vm.createDocumentPickerIfNeeded()
        let second = vm.documentPickerViewModel

        #expect(first === second)
    }

    // MARK: - Save with attachments

    @Test
    func save_withPendingAttachments_persistsDocumentReferenceRecords() async throws {
        let person = try makeTestPerson()
        let deps = FormViewModelDeps(personId: person.id)
        let blobService = MockDocumentBlobService()
        let vm = FormTestSupport.makeViewModel(
            person: person,
            recordType: .immunization,
            deps: deps,
            blobService: blobService
        )
        vm.setValue("Moderna", for: "vaccineCode")
        vm.setValue(Date(), for: "occurrenceDate")

        // Create attachment picker and add a draft
        await vm.createDocumentPickerIfNeeded()
        let pickerVM = try #require(vm.documentPickerViewModel)
        await pickerVM.addFromDocumentPicker([makeTempPDFURL()])

        #expect(pickerVM.drafts.count == 1)

        let ok = await vm.save()

        #expect(ok == true)
        // 1 parent record + 1 attachment record
        #expect(deps.repo.saveCallCount == 2)

        let allRecords = deps.repo.getAllRecords()
        #expect(allRecords.count == 2)

        // Find the DocumentReference record
        let docRefRecord = try allRecords.compactMap { record -> MedicalRecord? in
            let envelope = try deps.content.decrypt(record.encryptedContent, using: deps.fmkKey)
            return envelope.recordType == .documentReference ? record : nil
        }.first

        let docRef = try #require(docRefRecord)
        let envelope = try deps.content.decrypt(docRef.encryptedContent, using: deps.fmkKey)
        let decoded = try envelope.decode(DocumentReferenceRecord.self)

        // The sourceRecordId should match the saved parent record's ID
        let parentRecord = allRecords.first { $0.id != docRef.id }
        #expect(decoded.sourceRecordId == parentRecord?.id)
    }

    @Test
    func save_withNoAttachments_worksAsBeforeWithSingleSave() async throws {
        let person = try makeTestPerson()
        let deps = FormViewModelDeps(personId: person.id)
        let vm = FormTestSupport.makeViewModel(person: person, recordType: .immunization, deps: deps)
        vm.setValue("Pfizer", for: "vaccineCode")
        vm.setValue(Date(), for: "occurrenceDate")

        // No attachment picker created at all
        let ok = await vm.save()

        #expect(ok == true)
        #expect(deps.repo.saveCallCount == 1)
    }

    @Test
    func save_withEmptyAttachmentPicker_onlySavesParentRecord() async throws {
        let person = try makeTestPerson()
        let deps = FormViewModelDeps(personId: person.id)
        let blobService = MockDocumentBlobService()
        let vm = FormTestSupport.makeViewModel(
            person: person,
            recordType: .immunization,
            deps: deps,
            blobService: blobService
        )
        vm.setValue("Pfizer", for: "vaccineCode")
        vm.setValue(Date(), for: "occurrenceDate")

        await vm.createDocumentPickerIfNeeded()
        // No drafts added

        let ok = await vm.save()

        #expect(ok == true)
        #expect(deps.repo.saveCallCount == 1)
    }

    @Test
    func save_parentSaveFails_noAttachmentsSaved() async throws {
        let person = try makeTestPerson()
        let deps = FormViewModelDeps(personId: person.id)
        deps.repo.shouldFailSave = true
        let blobService = MockDocumentBlobService()
        let vm = FormTestSupport.makeViewModel(
            person: person,
            recordType: .immunization,
            deps: deps,
            blobService: blobService
        )
        vm.setValue("Moderna", for: "vaccineCode")
        vm.setValue(Date(), for: "occurrenceDate")

        await vm.createDocumentPickerIfNeeded()
        let pickerVM = try #require(vm.documentPickerViewModel)
        await pickerVM.addFromDocumentPicker([makeTempPDFURL()])

        let ok = await vm.save()

        #expect(ok == false)
        // save was attempted once (the parent) and failed
        #expect(deps.repo.saveCallCount == 1)
    }

    @Test
    func save_withPendingAttachments_clearsInFlightForEachSavedAttachment() async throws {
        let person = try makeTestPerson()
        let deps = FormViewModelDeps(personId: person.id)
        let blobService = MockDocumentBlobService()
        let vm = FormTestSupport.makeViewModel(
            person: person,
            recordType: .immunization,
            deps: deps,
            blobService: blobService
        )
        vm.setValue("Moderna", for: "vaccineCode")
        vm.setValue(Date(), for: "occurrenceDate")

        await vm.createDocumentPickerIfNeeded()
        let pickerVM = try #require(vm.documentPickerViewModel)
        // Two distinct PDFs so their SHA256-based synthetic HMACs don't collide.
        // The mock's synthetic HMAC is computed from the raw bytes, so different
        // payloads guarantee two separate in-flight entries and two clearInFlight
        // calls on save — the "for each" part of the test's promise.
        await pickerVM.addFromDocumentPicker([
            makeTempPDFURL(payload: "content-one"),
            makeTempPDFURL(payload: "content-two")
        ])

        #expect(pickerVM.drafts.count == 2)
        // Atomic `store` contract: both drafts are in-flight immediately after append,
        // without any explicit markInFlight call from the picker VM.
        let firstHMAC = try #require(pickerVM.drafts.first?.content.contentHMAC)
        let secondHMAC = try #require(pickerVM.drafts.last?.content.contentHMAC)
        #expect(firstHMAC != secondHMAC)
        #expect(blobService.inFlightHMACs.contains(firstHMAC))
        #expect(blobService.inFlightHMACs.contains(secondHMAC))

        let ok = await vm.save()

        #expect(ok == true)
        // After the attachment record save, the form VM should have proxied
        // clearInFlightForDraft through the picker to the blob service for EACH
        // saved attachment — not just the first.
        #expect(blobService.clearInFlightCalls.contains(firstHMAC))
        #expect(blobService.clearInFlightCalls.contains(secondHMAC))
        #expect(!blobService.inFlightHMACs.contains(firstHMAC))
        #expect(!blobService.inFlightHMACs.contains(secondHMAC))
    }

    @Test
    func save_attachmentSaveFails_leavesHMACInFlight() async throws {
        let person = try makeTestPerson()
        let deps = FormViewModelDeps(personId: person.id)
        let blobService = MockDocumentBlobService()
        let vm = FormTestSupport.makeViewModel(
            person: person,
            recordType: .immunization,
            deps: deps,
            blobService: blobService
        )
        vm.setValue("Moderna", for: "vaccineCode")
        vm.setValue(Date(), for: "occurrenceDate")

        await vm.createDocumentPickerIfNeeded()
        let pickerVM = try #require(vm.documentPickerViewModel)
        await pickerVM.addFromDocumentPicker([makeTempPDFURL()])

        let draftHMAC = try #require(pickerVM.drafts.first?.content.contentHMAC)
        #expect(blobService.inFlightHMACs.contains(draftHMAC))

        // Fail on attachment save (second call), succeed on parent (first).
        deps.repo.failOnSaveCallNumber = 2

        let ok = await vm.save()

        // Parent saved, overall returns true but attachment save failed.
        #expect(ok == true)
        #expect(vm.errorMessage != nil)
        // Crucially: in-flight state is NOT cleared for the failed attachment so a
        // subsequent retry still has the blob on disk.
        #expect(!blobService.clearInFlightCalls.contains(draftHMAC))
        #expect(blobService.inFlightHMACs.contains(draftHMAC))
    }

    @Test
    func save_attachmentSaveError_doesNotFailParent() async throws {
        let person = try makeTestPerson()
        let deps = FormViewModelDeps(personId: person.id)
        let blobService = MockDocumentBlobService()
        let vm = FormTestSupport.makeViewModel(
            person: person,
            recordType: .immunization,
            deps: deps,
            blobService: blobService
        )
        vm.setValue("Moderna", for: "vaccineCode")
        vm.setValue(Date(), for: "occurrenceDate")

        await vm.createDocumentPickerIfNeeded()
        let pickerVM = try #require(vm.documentPickerViewModel)
        await pickerVM.addFromDocumentPicker([makeTempPDFURL()])

        // Make repo fail on the second save call (attachment), succeed on first (parent)
        deps.repo.failOnSaveCallNumber = 2

        let ok = await vm.save()

        // Parent save succeeded, so overall returns true
        #expect(ok == true)
        // Error message set for the attachment failure
        #expect(vm.errorMessage != nil)
    }

    // MARK: - Edit mode existing attachments

    @Test
    func createDocumentPickerIfNeeded_editMode_loadsExistingAttachments() async throws {
        let person = try makeTestPerson()
        let deps = FormViewModelDeps(personId: person.id)

        let existingRecord = try makeExistingImmunizationRecord(personId: person.id)

        // Configure the mock query service to return 2 existing attachments
        let docRef1 = DocumentReferenceRecord(
            title: "Lab Report",
            mimeType: "application/pdf",
            fileSize: 1_024,
            contentHMAC: Data([0x01, 0x02]),
            sourceRecordId: existingRecord.record.id
        )
        let docRef2 = DocumentReferenceRecord(
            title: "X-Ray",
            mimeType: "image/jpeg",
            fileSize: 2_048,
            contentHMAC: Data([0x03, 0x04]),
            sourceRecordId: existingRecord.record.id
        )
        deps.docRefQueryService.attachmentsResult = [
            PersistedDocumentReference(recordId: UUID(), content: docRef1, createdAt: Date(), updatedAt: Date()),
            PersistedDocumentReference(recordId: UUID(), content: docRef2, createdAt: Date(), updatedAt: Date())
        ]

        let vm = FormTestSupport.makeViewModel(
            person: person,
            recordType: .immunization,
            existingRecord: existingRecord,
            deps: deps
        )

        await vm.createDocumentPickerIfNeeded()

        let pickerVM = try #require(vm.documentPickerViewModel)
        #expect(pickerVM.drafts.count == 2)
        #expect(deps.docRefQueryService.attachmentsForCalls.count == 1)
        #expect(deps.docRefQueryService.attachmentsForCalls.first == existingRecord.record.id)
    }

    @Test
    func createDocumentPickerIfNeeded_editMode_existingAttachmentsCountTowardMaxPerRecord() async throws {
        let person = try makeTestPerson()
        let deps = FormViewModelDeps(personId: person.id)

        let existingRecord = try makeExistingImmunizationRecord(personId: person.id)

        // Fill to maxPerRecord (5) with existing attachments
        var attachments: [PersistedDocumentReference] = []
        for index in 0 ..< DocumentPickerViewModel.maxPerRecord {
            let docRef = DocumentReferenceRecord(
                title: "Doc \(index)",
                mimeType: "application/pdf",
                fileSize: 1_024,
                contentHMAC: Data([UInt8(index)]),
                sourceRecordId: existingRecord.record.id
            )
            attachments.append(
                PersistedDocumentReference(recordId: UUID(), content: docRef, createdAt: Date(), updatedAt: Date())
            )
        }
        deps.docRefQueryService.attachmentsResult = attachments

        let vm = FormTestSupport.makeViewModel(
            person: person,
            recordType: .immunization,
            existingRecord: existingRecord,
            deps: deps
        )

        await vm.createDocumentPickerIfNeeded()

        let pickerVM = try #require(vm.documentPickerViewModel)
        #expect(pickerVM.drafts.count == DocumentPickerViewModel.maxPerRecord)
        #expect(pickerVM.canAddMore == false)
        #expect(pickerVM.remainingSlots == 0)
    }

    @Test
    func createDocumentPickerIfNeeded_createMode_startsWithEmptyExisting() async throws {
        let person = try makeTestPerson()
        let deps = FormViewModelDeps(personId: person.id)
        // No existingRecord — create mode
        let vm = FormTestSupport.makeViewModel(person: person, recordType: .immunization, deps: deps)

        await vm.createDocumentPickerIfNeeded()

        let pickerVM = try #require(vm.documentPickerViewModel)
        #expect(pickerVM.drafts.isEmpty)
        // Should NOT have called the query service
        #expect(deps.docRefQueryService.attachmentsForCalls.isEmpty)
    }

    // MARK: - Helpers

    private func makeExistingImmunizationRecord(personId: UUID) throws -> DecryptedRecord {
        let envelope = try RecordContentEnvelope(
            ImmunizationRecord(vaccineCode: "Moderna", occurrenceDate: Date())
        )
        let record = MedicalRecord(personId: personId, encryptedContent: Data())
        return DecryptedRecord(record: record, envelope: envelope)
    }

    private func makeTempPDFURL(payload: String = "test content") -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("test_\(UUID().uuidString).pdf")
        // PDF magic bytes plus caller-chosen payload so distinct calls produce
        // distinct byte sequences (and therefore distinct SHA256-based HMACs in
        // the mock blob service — important for multi-attachment tests).
        let pdfData = Data("%PDF-1.4 \(payload)".utf8)
        try? pdfData.write(to: fileURL)
        return fileURL
    }
}
