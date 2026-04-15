import CryptoKit
import Foundation
import Testing
import UniformTypeIdentifiers
@testable import FamilyMedicalApp

@MainActor
struct DocumentPickerViewModelTests {
    // MARK: - Initialization Tests

    @Test
    func init_noExisting_startsEmpty() {
        let fixtures = makeFixtures()

        #expect(fixtures.viewModel.drafts.isEmpty)
        #expect(!fixtures.viewModel.isLoading)
        #expect(fixtures.viewModel.errorMessage == nil)
    }

    @Test
    func init_withExisting_loadsDrafts() {
        let doc1 = makeDocumentReference(title: "doc1.jpg", hmacByte: 0x01)
        let doc2 = makeDocumentReference(title: "doc2.jpg", hmacByte: 0x02)

        let fixtures = makeFixtures(existing: [doc1, doc2])

        #expect(fixtures.viewModel.drafts.count == 2)
        #expect(fixtures.viewModel.drafts[0].content.title == "doc1.jpg")
        #expect(fixtures.viewModel.drafts[1].content.title == "doc2.jpg")
    }

    @Test
    func init_storesContextFields() {
        let sourceId = UUID()
        let fixtures = makeFixtures(sourceRecordId: sourceId)

        #expect(fixtures.viewModel.sourceRecordId == sourceId)
        #expect(fixtures.viewModel.personId == fixtures.personId)
    }

    @Test
    func init_nilSourceRecordId_isAllowed() {
        let fixtures = makeFixtures(sourceRecordId: nil)

        #expect(fixtures.viewModel.sourceRecordId == nil)
    }

    // MARK: - Computed Properties Tests

    @Test
    func canAddMore_belowLimit_returnsTrue() {
        let fixtures = makeFixtures()
        #expect(fixtures.viewModel.canAddMore)
    }

    @Test
    func canAddMore_atLimit_returnsFalse() {
        var existing: [DocumentReferenceRecord] = []
        for index in 0 ..< DocumentPickerViewModel.maxPerRecord {
            existing.append(makeDocumentReference(title: "f\(index).jpg", hmacByte: UInt8(index)))
        }
        let fixtures = makeFixtures(existing: existing)

        #expect(!fixtures.viewModel.canAddMore)
    }

    @Test
    func remainingSlots_empty_returnsMax() {
        let fixtures = makeFixtures()
        #expect(fixtures.viewModel.remainingSlots == DocumentPickerViewModel.maxPerRecord)
    }

    @Test
    func remainingSlots_partial_returnsDiff() {
        let existing = [
            makeDocumentReference(title: "a.jpg", hmacByte: 0x01),
            makeDocumentReference(title: "b.jpg", hmacByte: 0x02)
        ]
        let fixtures = makeFixtures(existing: existing)

        #expect(fixtures.viewModel.remainingSlots == DocumentPickerViewModel.maxPerRecord - 2)
    }

    @Test
    func countSummary_formatsCorrectly() {
        let existing = [
            makeDocumentReference(title: "a.jpg", hmacByte: 0x01),
            makeDocumentReference(title: "b.jpg", hmacByte: 0x02)
        ]
        let fixtures = makeFixtures(existing: existing)

        #expect(fixtures.viewModel.countSummary == "2 of \(DocumentPickerViewModel.maxPerRecord) attachments")
    }

    @Test
    func allDocumentReferences_returnsDraftContent() {
        let doc1 = makeDocumentReference(title: "x.jpg", hmacByte: 0x11)
        let doc2 = makeDocumentReference(title: "y.jpg", hmacByte: 0x22)
        let fixtures = makeFixtures(existing: [doc1, doc2])

        let refs = fixtures.viewModel.allDocumentReferences
        #expect(refs.count == 2)
        #expect(refs[0].title == "x.jpg")
        #expect(refs[1].title == "y.jpg")
    }

    // MARK: - Add from Camera Data Tests

