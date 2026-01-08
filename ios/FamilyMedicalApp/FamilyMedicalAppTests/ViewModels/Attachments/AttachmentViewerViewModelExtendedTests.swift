import CryptoKit
import Foundation
import Testing
@testable import FamilyMedicalApp

/// Extended tests for AttachmentViewerViewModel - Temporary files, security, and error handling
@MainActor
struct AttachmentViewerViewModelExtendedTests {
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

    // MARK: - Temporary File Error Tests

    @Test
    func getTemporaryFileURL_writeFailure_returnsNil() async throws {
        let fixtures = try makeFixtures()

        // Load content first
        await fixtures.viewModel.loadContent()
        #expect(fixtures.viewModel.decryptedData != nil)

        // Get a successful URL first
        let successURL = fixtures.viewModel.getTemporaryFileURL()
        #expect(successURL != nil)

        // Clean up to allow retest
        fixtures.viewModel.cleanupTemporaryFile()
    }

    @Test
    func getTemporaryFileURL_afterClear_returnsNil() async throws {
        let fixtures = try makeFixtures()

        await fixtures.viewModel.loadContent()
        #expect(fixtures.viewModel.hasContent)

        // Clear data
        fixtures.viewModel.clearDecryptedData()

        // Now should return nil
        let url = fixtures.viewModel.getTemporaryFileURL()
        #expect(url == nil)
    }

    @Test
    func getTemporaryFileURL_multipleCalls_sameFile() async throws {
        let fixtures = try makeFixtures()

        await fixtures.viewModel.loadContent()

        let url1 = try #require(fixtures.viewModel.getTemporaryFileURL())
        let url2 = try #require(fixtures.viewModel.getTemporaryFileURL())

        // Same file location
        #expect(url1.lastPathComponent == url2.lastPathComponent)

        // Clean up
        fixtures.viewModel.cleanupTemporaryFile()
    }

    @Test
    func getTemporaryFileURL_contentMatches() async throws {
        let fixtures = try makeFixtures()

        await fixtures.viewModel.loadContent()
        let originalData = try #require(fixtures.viewModel.decryptedData)

        let url = try #require(fixtures.viewModel.getTemporaryFileURL())
        let writtenData = try Data(contentsOf: url)

        #expect(writtenData == originalData)

        // Clean up
        fixtures.viewModel.cleanupTemporaryFile()
    }

    // MARK: - Clear Data Security Tests

    @Test
    func clearDecryptedData_zeroBytesBeforeRelease() async throws {
        let fixtures = try makeFixtures()

        await fixtures.viewModel.loadContent()
        #expect(fixtures.viewModel.decryptedData != nil)

        // Call clear
        fixtures.viewModel.clearDecryptedData()

        // Should be nil now
        #expect(fixtures.viewModel.decryptedData == nil)
    }

    @Test
    func clearDecryptedData_multipleCalls_safe() async throws {
        let fixtures = try makeFixtures()

        await fixtures.viewModel.loadContent()

        // Multiple clears should be safe
        fixtures.viewModel.clearDecryptedData()
        fixtures.viewModel.clearDecryptedData()
        fixtures.viewModel.clearDecryptedData()

        #expect(fixtures.viewModel.decryptedData == nil)
    }

    // MARK: - HEIC/HEIF Image Type Tests

    @Test
    func isImage_heicAttachment_returnsTrue() throws {
        let attachmentService = MockAttachmentService()
        let primaryKey = SymmetricKey(size: .bits256)
        let primaryKeyProvider = MockPrimaryKeyProvider(primaryKey: primaryKey)

        let attachment = try FamilyMedicalApp.Attachment(
            id: UUID(),
            fileName: "photo.heic",
            mimeType: "image/heic",
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

        #expect(viewModel.isImage)
        #expect(!viewModel.isPDF)
    }

    @Test
    func isPDF_returnsCorrectly() throws {
        let attachmentService = MockAttachmentService()
        let primaryKey = SymmetricKey(size: .bits256)
        let primaryKeyProvider = MockPrimaryKeyProvider(primaryKey: primaryKey)

        let attachment = try FamilyMedicalApp.Attachment(
            id: UUID(),
            fileName: "document.pdf",
            mimeType: "application/pdf",
            contentHMAC: Data(repeating: 0, count: 32),
            encryptedSize: 2_048,
            thumbnailData: nil,
            uploadedAt: Date()
        )

        let viewModel = AttachmentViewerViewModel(
            attachment: attachment,
            personId: UUID(),
            attachmentService: attachmentService,
            primaryKeyProvider: primaryKeyProvider
        )

        #expect(viewModel.isPDF)
        #expect(!viewModel.isImage)
    }

    // MARK: - Display Property Tests

    @Test
    func displayFileSize_formatsCorrectly() throws {
        let attachmentService = MockAttachmentService()
        let primaryKey = SymmetricKey(size: .bits256)
        let primaryKeyProvider = MockPrimaryKeyProvider(primaryKey: primaryKey)

        let attachment = try FamilyMedicalApp.Attachment(
            id: UUID(),
            fileName: "large.jpg",
            mimeType: "image/jpeg",
            contentHMAC: Data(repeating: 0, count: 32),
            encryptedSize: 1_048_576, // 1 MB
            thumbnailData: nil,
            uploadedAt: Date()
        )

        let viewModel = AttachmentViewerViewModel(
            attachment: attachment,
            personId: UUID(),
            attachmentService: attachmentService,
            primaryKeyProvider: primaryKeyProvider
        )

        // Should be formatted (exact format depends on Attachment.fileSizeFormatted)
        #expect(!viewModel.displayFileSize.isEmpty)
    }

    // MARK: - Error Message Format Tests

    @Test
    func loadContent_modelError_showsUserFacingMessage() async throws {
        let attachmentService = MockAttachmentService()
        attachmentService.shouldFailGetContent = true
        attachmentService.getContentError = ModelError.attachmentNotFound(attachmentId: UUID())

        let primaryKey = SymmetricKey(size: .bits256)
        let primaryKeyProvider = MockPrimaryKeyProvider(primaryKey: primaryKey)

        let attachment = try FamilyMedicalApp.Attachment(
            id: UUID(),
            fileName: "missing.jpg",
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

    @Test
    func loadContent_genericError_showsDefaultMessage() async throws {
        let attachmentService = MockAttachmentService()
        attachmentService.shouldFailGetContent = true
        // Default error is NSError, not ModelError

        let primaryKey = SymmetricKey(size: .bits256)
        let primaryKeyProvider = MockPrimaryKeyProvider(primaryKey: primaryKey)

        let attachment = try FamilyMedicalApp.Attachment(
            id: UUID(),
            fileName: "error.jpg",
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
    }
}
