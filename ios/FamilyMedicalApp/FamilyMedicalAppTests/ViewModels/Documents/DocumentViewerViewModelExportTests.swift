import CryptoKit
import Foundation
import Testing
@testable import FamilyMedicalApp

/// Tests for DocumentViewerViewModel export flow, temporary files, and display properties.
@MainActor
struct DocumentViewerViewModelExportTests {
    // MARK: - Test Fixtures

    struct TestFixtures {
        let viewModel: DocumentViewerViewModel
        let blobService: MockDocumentBlobService
        let document: DocumentReferenceRecord
    }

    func makeFixtures(
        title: String = "test.jpg",
        mimeType: String = "image/jpeg"
    ) -> TestFixtures {
        let blobService = MockDocumentBlobService()
        blobService.retrieveResult = Data("test content".utf8)
        let primaryKey = SymmetricKey(size: .bits256)

        let document = DocumentReferenceRecord(
            title: title,
            mimeType: mimeType,
            fileSize: 1_024,
            contentHMAC: Data(repeating: 0xAB, count: 32)
        )

        let viewModel = DocumentViewerViewModel(
            document: document,
            personId: UUID(),
            primaryKey: primaryKey,
            blobService: blobService
        )
        return TestFixtures(viewModel: viewModel, blobService: blobService, document: document)
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
    func confirmExport_showsShareSheet() {
        let fixtures = makeFixtures()

        fixtures.viewModel.requestExport()
        fixtures.viewModel.confirmExport()

        #expect(!fixtures.viewModel.showingExportWarning)
        #expect(fixtures.viewModel.showingShareSheet)
    }

    @Test
    func cancelExport_hidesWarning() {
        let fixtures = makeFixtures()

        fixtures.viewModel.requestExport()
        fixtures.viewModel.cancelExport()

        #expect(!fixtures.viewModel.showingExportWarning)
        #expect(!fixtures.viewModel.showingShareSheet)
    }

    @Test
    func exportFlow_requestThenCancel() {
        let fixtures = makeFixtures()

        #expect(!fixtures.viewModel.showingExportWarning)
        #expect(!fixtures.viewModel.showingShareSheet)

        fixtures.viewModel.requestExport()
        #expect(fixtures.viewModel.showingExportWarning)
        #expect(!fixtures.viewModel.showingShareSheet)

        fixtures.viewModel.cancelExport()
        #expect(!fixtures.viewModel.showingExportWarning)
        #expect(!fixtures.viewModel.showingShareSheet)
    }

    @Test
    func exportFlow_requestThenConfirm() {
        let fixtures = makeFixtures()

        fixtures.viewModel.requestExport()
        fixtures.viewModel.confirmExport()

        #expect(!fixtures.viewModel.showingExportWarning)
        #expect(fixtures.viewModel.showingShareSheet)
    }

    // MARK: - Temporary File Tests

    @Test
    func getTemporaryFileURL_withContent_returnsURL() async {
        let fixtures = makeFixtures()

        await fixtures.viewModel.loadContent()
        let url = fixtures.viewModel.getTemporaryFileURL()

        #expect(url != nil)
        // Filename is HMAC hex prefix + MIME extension, not the user-provided title
        let hmacHex = fixtures.document.contentHMAC.prefix(8).map { String(format: "%02x", $0) }.joined()
        #expect(url?.lastPathComponent == "\(hmacHex).jpeg")

        if let url {
            try? FileManager.default.removeItem(at: url)
        }
    }

    @Test
    func getTemporaryFileURL_withoutContent_returnsNil() {
        let fixtures = makeFixtures()

        let url = fixtures.viewModel.getTemporaryFileURL()

        #expect(url == nil)
    }

    @Test
    func cleanupTemporaryFile_removesFile() async {
        let fixtures = makeFixtures()

        await fixtures.viewModel.loadContent()
        let url = fixtures.viewModel.getTemporaryFileURL()
        #expect(url != nil)

        fixtures.viewModel.cleanupTemporaryFile()

        if let url {
            #expect(!FileManager.default.fileExists(atPath: url.path))
        }
    }

    @Test
    func cleanupTemporaryFile_noFile_doesNotThrow() {
        let fixtures = makeFixtures()
        fixtures.viewModel.cleanupTemporaryFile()
    }

    @Test
    func getTemporaryFileURL_createsFileWithHMACName() async {
        let fixtures = makeFixtures(title: "my_file.jpg")

        await fixtures.viewModel.loadContent()
        let url = fixtures.viewModel.getTemporaryFileURL()

        // Filename is HMAC hex prefix + MIME extension, not the user-provided title
        let hmacHex = fixtures.document.contentHMAC.prefix(8).map { String(format: "%02x", $0) }.joined()
        #expect(url?.lastPathComponent == "\(hmacHex).jpeg")

        fixtures.viewModel.cleanupTemporaryFile()
    }

    @Test
    func getTemporaryFileURL_writesCorrectData() async {
        let fixtures = makeFixtures()

        await fixtures.viewModel.loadContent()
        let url = fixtures.viewModel.getTemporaryFileURL()

        if let url {
            let writtenData = try? Data(contentsOf: url)
            #expect(writtenData?.isEmpty == false)
            fixtures.viewModel.cleanupTemporaryFile()
        }
    }

    // MARK: - Content Type Detection Tests

    @Test
    func isImage_gif_returnsTrue() {
        let fixtures = makeFixtures(title: "test.gif", mimeType: "image/gif")
        #expect(fixtures.viewModel.isImage)
    }

    @Test
    func isPDF_applicationPDF_returnsTrue() {
        let fixtures = makeFixtures(title: "doc.pdf", mimeType: "application/pdf")
        #expect(fixtures.viewModel.isPDF)
        #expect(!fixtures.viewModel.isImage)
    }

    // MARK: - Display Properties Tests

    @Test
    func displayFileName_matchesDocumentTitle() {
        let fixtures = makeFixtures(title: "medical_report.pdf")
        #expect(fixtures.viewModel.displayFileName == "medical_report.pdf")
    }

    @Test
    func displayFileSize_isNotEmpty() {
        let fixtures = makeFixtures()
        #expect(!fixtures.viewModel.displayFileSize.isEmpty)
    }

    // MARK: - Memory Cleanup Tests

    @Test
    func clearDecryptedData_afterLoad_clearsData() async {
        let fixtures = makeFixtures()

        await fixtures.viewModel.loadContent()
        #expect(fixtures.viewModel.hasContent)

        fixtures.viewModel.clearDecryptedData()
        #expect(!fixtures.viewModel.hasContent)
    }

    // MARK: - PersonId Tests

    @Test
    func personId_isCorrectlySet() {
        let expectedPersonId = UUID()
        let blobService = MockDocumentBlobService()
        let primaryKey = SymmetricKey(size: .bits256)
        let document = DocumentReferenceRecord(
            title: "test.jpg",
            mimeType: "image/jpeg",
            fileSize: 1_024,
            contentHMAC: Data(repeating: 0, count: 32)
        )

        let viewModel = DocumentViewerViewModel(
            document: document,
            personId: expectedPersonId,
            primaryKey: primaryKey,
            blobService: blobService
        )

        #expect(viewModel.personId == expectedPersonId)
    }
}
