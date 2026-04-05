import CryptoKit
import Foundation
import Testing
@testable import FamilyMedicalApp

/// Tests for AttachmentViewerViewModel initialization, computed properties, and content loading.
@MainActor
struct AttachmentViewerViewModelTests {
    // MARK: - Test Fixtures

    struct TestFixtures {
        let viewModel: AttachmentViewerViewModel
        let blobService: MockAttachmentBlobService
        let document: DocumentReferenceRecord
        let personId: UUID
        let primaryKey: SymmetricKey
    }

    func makeFixtures(
        title: String = "test.jpg",
        mimeType: String = "image/jpeg",
        fileSize: Int = 1_024,
        retrieveResult: Data = Data("test content".utf8)
    ) -> TestFixtures {
        let blobService = MockAttachmentBlobService()
        blobService.retrieveResult = retrieveResult
        let primaryKey = SymmetricKey(size: .bits256)
        let personId = UUID()

        let document = DocumentReferenceRecord(
            title: title,
            mimeType: mimeType,
            fileSize: fileSize,
            contentHMAC: Data(repeating: 0xAB, count: 32)
        )

        let viewModel = AttachmentViewerViewModel(
            document: document,
            personId: personId,
            primaryKey: primaryKey,
            blobService: blobService
        )

        return TestFixtures(
            viewModel: viewModel,
            blobService: blobService,
            document: document,
            personId: personId,
            primaryKey: primaryKey
        )
    }

    // MARK: - Initialization Tests

    @Test
    func init_setsDocumentAndPersonId() {
        let fixtures = makeFixtures()

        #expect(fixtures.viewModel.document.title == fixtures.document.title)
        #expect(fixtures.viewModel.document.contentHMAC == fixtures.document.contentHMAC)
        #expect(fixtures.viewModel.personId == fixtures.personId)
    }

    @Test
    func init_startsWithNilDecryptedData() {
        let fixtures = makeFixtures()

        #expect(fixtures.viewModel.decryptedData == nil)
        #expect(!fixtures.viewModel.hasContent)
    }

    @Test
    func init_notLoading() {
        let fixtures = makeFixtures()

        #expect(!fixtures.viewModel.isLoading)
        #expect(fixtures.viewModel.errorMessage == nil)
    }

    @Test
    func init_sheetsNotShowing() {
        let fixtures = makeFixtures()

        #expect(!fixtures.viewModel.showingExportWarning)
        #expect(!fixtures.viewModel.showingShareSheet)
    }

    // MARK: - Computed Properties Tests

    @Test
    func isImage_jpegDocument_returnsTrue() {
        let fixtures = makeFixtures(mimeType: "image/jpeg")

        #expect(fixtures.viewModel.isImage)
        #expect(!fixtures.viewModel.isPDF)
    }

    @Test
    func isImage_pngDocument_returnsTrue() {
        let fixtures = makeFixtures(title: "test.png", mimeType: "image/png")

        #expect(fixtures.viewModel.isImage)
        #expect(!fixtures.viewModel.isPDF)
    }

    @Test
    func isPDF_pdfDocument_returnsTrue() {
        let fixtures = makeFixtures(title: "test.pdf", mimeType: "application/pdf")

        #expect(fixtures.viewModel.isPDF)
        #expect(!fixtures.viewModel.isImage)
    }

    @Test
    func displayFileName_returnsDocumentTitle() {
        let fixtures = makeFixtures(title: "my_document.pdf")

        #expect(fixtures.viewModel.displayFileName == "my_document.pdf")
    }

    @Test
    func displayFileSize_returnsFormattedSize() {
        let fixtures = makeFixtures(fileSize: 2_048)

        #expect(!fixtures.viewModel.displayFileSize.isEmpty)
    }

    @Test
    func hasContent_afterLoad_returnsTrue() async {
        let fixtures = makeFixtures()

        await fixtures.viewModel.loadContent()

        #expect(fixtures.viewModel.hasContent)
    }

    // MARK: - Load Content Tests

    @Test
    func loadContent_success_setsDecryptedData() async {
        let fixtures = makeFixtures()

        await fixtures.viewModel.loadContent()

        #expect(fixtures.viewModel.decryptedData != nil)
        #expect(fixtures.viewModel.errorMessage == nil)
        #expect(!fixtures.viewModel.isLoading)
    }

    @Test
    func loadContent_callsBlobService() async {
        let fixtures = makeFixtures()

        await fixtures.viewModel.loadContent()

        #expect(fixtures.blobService.retrieveCalls.count == 1)
        #expect(fixtures.blobService.retrieveCalls[0] == fixtures.document.contentHMAC)
    }

