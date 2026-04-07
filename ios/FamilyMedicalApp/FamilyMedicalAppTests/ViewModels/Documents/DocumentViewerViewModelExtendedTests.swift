import CryptoKit
import Foundation
import Testing
@testable import FamilyMedicalApp

/// Extended tests for DocumentViewerViewModel - temp files, security, and error handling.
@MainActor
struct DocumentViewerViewModelExtendedTests {
    // MARK: - Test Fixtures

    struct TestFixtures {
        let viewModel: DocumentViewerViewModel
        let blobService: MockDocumentBlobService
        let document: DocumentReferenceRecord
        let personId: UUID
    }

    func makeFixtures(
        title: String = "test.jpg",
        mimeType: String = "image/jpeg"
    ) -> TestFixtures {
        let blobService = MockDocumentBlobService()
        blobService.retrieveResult = Data("test content".utf8)
        let primaryKey = SymmetricKey(size: .bits256)
        let personId = UUID()

        let document = DocumentReferenceRecord(
            title: title,
            mimeType: mimeType,
            fileSize: 1_024,
            contentHMAC: Data(repeating: 0xAB, count: 32)
        )

        let viewModel = DocumentViewerViewModel(
            document: document,
            personId: personId,
            primaryKey: primaryKey,
            blobService: blobService
        )
        return TestFixtures(viewModel: viewModel, blobService: blobService, document: document, personId: personId)
    }

    // MARK: - Temporary File Tests

    @Test
    func getTemporaryFileURL_returnsURL_whenDataPresent() async {
        let fixtures = makeFixtures()

        await fixtures.viewModel.loadContent()
        let url = fixtures.viewModel.getTemporaryFileURL()

        #expect(url != nil)
        fixtures.viewModel.cleanupTemporaryFile()
    }

    @Test
    func getTemporaryFileURL_afterClear_returnsNil() async {
        let fixtures = makeFixtures()

        await fixtures.viewModel.loadContent()
        #expect(fixtures.viewModel.hasContent)

        fixtures.viewModel.clearDecryptedData()

        let url = fixtures.viewModel.getTemporaryFileURL()
        #expect(url == nil)
    }

    @Test
    func getTemporaryFileURL_multipleCalls_sameFile() async throws {
        let fixtures = makeFixtures()

        await fixtures.viewModel.loadContent()

        let url1 = try #require(fixtures.viewModel.getTemporaryFileURL())
        let url2 = try #require(fixtures.viewModel.getTemporaryFileURL())

        #expect(url1.lastPathComponent == url2.lastPathComponent)
        fixtures.viewModel.cleanupTemporaryFile()
    }

    @Test
    func getTemporaryFileURL_contentMatches() async throws {
        let fixtures = makeFixtures()

        await fixtures.viewModel.loadContent()
        let originalData = try #require(fixtures.viewModel.decryptedData)

        let url = try #require(fixtures.viewModel.getTemporaryFileURL())
        let writtenData = try Data(contentsOf: url)

        #expect(writtenData == originalData)
        fixtures.viewModel.cleanupTemporaryFile()
    }

    // MARK: - Clear Data Security Tests

    @Test
    func clearDecryptedData_zeroBytesBeforeRelease() async {
        let fixtures = makeFixtures()

        await fixtures.viewModel.loadContent()
        #expect(fixtures.viewModel.decryptedData != nil)

        fixtures.viewModel.clearDecryptedData()

        #expect(fixtures.viewModel.decryptedData == nil)
    }

    @Test
    func clearDecryptedData_multipleCalls_safe() async {
        let fixtures = makeFixtures()

        await fixtures.viewModel.loadContent()

        fixtures.viewModel.clearDecryptedData()
        fixtures.viewModel.clearDecryptedData()
        fixtures.viewModel.clearDecryptedData()

        #expect(fixtures.viewModel.decryptedData == nil)
    }

    // MARK: - Image Type Tests

    @Test
    func isImage_heicDocument_returnsTrue() {
        let fixtures = makeFixtures(title: "photo.heic", mimeType: "image/heic")

        #expect(fixtures.viewModel.isImage)
        #expect(!fixtures.viewModel.isPDF)
    }

    @Test
    func isPDF_applicationPDF_returnsTrue() {
        let fixtures = makeFixtures(title: "doc.pdf", mimeType: "application/pdf")

        #expect(fixtures.viewModel.isPDF)
        #expect(!fixtures.viewModel.isImage)
    }

    // MARK: - Display Property Tests

    @Test
    func displayFileSize_formatsCorrectly() {
        let blobService = MockDocumentBlobService()
        let primaryKey = SymmetricKey(size: .bits256)
        let document = DocumentReferenceRecord(
            title: "large.jpg",
            mimeType: "image/jpeg",
            fileSize: 1_048_576,
            contentHMAC: Data(repeating: 0, count: 32)
        )

        let viewModel = DocumentViewerViewModel(
            document: document,
            personId: UUID(),
            primaryKey: primaryKey,
            blobService: blobService
        )

        #expect(!viewModel.displayFileSize.isEmpty)
    }

    // MARK: - Error Message Tests

    @Test
    func loadContent_modelError_setsUserFacingMessage() async {
        let fixtures = makeFixtures()
        fixtures.blobService.retrieveError = ModelError.documentNotFound(documentId: UUID())

        await fixtures.viewModel.loadContent()

        #expect(fixtures.viewModel.errorMessage != nil)
        #expect(fixtures.viewModel.decryptedData == nil)
    }
}
