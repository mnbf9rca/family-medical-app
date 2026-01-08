import CryptoKit
import Foundation
import Testing
@testable import FamilyMedicalApp

/// Tests for AttachmentViewerViewModel initialization, computed properties, and content loading
@MainActor
struct AttachmentViewerViewModelTests {
    // MARK: - Test Fixtures

    struct TestFixtures {
        let viewModel: AttachmentViewerViewModel
        let attachmentService: MockAttachmentService
        let primaryKeyProvider: MockPrimaryKeyProvider
        let attachment: FamilyMedicalApp.Attachment
        let personId: UUID
        let primaryKey: SymmetricKey
    }

    func makeFixtures(
        fileName: String = "test.jpg",
        mimeType: String = "image/jpeg"
    ) throws -> TestFixtures {
        let attachmentService = MockAttachmentService()
        let primaryKey = SymmetricKey(size: .bits256)
        let primaryKeyProvider = MockPrimaryKeyProvider(primaryKey: primaryKey)
        let personId = UUID()

        let attachment = try AttachmentTestHelper.makeTestAttachmentDeterministic(
            fileName: fileName,
            mimeType: mimeType
        )

        attachmentService.addTestAttachment(
            attachment,
            content: Data("test content".utf8),
            linkedToRecord: UUID()
        )

        let viewModel = AttachmentViewerViewModel(
            attachment: attachment,
            personId: personId,
            attachmentService: attachmentService,
            primaryKeyProvider: primaryKeyProvider
        )

        return TestFixtures(
            viewModel: viewModel,
            attachmentService: attachmentService,
            primaryKeyProvider: primaryKeyProvider,
            attachment: attachment,
            personId: personId,
            primaryKey: primaryKey
        )
    }

    // MARK: - Initialization Tests

    @Test
    func init_setsAttachmentAndPersonId() throws {
        let fixtures = try makeFixtures()

        #expect(fixtures.viewModel.attachment.id == fixtures.attachment.id)
        #expect(fixtures.viewModel.personId == fixtures.personId)
    }

    @Test
    func init_startsWithNilDecryptedData() throws {
        let fixtures = try makeFixtures()

        #expect(fixtures.viewModel.decryptedData == nil)
        #expect(!fixtures.viewModel.hasContent)
    }

    @Test
    func init_notLoading() throws {
        let fixtures = try makeFixtures()

        #expect(!fixtures.viewModel.isLoading)
        #expect(fixtures.viewModel.errorMessage == nil)
    }

    @Test
    func init_sheetsNotShowing() throws {
        let fixtures = try makeFixtures()

        #expect(!fixtures.viewModel.showingExportWarning)
        #expect(!fixtures.viewModel.showingShareSheet)
    }

    // MARK: - Computed Properties Tests

    @Test
    func isImage_jpegAttachment_returnsTrue() throws {
        let fixtures = try makeFixtures(mimeType: "image/jpeg")

        #expect(fixtures.viewModel.isImage)
        #expect(!fixtures.viewModel.isPDF)
    }

    @Test
    func isImage_pngAttachment_returnsTrue() throws {
        let fixtures = try makeFixtures(fileName: "test.png", mimeType: "image/png")

        #expect(fixtures.viewModel.isImage)
        #expect(!fixtures.viewModel.isPDF)
    }

    @Test
    func isPDF_pdfAttachment_returnsTrue() throws {
        let fixtures = try makeFixtures(fileName: "test.pdf", mimeType: "application/pdf")

        #expect(fixtures.viewModel.isPDF)
        #expect(!fixtures.viewModel.isImage)
    }

    @Test
    func displayFileName_returnsAttachmentFileName() throws {
        let fixtures = try makeFixtures(fileName: "my_document.pdf")

        #expect(fixtures.viewModel.displayFileName == "my_document.pdf")
    }

    @Test
    func displayFileSize_returnsFormattedSize() throws {
        let fixtures = try makeFixtures()

        #expect(!fixtures.viewModel.displayFileSize.isEmpty)
    }

    @Test
    func hasContent_afterLoad_returnsTrue() async throws {
        let fixtures = try makeFixtures()

        await fixtures.viewModel.loadContent()

        #expect(fixtures.viewModel.hasContent)
    }

    // MARK: - Load Content Tests

    @Test
    func loadContent_success_setsDecryptedData() async throws {
        let fixtures = try makeFixtures()

        await fixtures.viewModel.loadContent()

        #expect(fixtures.viewModel.decryptedData != nil)
        #expect(fixtures.viewModel.errorMessage == nil)
        #expect(!fixtures.viewModel.isLoading)
    }

    @Test
    func loadContent_callsService() async throws {
        let fixtures = try makeFixtures()

        await fixtures.viewModel.loadContent()

        #expect(fixtures.attachmentService.getContentCalls.count == 1)
        #expect(fixtures.attachmentService.getContentCalls[0].attachment.id == fixtures.attachment.id)
        #expect(fixtures.attachmentService.getContentCalls[0].personId == fixtures.personId)
    }

    @Test
    func loadContent_alreadyLoaded_doesNotReload() async throws {
        let fixtures = try makeFixtures()

        await fixtures.viewModel.loadContent()
        await fixtures.viewModel.loadContent()

        #expect(fixtures.attachmentService.getContentCalls.count == 1)
    }

