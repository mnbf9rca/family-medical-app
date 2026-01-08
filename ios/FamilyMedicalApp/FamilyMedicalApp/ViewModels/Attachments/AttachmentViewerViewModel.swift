import CryptoKit
import Foundation
import Observation

/// ViewModel for viewing attachment content in full-screen
///
/// Handles loading, decrypting, and displaying attachment content with security
/// features like export warnings and memory clearing.
@MainActor
@Observable
final class AttachmentViewerViewModel {
    // MARK: - State

    /// The attachment being viewed
    let attachment: Attachment

    /// Decrypted content data (cleared on dismiss for security)
    var decryptedData: Data?

    /// Loading state
    var isLoading = false

    /// Error message for display
    var errorMessage: String?

    /// Whether to show export warning dialog
    var showingExportWarning = false

    /// Whether to show share sheet
    var showingShareSheet = false

    // MARK: - Context

    /// The person this attachment belongs to
    let personId: UUID

    // MARK: - Dependencies

    private let attachmentService: AttachmentServiceProtocol
    private let primaryKeyProvider: PrimaryKeyProviderProtocol
    private let logger = LoggingService.shared.logger(category: .storage)

    // MARK: - Computed Properties

    /// Whether content is an image
    var isImage: Bool {
        attachment.isImage
    }

    /// Whether content is a PDF
    var isPDF: Bool {
        attachment.isPDF
    }

    /// File name for display
    var displayFileName: String {
        attachment.fileName
    }

    /// File size for display
    var displayFileSize: String {
        attachment.fileSizeFormatted
    }

    /// Whether content has been loaded
    var hasContent: Bool {
        decryptedData != nil
    }

    // MARK: - Initialization

    /// Initialize the viewer ViewModel
    ///
    /// - Parameters:
    ///   - attachment: The attachment to view
    ///   - personId: The person this attachment belongs to
    ///   - attachmentService: Service for content retrieval
    ///   - primaryKeyProvider: Provider for encryption key
    init(
        attachment: Attachment,
        personId: UUID,
        attachmentService: AttachmentServiceProtocol? = nil,
        primaryKeyProvider: PrimaryKeyProviderProtocol? = nil
    ) {
        self.attachment = attachment
        self.personId = personId

        // Use default implementations if not provided (for testing)
        self.attachmentService = attachmentService ?? Self.createDefaultAttachmentService()
        self.primaryKeyProvider = primaryKeyProvider ?? PrimaryKeyProvider()
    }

    // MARK: - Actions

    /// Load and decrypt attachment content
    func loadContent() async {
        guard decryptedData == nil else {
            return // Already loaded
        }

        isLoading = true
        errorMessage = nil

        do {
            let primaryKey = try primaryKeyProvider.getPrimaryKey()

            decryptedData = try await attachmentService.getContent(
                attachment: attachment,
                personId: personId,
                primaryKey: primaryKey
            )
        } catch let error as ModelError {
            errorMessage = error.userFacingMessage
            logger.logError(error, context: "AttachmentViewerViewModel.loadContent")
        } catch {
            errorMessage = "Unable to load attachment. Please try again."
            logger.logError(error, context: "AttachmentViewerViewModel.loadContent")
        }

        isLoading = false
    }

    /// Request to export/share the attachment
    ///
    /// Shows warning dialog before proceeding.
    func requestExport() {
        showingExportWarning = true
    }

    /// Confirm export after warning acknowledgment
    func confirmExport() {
        showingExportWarning = false
        showingShareSheet = true
    }

    /// Cancel export
    func cancelExport() {
        showingExportWarning = false
    }

    /// Clear decrypted data from memory
    ///
    /// SECURITY: Call this when dismissing the viewer to prevent
    /// decrypted content from remaining in memory.
    func clearDecryptedData() {
        // Zero out the data before releasing
        if var data = decryptedData {
            data.resetBytes(in: 0 ..< data.count)
        }
        decryptedData = nil
    }

    /// Get temporary URL for sharing
    ///
    /// Creates a temporary file for the share sheet. File is deleted after share completes.
    func getTemporaryFileURL() -> URL? {
        guard let data = decryptedData else {
            return nil
        }

        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(attachment.fileName)

        do {
            // Write to temp file (will be cleaned up by system)
            try data.write(to: fileURL)
            return fileURL
        } catch {
            logger.logError(error, context: "AttachmentViewerViewModel.getTemporaryFileURL")
            return nil
        }
    }

    /// Clean up temporary export file
    func cleanupTemporaryFile() {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(attachment.fileName)

        try? FileManager.default.removeItem(at: fileURL)
    }

    // MARK: - Private Helpers

    /// Create default attachment service with all dependencies
    private static func createDefaultAttachmentService() -> AttachmentServiceProtocol {
        let coreDataStack = CoreDataStack.shared
        let encryptionService = EncryptionService()
        let fmkService = FamilyMemberKeyService()

        let attachmentRepository = AttachmentRepository(
            coreDataStack: coreDataStack,
            encryptionService: encryptionService,
            fmkService: fmkService
        )

        // Create file storage
        let fileStorage: AttachmentFileStorageServiceProtocol
        do {
            fileStorage = try AttachmentFileStorageService()
        } catch {
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("Attachments")
            try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            fileStorage = AttachmentFileStorageService(attachmentsDirectory: tempDir)
        }

        let imageProcessor = ImageProcessingService()

        return AttachmentService(
            attachmentRepository: attachmentRepository,
            fileStorage: fileStorage,
            imageProcessor: imageProcessor,
            encryptionService: encryptionService,
            fmkService: fmkService
        )
    }
}
