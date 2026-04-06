import CryptoKit
import Foundation
import Observation
import UniformTypeIdentifiers

/// ViewModel for viewing a DocumentReferenceRecord's decrypted content in full-screen.
///
/// Handles loading, decrypting, and displaying attachment content with security features
/// like export warnings and memory clearing. Content is fetched via DocumentBlobService
/// keyed by the document's contentHMAC.
@MainActor
@Observable
final class DocumentViewerViewModel {
    // MARK: - State

    /// The DocumentReferenceRecord being viewed.
    let document: DocumentReferenceRecord

    /// Decrypted content data (cleared on dismiss for security).
    var decryptedData: Data?

    /// Loading state.
    var isLoading = false

    /// Error message for display.
    var errorMessage: String?

    /// Whether to show export warning dialog.
    var showingExportWarning = false

    /// Whether to show share sheet.
    var showingShareSheet = false

    // MARK: - Context

    /// The person this document belongs to.
    let personId: UUID

    /// Primary key used by the blob service to derive the FMK.
    @ObservationIgnored private let primaryKey: SymmetricKey

    // MARK: - Dependencies

    @ObservationIgnored private let blobService: DocumentBlobServiceProtocol
    @ObservationIgnored private let logger: TracingCategoryLogger

    // MARK: - Computed Properties

    var isImage: Bool {
        document.mimeType.hasPrefix("image/")
    }

    var isPDF: Bool {
        document.mimeType == "application/pdf"
    }

    var displayFileName: String {
        document.title
    }

    var displayFileSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(document.fileSize), countStyle: .file)
    }

    var hasContent: Bool {
        decryptedData != nil
    }

    // MARK: - Initialization

    init(
        document: DocumentReferenceRecord,
        personId: UUID,
        primaryKey: SymmetricKey,
        blobService: DocumentBlobServiceProtocol? = nil,
        logger: CategoryLoggerProtocol? = nil
    ) {
        self.document = document
        self.personId = personId
        self.primaryKey = primaryKey
        self.blobService = blobService ?? DocumentBlobService.makeDefault()
        self.logger = TracingCategoryLogger(
            wrapping: logger ?? LoggingService.shared.logger(category: .storage)
        )
    }

    // MARK: - Actions

    /// Load and decrypt the document content.
    func loadContent() async {
        guard decryptedData == nil else {
            return
        }
        isLoading = true
        errorMessage = nil

        do {
            decryptedData = try await blobService.retrieve(
                contentHMAC: document.contentHMAC,
                personId: personId,
                primaryKey: primaryKey
            )
        } catch let error as ModelError {
            errorMessage = error.userFacingMessage
            logger.logError(error, context: "DocumentViewerViewModel.loadContent")
        } catch {
            errorMessage = "Unable to load document. Please try again."
            logger.logError(error, context: "DocumentViewerViewModel.loadContent")
        }
        isLoading = false
    }

    /// Request to export/share the document (shows warning dialog).
    func requestExport() {
        showingExportWarning = true
    }

    /// Confirm export after warning acknowledgment.
    func confirmExport() {
        showingExportWarning = false
        showingShareSheet = true
    }

    /// Cancel export.
    func cancelExport() {
        showingExportWarning = false
    }

    /// Clear decrypted data from memory.
    ///
    /// SECURITY: call this when dismissing the viewer so decrypted content does not linger.
    func clearDecryptedData() {
        decryptedData?.withUnsafeMutableBytes { buffer in
            guard let baseAddress = buffer.baseAddress else { return }
            memset(baseAddress, 0, buffer.count)
        }
        decryptedData = nil
    }

    /// Temporary URL for sharing. Writes the decrypted data to a file in the temp directory.
    func getTemporaryFileURL() -> URL? {
        guard let data = decryptedData else { return nil }
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(sanitizedFileName)
        do {
            try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
            return fileURL
        } catch {
            logger.logError(error, context: "DocumentViewerViewModel.getTemporaryFileURL")
            return nil
        }
    }

    /// Clean up the temporary export file.
    func cleanupTemporaryFile() {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(sanitizedFileName)
        try? FileManager.default.removeItem(at: fileURL)
    }

    /// Derives a safe filename from the content HMAC hex and MIME-based extension.
    /// Zero user input in the filesystem path — prevents path traversal by construction.
    private var sanitizedFileName: String {
        let hexPrefix = document.contentHMAC.prefix(8).map { String(format: "%02x", $0) }.joined()
        let ext = UTType(mimeType: document.mimeType)?.preferredFilenameExtension ?? "bin"
        return "\(hexPrefix).\(ext)"
    }
}