    @Test
    func addFromCameraData_heicBytes_addsDraft() async {
        let fixtures = makeFixtures()
        fixtures.blobService.detectedMimeStub = "image/heic"

        await fixtures.viewModel.addFromCameraData(SyntheticPhotoFixtures.heicData, type: .heic)

        #expect(fixtures.viewModel.drafts.count == 1)
        #expect(fixtures.viewModel.errorMessage == nil)
        #expect(!fixtures.viewModel.isLoading)
    }

    @Test
    func addFromCameraData_heicBytes_preservesHeicMimeType() async throws {
        let fixtures = makeFixtures()
        fixtures.blobService.detectedMimeStub = "image/heic"

        await fixtures.viewModel.addFromCameraData(SyntheticPhotoFixtures.heicData, type: .heic)

        let draft = try #require(fixtures.viewModel.drafts.first)
        #expect(draft.content.mimeType == "image/heic")
        #expect(draft.content.title.hasSuffix(".heic"))
    }

    @Test
    func addFromCameraData_jpegBytes_preservesJpegMimeType() async throws {
        let fixtures = makeFixtures()
        fixtures.blobService.detectedMimeStub = "image/jpeg"

        await fixtures.viewModel.addFromCameraData(SyntheticPhotoFixtures.jpegData, type: .jpeg)

        let draft = try #require(fixtures.viewModel.drafts.first)
        #expect(draft.content.mimeType == "image/jpeg")
        #expect(draft.content.title.hasSuffix(".jpeg"))
    }

    @Test
    func addFromCameraData_bytes_preservedByteForByteViaHMAC() async throws {
        let fixtures = makeFixtures()
        fixtures.blobService.detectedMimeStub = "image/heic"

        let fixture = SyntheticPhotoFixtures.heicData
        await fixtures.viewModel.addFromCameraData(fixture, type: .heic)

        // MockDocumentBlobService computes contentHMAC as SHA256(plaintext).
        // If the view model had decoded/re-encoded the Data anywhere along the
        // way, the stored HMAC would not match SHA256 of the input bytes.
        // This test is the byte-integrity invariant expressed in code.
        let expectedHMAC = Data(SHA256.hash(data: fixture))
        let draft = try #require(fixtures.viewModel.drafts.first)
        #expect(draft.content.contentHMAC == expectedHMAC)
        #expect(draft.content.fileSize == fixture.count)
    }

    @Test
    func addFromCameraData_atLimit_setsErrorAndDoesNotCallStore() async {
        var existing: [DocumentReferenceRecord] = []
        for index in 0 ..< DocumentPickerViewModel.maxPerRecord {
            existing.append(makeDocumentReference(title: "f\(index).jpg", hmacByte: UInt8(index)))
        }
        let fixtures = makeFixtures(existing: existing)

        await fixtures.viewModel.addFromCameraData(SyntheticPhotoFixtures.jpegData, type: .jpeg)

        #expect(fixtures.viewModel.errorMessage != nil)
        #expect(fixtures.blobService.storeCalls.isEmpty)
    }

    @Test
    func addFromCameraData_stampsSourceRecordIdOnDraft() async throws {
        let sourceId = UUID()
        let fixtures = makeFixtures(sourceRecordId: sourceId)
        fixtures.blobService.detectedMimeStub = "image/jpeg"

        await fixtures.viewModel.addFromCameraData(SyntheticPhotoFixtures.jpegData, type: .jpeg)

        let draft = try #require(fixtures.viewModel.drafts.first)
        #expect(draft.content.sourceRecordId == sourceId)
    }

    @Test
    func addFromCameraData_storeFailure_setsError() async {
        let fixtures = makeFixtures()
        fixtures.blobService.storeError = ModelError.unsupportedContent

        await fixtures.viewModel.addFromCameraData(SyntheticPhotoFixtures.jpegData, type: .jpeg)

        #expect(fixtures.viewModel.drafts.isEmpty)
        #expect(fixtures.viewModel.errorMessage != nil)
    }

