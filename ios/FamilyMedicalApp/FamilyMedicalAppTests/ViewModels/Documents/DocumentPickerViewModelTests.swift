import CryptoKit
import Foundation
import Testing
import UIKit
@testable import FamilyMedicalApp

@MainActor
struct DocumentPickerViewModelTests {
    // MARK: - Test Fixtures

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

    func makeTestImage(size: CGSize = CGSize(width: 100, height: 100)) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor.blue.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
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

    // MARK: - Add from Camera Tests

    @Test
    func addFromCamera_validImage_addsDraft() async {
        let fixtures = makeFixtures()
        let image = makeTestImage()

        await fixtures.viewModel.addFromCamera(image)

        #expect(fixtures.viewModel.drafts.count == 1)
        #expect(fixtures.viewModel.errorMessage == nil)
        #expect(!fixtures.viewModel.isLoading)
    }

    @Test
    func addFromCamera_callsStoreWithJPEG() async {
        let fixtures = makeFixtures()
        let image = makeTestImage()

        await fixtures.viewModel.addFromCamera(image)

        #expect(fixtures.blobService.storeCalls.count == 1)
        let call = fixtures.blobService.storeCalls[0]
        #expect(call.mimeType == "image/jpeg")
        #expect(call.personId == fixtures.personId)
    }

    @Test
    func addFromCamera_titleLooksLikePhotoTimestamp() async throws {
        let fixtures = makeFixtures()
        let image = makeTestImage()

        await fixtures.viewModel.addFromCamera(image)

        let draft = try #require(fixtures.viewModel.drafts.first)
        #expect(draft.content.title.hasPrefix("Photo_"))
        // UTType.jpeg.preferredFilenameExtension is "jpeg", not "jpg".
        #expect(draft.content.title.hasSuffix(".jpeg"))
    }

    @Test
    func addFromCamera_storeFailure_setsError() async {
        let fixtures = makeFixtures()
        fixtures.blobService.storeError = ModelError.unsupportedMimeType(mimeType: "image/jpeg")
        let image = makeTestImage()

        await fixtures.viewModel.addFromCamera(image)

        #expect(fixtures.viewModel.drafts.isEmpty)
        #expect(fixtures.viewModel.errorMessage != nil)
        #expect(!fixtures.viewModel.isLoading)
    }

    @Test
    func addFromCamera_atLimit_setsError() async {
        var existing: [DocumentReferenceRecord] = []
        for index in 0 ..< DocumentPickerViewModel.maxPerRecord {
            existing.append(makeDocumentReference(title: "f\(index).jpg", hmacByte: UInt8(index)))
        }
        let fixtures = makeFixtures(existing: existing)
        let image = makeTestImage()

        await fixtures.viewModel.addFromCamera(image)

        #expect(fixtures.viewModel.errorMessage != nil)
        #expect(fixtures.blobService.storeCalls.isEmpty)
    }

    @Test
    func addFromCamera_stampsSourceRecordIdOnDraft() async throws {
        let sourceId = UUID()
        let fixtures = makeFixtures(sourceRecordId: sourceId)
        let image = makeTestImage()

        await fixtures.viewModel.addFromCamera(image)

        let draft = try #require(fixtures.viewModel.drafts.first)
        #expect(draft.content.sourceRecordId == sourceId)
    }

    @Test
    func addFromCamera_populatesDocumentMetadata() async throws {
        let fixtures = makeFixtures()
        let image = makeTestImage()

        await fixtures.viewModel.addFromCamera(image)

        let draft = try #require(fixtures.viewModel.drafts.first)
        #expect(draft.content.mimeType == "image/jpeg")
        #expect(draft.content.fileSize > 0)
        #expect(draft.content.contentHMAC.count == 32)
        #expect(draft.content.thumbnailData != nil)
        #expect(draft.content.documentType == nil)
        #expect(draft.content.notes == nil)
        #expect(draft.content.tags.isEmpty == true)
    }

    // MARK: - Remove Draft Tests

    @Test
    func removeDraft_existingId_removesFromList() async throws {
        let fixtures = makeFixtures()
        let image = makeTestImage()
        await fixtures.viewModel.addFromCamera(image)

        let draftId = try #require(fixtures.viewModel.drafts.first?.id)
        fixtures.viewModel.removeDraft(id: draftId)

        #expect(fixtures.viewModel.drafts.isEmpty)
    }

    @Test
    func removeDraft_unknownId_doesNothing() async {
        let fixtures = makeFixtures()
        let image = makeTestImage()
        await fixtures.viewModel.addFromCamera(image)

        fixtures.viewModel.removeDraft(id: UUID())

        #expect(fixtures.viewModel.drafts.count == 1)
    }

    // MARK: - Set Title Tests

    @Test
    func setTitle_updatesDraftContent() async throws {
        let fixtures = makeFixtures()
        let image = makeTestImage()
        await fixtures.viewModel.addFromCamera(image)

        let draftId = try #require(fixtures.viewModel.drafts.first?.id)
        fixtures.viewModel.setTitle("Renamed.jpg", for: draftId)

        #expect(fixtures.viewModel.drafts.first?.content.title == "Renamed.jpg")
    }

    @Test
    func setTitle_unknownId_doesNothing() async {
        let fixtures = makeFixtures()
        let image = makeTestImage()
        await fixtures.viewModel.addFromCamera(image)

        let original = fixtures.viewModel.drafts.first?.content.title
        fixtures.viewModel.setTitle("NewName.jpg", for: UUID())

        #expect(fixtures.viewModel.drafts.first?.content.title == original)
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
