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

    // MARK: - createAttachmentPickerIfNeeded

    @Test
    func createAttachmentPickerIfNeeded_createsPickerForNonDocumentReferenceType() throws {
        let person = try makeTestPerson()
        let deps = FormViewModelDeps(personId: person.id)
        let vm = FormTestSupport.makeViewModel(person: person, recordType: .immunization, deps: deps)

        vm.createAttachmentPickerIfNeeded()

        #expect(vm.attachmentPickerViewModel != nil)
    }

    @Test
    func createAttachmentPickerIfNeeded_doesNotCreatePickerForDocumentReferenceType() throws {
        let person = try makeTestPerson()
        let deps = FormViewModelDeps(personId: person.id)
        let vm = FormTestSupport.makeViewModel(person: person, recordType: .documentReference, deps: deps)

        vm.createAttachmentPickerIfNeeded()

        #expect(vm.attachmentPickerViewModel == nil)
    }

    @Test
    func createAttachmentPickerIfNeeded_doesNotRecreateIfAlreadyExists() throws {
        let person = try makeTestPerson()
        let deps = FormViewModelDeps(personId: person.id)
        let vm = FormTestSupport.makeViewModel(person: person, recordType: .immunization, deps: deps)

        vm.createAttachmentPickerIfNeeded()
        let first = vm.attachmentPickerViewModel
        vm.createAttachmentPickerIfNeeded()
        let second = vm.attachmentPickerViewModel

        #expect(first === second)
    }

    // MARK: - Save with attachments

    @Test
    func save_withPendingAttachments_persistsDocumentReferenceRecords() async throws {
        let person = try makeTestPerson()
        let deps = FormViewModelDeps(personId: person.id)
        let blobService = MockAttachmentBlobService()
        let vm = FormTestSupport.makeViewModel(
            person: person,
            recordType: .immunization,
            deps: deps,
            blobService: blobService
        )
        vm.setValue("Moderna", for: "vaccineCode")
        vm.setValue(Date(), for: "occurrenceDate")

        // Create attachment picker and add a draft
        vm.createAttachmentPickerIfNeeded()
        let pickerVM = try #require(vm.attachmentPickerViewModel)
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
        let blobService = MockAttachmentBlobService()
        let vm = FormTestSupport.makeViewModel(
            person: person,
            recordType: .immunization,
            deps: deps,
            blobService: blobService
        )
        vm.setValue("Pfizer", for: "vaccineCode")
        vm.setValue(Date(), for: "occurrenceDate")

        vm.createAttachmentPickerIfNeeded()
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
        let blobService = MockAttachmentBlobService()
        let vm = FormTestSupport.makeViewModel(
            person: person,
            recordType: .immunization,
            deps: deps,
            blobService: blobService
        )
        vm.setValue("Moderna", for: "vaccineCode")
        vm.setValue(Date(), for: "occurrenceDate")

        vm.createAttachmentPickerIfNeeded()
        let pickerVM = try #require(vm.attachmentPickerViewModel)
        await pickerVM.addFromDocumentPicker([makeTempPDFURL()])

        let ok = await vm.save()

        #expect(ok == false)
        // save was attempted once (the parent) and failed
        #expect(deps.repo.saveCallCount == 1)
    }

    @Test
    func save_attachmentSaveError_doesNotFailParent() async throws {
        let person = try makeTestPerson()
        let deps = FormViewModelDeps(personId: person.id)
        let blobService = MockAttachmentBlobService()
        let vm = FormTestSupport.makeViewModel(
            person: person,
            recordType: .immunization,
            deps: deps,
            blobService: blobService
        )
        vm.setValue("Moderna", for: "vaccineCode")
        vm.setValue(Date(), for: "occurrenceDate")

        vm.createAttachmentPickerIfNeeded()
        let pickerVM = try #require(vm.attachmentPickerViewModel)
        await pickerVM.addFromDocumentPicker([makeTempPDFURL()])

        // Make repo fail on the second save call (attachment), succeed on first (parent)
        deps.repo.failOnSaveCallNumber = 2

        let ok = await vm.save()

        // Parent save succeeded, so overall returns true
        #expect(ok == true)
        // Error message set for the attachment failure
        #expect(vm.errorMessage != nil)
    }

    // MARK: - Helpers

    private func makeTempPDFURL() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("test_\(UUID().uuidString).pdf")
        // PDF magic bytes
        let pdfData = Data("%PDF-1.4 test content".utf8)
        try? pdfData.write(to: fileURL)
        return fileURL
    }
}