    @Test
    func addFromCameraData_leavesHMACInFlightAfterStore() async throws {
        let fixtures = makeFixtures()
        fixtures.blobService.detectedMimeStub = "image/heic"

        await fixtures.viewModel.addFromCameraData(SyntheticPhotoFixtures.heicData, type: .heic)

        let draftHMAC = try #require(fixtures.viewModel.drafts.first?.content.contentHMAC)
        #expect(fixtures.blobService.inFlightHMACs.contains(draftHMAC))
    }

    // MARK: - Remove Draft Tests

    @Test
    func removeDraft_existingId_removesFromList() async throws {
        let fixtures = makeFixtures()
        fixtures.blobService.detectedMimeStub = "image/jpeg"
        await fixtures.viewModel.addFromCameraData(SyntheticPhotoFixtures.jpegData, type: .jpeg)

        let draftId = try #require(fixtures.viewModel.drafts.first?.id)
        fixtures.viewModel.removeDraft(id: draftId)

        #expect(fixtures.viewModel.drafts.isEmpty)
    }

    @Test
    func removeDraft_unknownId_doesNothing() async {
        let fixtures = makeFixtures()
        fixtures.blobService.detectedMimeStub = "image/jpeg"
        await fixtures.viewModel.addFromCameraData(SyntheticPhotoFixtures.jpegData, type: .jpeg)

        fixtures.viewModel.removeDraft(id: UUID())

        #expect(fixtures.viewModel.drafts.count == 1)
    }

    @Test
    func removeDraft_clearsInFlightForRemovedHMAC() async throws {
        let fixtures = makeFixtures()
        fixtures.blobService.detectedMimeStub = "image/jpeg"
        await fixtures.viewModel.addFromCameraData(SyntheticPhotoFixtures.jpegData, type: .jpeg)

        let draftId = try #require(fixtures.viewModel.drafts.first?.id)
        let draftHMAC = try #require(fixtures.viewModel.drafts.first?.content.contentHMAC)
        // Precondition: the blob is in-flight — established by the atomic `store`
        // contract rather than by an explicit markInFlight call.
        #expect(fixtures.blobService.inFlightHMACs.contains(draftHMAC))

        fixtures.viewModel.removeDraft(id: draftId)

        // removeDraft fires its clearInFlight in a detached Task. Deterministic wait:
        // yield up to 20 event-loop turns for the clear to land. This fails fast if
        // the clear never happens and avoids the timing flakiness of Task.sleep.
        for _ in 0 ..< 20 {
            await Task.yield()
            if !fixtures.blobService.inFlightHMACs.contains(draftHMAC) { break }
        }

        #expect(fixtures.viewModel.drafts.isEmpty)
        #expect(fixtures.blobService.clearInFlightCalls.contains(draftHMAC))
        #expect(!fixtures.blobService.inFlightHMACs.contains(draftHMAC))
    }

    @Test
    func removeDraft_unknownId_doesNotClearInFlight() async {
        let fixtures = makeFixtures()
        fixtures.blobService.detectedMimeStub = "image/jpeg"
        await fixtures.viewModel.addFromCameraData(SyntheticPhotoFixtures.jpegData, type: .jpeg)

        fixtures.viewModel.removeDraft(id: UUID())

        // Yield a bounded number of turns to give any stray background Task a chance
        // to run. Nothing should have been cleared — the blob is still pending save.
        for _ in 0 ..< 20 {
            await Task.yield()
        }

        #expect(fixtures.blobService.clearInFlightCalls.isEmpty)
    }

    // MARK: - Set Title Tests

    @Test
    func setTitle_updatesDraftContent() async throws {
        let fixtures = makeFixtures()
        fixtures.blobService.detectedMimeStub = "image/jpeg"
        await fixtures.viewModel.addFromCameraData(SyntheticPhotoFixtures.jpegData, type: .jpeg)

        let draftId = try #require(fixtures.viewModel.drafts.first?.id)
        fixtures.viewModel.setTitle("Renamed.jpg", for: draftId)

        #expect(fixtures.viewModel.drafts.first?.content.title == "Renamed.jpg")
    }