    @Test
    func loadContent_failure_setsError() async throws {
        let fixtures = try makeFixtures()
        fixtures.attachmentService.shouldFailGetContent = true

        await fixtures.viewModel.loadContent()

        #expect(fixtures.viewModel.decryptedData == nil)
        #expect(fixtures.viewModel.errorMessage != nil)
    }

    @Test
    func loadContent_primaryKeyFailure_setsError() async throws {
        let attachmentService = MockAttachmentService()
        let primaryKeyProvider = MockPrimaryKeyProvider(shouldFail: true)
        let attachment = try FamilyMedicalApp.Attachment(
            id: UUID(),
            fileName: "test.jpg",
            mimeType: "image/jpeg",
            contentHMAC: Data(repeating: 0, count: 32),
            encryptedSize: 1_024,
            thumbnailData: nil,
            uploadedAt: Date()
        )

        let viewModel = AttachmentViewerViewModel(
            attachment: attachment,
            personId: UUID(),
            attachmentService: attachmentService,
            primaryKeyProvider: primaryKeyProvider
        )

        await viewModel.loadContent()

        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.decryptedData == nil)
    }

    // MARK: - Clear Decrypted Data Tests

    @Test
    func clearDecryptedData_removesData() async throws {
        let fixtures = try makeFixtures()

        await fixtures.viewModel.loadContent()
        #expect(fixtures.viewModel.decryptedData != nil)

        fixtures.viewModel.clearDecryptedData()

        #expect(fixtures.viewModel.decryptedData == nil)
        #expect(!fixtures.viewModel.hasContent)
    }

    @Test
    func clearDecryptedData_whenNil_doesNothing() throws {
        let fixtures = try makeFixtures()

        fixtures.viewModel.clearDecryptedData()

        #expect(fixtures.viewModel.decryptedData == nil)
    }

    // MARK: - Loading State Tests

    @Test
    func loadContent_setsLoadingFalseAfter() async throws {
        let fixtures = try makeFixtures()

        await fixtures.viewModel.loadContent()

        #expect(!fixtures.viewModel.isLoading)
    }

    @Test
    func loadContent_failure_setsLoadingFalse() async throws {
        let fixtures = try makeFixtures()
        fixtures.attachmentService.shouldFailGetContent = true

        await fixtures.viewModel.loadContent()

        #expect(!fixtures.viewModel.isLoading)
    }

    // MARK: - Error Message Tests

    @Test
    func loadContent_serviceError_showsUserFacingMessage() async throws {
        let fixtures = try makeFixtures()
        fixtures.attachmentService.shouldFailGetContent = true

        await fixtures.viewModel.loadContent()

        #expect(fixtures.viewModel.errorMessage != nil)
        #expect(fixtures.viewModel.errorMessage?.isEmpty == false)
    }

    // MARK: - Export Flow Tests

    @Test
    func requestExport_showsWarning() throws {
        let fixtures = try makeFixtures()

        fixtures.viewModel.requestExport()

        #expect(fixtures.viewModel.showingExportWarning)
        #expect(!fixtures.viewModel.showingShareSheet)
    }

    @Test
    func confirmExport_hidesWarningShowsShareSheet() throws {
        let fixtures = try makeFixtures()
        fixtures.viewModel.showingExportWarning = true

        fixtures.viewModel.confirmExport()

        #expect(!fixtures.viewModel.showingExportWarning)
        #expect(fixtures.viewModel.showingShareSheet)
    }

    @Test
    func cancelExport_hidesWarning() throws {
        let fixtures = try makeFixtures()
        fixtures.viewModel.showingExportWarning = true

        fixtures.viewModel.cancelExport()

        #expect(!fixtures.viewModel.showingExportWarning)
        #expect(!fixtures.viewModel.showingShareSheet)
    }

    // MARK: - Temporary File URL Tests

    @Test
    func getTemporaryFileURL_noData_returnsNil() throws {
        let fixtures = try makeFixtures()

        let url = fixtures.viewModel.getTemporaryFileURL()

        #expect(url == nil)
    }

    @Test
    func getTemporaryFileURL_withData_createsFile() async throws {
        let fixtures = try makeFixtures()

        await fixtures.viewModel.loadContent()
        let url = try #require(fixtures.viewModel.getTemporaryFileURL())

        #expect(FileManager.default.fileExists(atPath: url.path))

        // Clean up
        try? FileManager.default.removeItem(at: url)
    }

    @Test
    func getTemporaryFileURL_usesCorrectFileName() async throws {
        let fixtures = try makeFixtures(fileName: "my_medical_document.pdf")

        await fixtures.viewModel.loadContent()
        let url = try #require(fixtures.viewModel.getTemporaryFileURL())

        #expect(url.lastPathComponent == "my_medical_document.pdf")

        // Clean up
        try? FileManager.default.removeItem(at: url)
    }

    @Test
    func cleanupTemporaryFile_removesFile() async throws {
        let fixtures = try makeFixtures()

        await fixtures.viewModel.loadContent()
        let url = try #require(fixtures.viewModel.getTemporaryFileURL())
        #expect(FileManager.default.fileExists(atPath: url.path))

        fixtures.viewModel.cleanupTemporaryFile()

        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    @Test
    func cleanupTemporaryFile_noFile_doesNotThrow() throws {
        let fixtures = try makeFixtures()

        // Should not throw even if file doesn't exist
        fixtures.viewModel.cleanupTemporaryFile()
    }
}