    @Test
    func loadContent_alreadyLoaded_doesNotReload() async {
        let fixtures = makeFixtures()

        await fixtures.viewModel.loadContent()
        await fixtures.viewModel.loadContent()

        #expect(fixtures.blobService.retrieveCalls.count == 1)
    }

    @Test
    func loadContent_failure_setsError() async {
        let fixtures = makeFixtures()
        fixtures.blobService.retrieveError = ModelError.attachmentContentCorrupted

        await fixtures.viewModel.loadContent()

        #expect(fixtures.viewModel.decryptedData == nil)
        #expect(fixtures.viewModel.errorMessage != nil)
    }

    @Test
    func loadContent_genericError_setsDefaultMessage() async {
        let fixtures = makeFixtures()
        fixtures.blobService.retrieveError = NSError(domain: "Test", code: 1)

        await fixtures.viewModel.loadContent()

        #expect(fixtures.viewModel.errorMessage != nil)
        #expect(fixtures.viewModel.decryptedData == nil)
    }

    // MARK: - Clear Decrypted Data Tests

    @Test
    func clearDecryptedData_removesData() async {
        let fixtures = makeFixtures()

        await fixtures.viewModel.loadContent()
        #expect(fixtures.viewModel.decryptedData != nil)

        fixtures.viewModel.clearDecryptedData()

        #expect(fixtures.viewModel.decryptedData == nil)
        #expect(!fixtures.viewModel.hasContent)
    }

    @Test
    func clearDecryptedData_whenNil_doesNothing() {
        let fixtures = makeFixtures()

        fixtures.viewModel.clearDecryptedData()

        #expect(fixtures.viewModel.decryptedData == nil)
    }

    // MARK: - Loading State Tests

    @Test
    func loadContent_setsLoadingFalseAfter() async {
        let fixtures = makeFixtures()

        await fixtures.viewModel.loadContent()

        #expect(!fixtures.viewModel.isLoading)
    }

    @Test
    func loadContent_failure_setsLoadingFalse() async {
        let fixtures = makeFixtures()
        fixtures.blobService.retrieveError = ModelError.attachmentContentCorrupted

        await fixtures.viewModel.loadContent()

        #expect(!fixtures.viewModel.isLoading)
    }

    // MARK: - Export Flow Tests

    @Test
    func requestExport_showsWarning() {
        let fixtures = makeFixtures()

        fixtures.viewModel.requestExport()

        #expect(fixtures.viewModel.showingExportWarning)
        #expect(!fixtures.viewModel.showingShareSheet)
    }

    @Test
    func confirmExport_hidesWarningShowsShareSheet() {
        let fixtures = makeFixtures()
        fixtures.viewModel.showingExportWarning = true

        fixtures.viewModel.confirmExport()

        #expect(!fixtures.viewModel.showingExportWarning)
        #expect(fixtures.viewModel.showingShareSheet)
    }

    @Test
    func cancelExport_hidesWarning() {
        let fixtures = makeFixtures()
        fixtures.viewModel.showingExportWarning = true

        fixtures.viewModel.cancelExport()

        #expect(!fixtures.viewModel.showingExportWarning)
        #expect(!fixtures.viewModel.showingShareSheet)
    }

    // MARK: - Temporary File URL Tests

    @Test
    func getTemporaryFileURL_noData_returnsNil() {
        let fixtures = makeFixtures()

        let url = fixtures.viewModel.getTemporaryFileURL()

        #expect(url == nil)
    }

    @Test
    func getTemporaryFileURL_withData_createsFile() async throws {
        let fixtures = makeFixtures()

        await fixtures.viewModel.loadContent()
        let url = try #require(fixtures.viewModel.getTemporaryFileURL())

        #expect(FileManager.default.fileExists(atPath: url.path))

        try? FileManager.default.removeItem(at: url)
    }

    @Test
    func getTemporaryFileURL_usesCorrectFileName() async throws {
        let fixtures = makeFixtures(title: "my_medical_document.pdf")

        await fixtures.viewModel.loadContent()
        let url = try #require(fixtures.viewModel.getTemporaryFileURL())

        #expect(url.lastPathComponent == "my_medical_document.pdf")

        try? FileManager.default.removeItem(at: url)
    }

    @Test
    func cleanupTemporaryFile_removesFile() async throws {
        let fixtures = makeFixtures()

        await fixtures.viewModel.loadContent()
        let url = try #require(fixtures.viewModel.getTemporaryFileURL())
        #expect(FileManager.default.fileExists(atPath: url.path))

        fixtures.viewModel.cleanupTemporaryFile()

        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    @Test
    func cleanupTemporaryFile_noFile_doesNotThrow() {
        let fixtures = makeFixtures()

        fixtures.viewModel.cleanupTemporaryFile()
    }
}