    @Test
    func setTitle_unknownId_doesNothing() async {
        let fixtures = makeFixtures()
        fixtures.blobService.detectedMimeStub = "image/jpeg"
        await fixtures.viewModel.addFromCameraData(SyntheticPhotoFixtures.jpegData, type: .jpeg)

        let original = fixtures.viewModel.drafts.first?.content.title
        fixtures.viewModel.setTitle("NewName.jpg", for: UUID())

        #expect(fixtures.viewModel.drafts.first?.content.title == original)
    }

    @Test
    func setTitle_overMaxLength_truncatesToMax() async throws {
        let fixtures = makeFixtures()
        fixtures.blobService.detectedMimeStub = "image/jpeg"
        await fixtures.viewModel.addFromCameraData(SyntheticPhotoFixtures.jpegData, type: .jpeg)

        let draftId = try #require(fixtures.viewModel.drafts.first?.id)
        let overLong = String(repeating: "z", count: DocumentReferenceRecord.titleMaxLength + 100)
        fixtures.viewModel.setTitle(overLong, for: draftId)

        // Regression guard: DocumentReferenceRecord.title must enforce length structurally.
        #expect(fixtures.viewModel.drafts.first?.content.title.count == DocumentReferenceRecord.titleMaxLength)
    }

    @Test
    func setTitle_exactlyMaxLength_keepsFullTitle() async throws {
        let fixtures = makeFixtures()
        fixtures.blobService.detectedMimeStub = "image/jpeg"
        await fixtures.viewModel.addFromCameraData(SyntheticPhotoFixtures.jpegData, type: .jpeg)

        let draftId = try #require(fixtures.viewModel.drafts.first?.id)
        let maxTitle = String(repeating: "y", count: DocumentReferenceRecord.titleMaxLength)
        fixtures.viewModel.setTitle(maxTitle, for: draftId)

        #expect(fixtures.viewModel.drafts.first?.content.title == maxTitle)
    }

    // MARK: - Sheet State Tests

    @Test
    func showingCamera_initiallyFalse() {
        let fixtures = makeFixtures()
        #expect(!fixtures.viewModel.showingCamera)
    }

    @Test
    func showingPhotoLibrary_initiallyFalse() {
        let fixtures = makeFixtures()
        #expect(!fixtures.viewModel.showingPhotoLibrary)
    }

    @Test
    func showingDocumentPicker_initiallyFalse() {
        let fixtures = makeFixtures()
        #expect(!fixtures.viewModel.showingDocumentPicker)
    }
}

// MARK: - Fixtures and Helpers
//
// Lifted into an extension so they don't contribute to the primary type's
// body-length budget (SwiftLint `type_body_length`).

@MainActor
extension DocumentPickerViewModelTests {
    struct TestFixtures {
        let viewModel: DocumentPickerViewModel
        let blobService: MockDocumentBlobService
        let personId: UUID
        let sourceRecordId: UUID?
        let primaryKey: SymmetricKey
    }

    func makeFixtures(
        sourceRecordId: UUID? = UUID(),
        existing: [DocumentReferenceRecord] = []
    ) -> TestFixtures {
        let blobService = MockDocumentBlobService()
        let primaryKey = SymmetricKey(size: .bits256)
        let personId = UUID()

        let viewModel = DocumentPickerViewModel(
            personId: personId,
            sourceRecordId: sourceRecordId,
            primaryKey: primaryKey,
            existing: existing,
            blobService: blobService
        )

        return TestFixtures(
            viewModel: viewModel,
            blobService: blobService,
            personId: personId,
            sourceRecordId: sourceRecordId,
            primaryKey: primaryKey
        )
    }

    func makeDocumentReference(
        title: String = "existing.jpg",
        mimeType: String = "image/jpeg",
        hmacByte: UInt8 = 0x01
    ) -> DocumentReferenceRecord {
        DocumentReferenceRecord(
            title: title,
            mimeType: mimeType,
            fileSize: 1_024,
            contentHMAC: Data(repeating: hmacByte, count: 32)
        )
    }
}
