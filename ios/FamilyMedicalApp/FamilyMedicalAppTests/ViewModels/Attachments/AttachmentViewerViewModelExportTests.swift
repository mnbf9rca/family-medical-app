import CryptoKit
import Foundation
import Testing
@testable import FamilyMedicalApp

/// Tests for AttachmentViewerViewModel export flow, temporary files, and display properties
@MainActor
struct AttachmentViewerViewModelExportTests {
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

        let attachment = try FamilyMedicalApp.Attachment(
            id: UUID(),
            fileName: fileName,
            mimeType: mimeType,
            contentHMAC: Data(repeating: 0xAB, count: 32),
            encryptedSize: 1_024,
            thumbnailData: nil,
            uploadedAt: Date()
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

    // MARK: - Export Flow Tests

    @Test
    func requestExport_showsWarning() throws {
        let fixtures = try makeFixtures()

        fixtures.viewModel.requestExport()

        #expect(fixtures.viewModel.showingExportWarning)
        #expect(!fixtures.viewModel.showingShareSheet)
    }

    @Test
    func confirmExport_showsShareSheet() throws {
        let fixtures = try makeFixtures()

        fixtures.viewModel.requestExport()
        fixtures.viewModel.confirmExport()

        #expect(!fixtures.viewModel.showingExportWarning)
        #expect(fixtures.viewModel.showingShareSheet)
    }

    @Test
    func cancelExport_hidesWarning() throws {
        let fixtures = try makeFixtures()

        fixtures.viewModel.requestExport()
        fixtures.viewModel.cancelExport()

        #expect(!fixtures.viewModel.showingExportWarning)
        #expect(!fixtures.viewModel.showingShareSheet)
    }

    @Test
    func exportFlow_requestConfirmCancel() throws {
        let fixtures = try makeFixtures()

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
    func exportFlow_requestConfirmConfirm() throws {
        let fixtures = try makeFixtures()

        fixtures.viewModel.requestExport()
        fixtures.viewModel.confirmExport()

        #expect(!fixtures.viewModel.showingExportWarning)
        #expect(fixtures.viewModel.showingShareSheet)
    }

    // MARK: - Temporary File Tests

    @Test
    func getTemporaryFileURL_withContent_returnsURL() async throws {
        let fixtures = try makeFixtures()

        await fixtures.viewModel.loadContent()
        let url = fixtures.viewModel.getTemporaryFileURL()

        #expect(url != nil)
        #expect(url?.lastPathComponent == fixtures.attachment.fileName)

        if let url {
            try? FileManager.default.removeItem(at: url)
        }
    }

    @Test
    func getTemporaryFileURL_withoutContent_returnsNil() throws {
        let fixtures = try makeFixtures()

        let url = fixtures.viewModel.getTemporaryFileURL()

        #expect(url == nil)
    }

    @Test
    func cleanupTemporaryFile_removesFile() async throws {
        let fixtures = try makeFixtures()

        await fixtures.viewModel.loadContent()
        let url = fixtures.viewModel.getTemporaryFileURL()
        #expect(url != nil)

        fixtures.viewModel.cleanupTemporaryFile()

        if let url {
            #expect(!FileManager.default.fileExists(atPath: url.path))
        }
    }

    @Test
    func cleanupTemporaryFile_noFile_doesNotThrow() throws {
        let fixtures = try makeFixtures()
        fixtures.viewModel.cleanupTemporaryFile()
    }

    @Test
    func getTemporaryFileURL_createsFileWithCorrectName() async throws {
        let fixtures = try makeFixtures(fileName: "my_file.jpg")

        await fixtures.viewModel.loadContent()
        let url = fixtures.viewModel.getTemporaryFileURL()

        #expect(url != nil)
        #expect(url?.lastPathComponent == "my_file.jpg")

        fixtures.viewModel.cleanupTemporaryFile()
    }

    @Test
    func getTemporaryFileURL_writesCorrectData() async throws {
        let fixtures = try makeFixtures()
        let testContent = Data("test content".utf8)

        fixtures.attachmentService.addTestAttachment(
            fixtures.attachment,
            content: testContent,
            linkedToRecord: UUID()
        )

        await fixtures.viewModel.loadContent()
        let url = fixtures.viewModel.getTemporaryFileURL()

        if let url {
            let writtenData = try Data(contentsOf: url)
            #expect(!writtenData.isEmpty)
            fixtures.viewModel.cleanupTemporaryFile()
        }
    }

    // MARK: - Content Type Detection Tests

    @Test
    func isImage_differentImageType_returnsTrue() throws {
        let fixtures = try makeFixtures(fileName: "test.gif", mimeType: "image/gif")
        #expect(fixtures.viewModel.isImage)
    }

    @Test
    func isPDF_applicationPDF_returnsTrue() throws {
        let fixtures = try makeFixtures(fileName: "doc.pdf", mimeType: "application/pdf")
        #expect(fixtures.viewModel.isPDF)
        #expect(!fixtures.viewModel.isImage)
    }

    // MARK: - Display Properties Tests

    @Test
    func displayFileName_matchesAttachmentFileName() throws {
        let fixtures = try makeFixtures(fileName: "medical_report.pdf")
        #expect(fixtures.viewModel.displayFileName == "medical_report.pdf")
    }

    @Test
    func displayFileSize_isNotEmpty() throws {
        let fixtures = try makeFixtures()
        #expect(!fixtures.viewModel.displayFileSize.isEmpty)
    }

    // MARK: - Memory Cleanup Tests

    @Test
    func clearDecryptedData_afterMultipleLoads_clearsData() async throws {
        let fixtures = try makeFixtures()

        await fixtures.viewModel.loadContent()
        #expect(fixtures.viewModel.hasContent)

        fixtures.viewModel.clearDecryptedData()
        #expect(!fixtures.viewModel.hasContent)
    }

    // MARK: - PersonId Tests

    @Test
    func personId_isCorrectlySet() throws {
        let expectedPersonId = UUID()
        let attachmentService = MockAttachmentService()
        let primaryKeyProvider = MockPrimaryKeyProvider(primaryKey: SymmetricKey(size: .bits256))
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
            personId: expectedPersonId,
            attachmentService: attachmentService,
            primaryKeyProvider: primaryKeyProvider
        )

        #expect(viewModel.personId == expectedPersonId)
    }
}
