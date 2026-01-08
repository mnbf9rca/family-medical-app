import CryptoKit
import Foundation
import Observation
import PhotosUI
import SwiftUI
import UIKit

/// ViewModel for selecting and managing attachments in a medical record form
///
/// Handles adding attachments from camera, photo library, and document picker,
/// as well as removing existing attachments.
@MainActor
@Observable
final class AttachmentPickerViewModel {
    // MARK: - State

    /// Currently selected/existing attachments
    var attachments: [Attachment] = []

    /// Loading state for async operations
    var isLoading = false

    /// Error message for display
    var errorMessage: String?

    /// Whether camera sheet should be shown
    var showingCamera = false

    /// Whether photo library picker should be shown
    var showingPhotoLibrary = false

    /// Whether document picker should be shown
    var showingDocumentPicker = false

    // MARK: - Context

    /// The record ID (nil for new records, attachments linked on save)
    let recordId: UUID?

    /// The person this record belongs to
    let personId: UUID

    // MARK: - Constants

    /// Maximum number of attachments per record
    static let maxAttachments = AttachmentService.maxAttachmentsPerRecord

    /// Maximum file size in bytes
    static let maxFileSizeBytes = AttachmentService.maxFileSizeBytes

    // MARK: - Dependencies

    private let attachmentService: AttachmentServiceProtocol
    private let primaryKeyProvider: PrimaryKeyProviderProtocol
    private let logger = LoggingService.shared.logger(category: .storage)

    // MARK: - Computed Properties

    /// Whether more attachments can be added
    var canAddMore: Bool {
        attachments.count < Self.maxAttachments
    }

    /// Remaining attachment slots
    var remainingSlots: Int {
        max(0, Self.maxAttachments - attachments.count)
    }

    /// Summary text for attachment count
    var countSummary: String {
        "\(attachments.count) of \(Self.maxAttachments) attachments"
    }

    // MARK: - Initialization

    /// Initialize the picker ViewModel
    ///
    /// - Parameters:
    ///   - personId: The person this record belongs to
    ///   - recordId: Optional existing record ID (nil for new records)
    ///   - existingAttachments: Pre-loaded attachments for editing
    ///   - attachmentService: Service for attachment operations
    ///   - primaryKeyProvider: Provider for encryption key
    init(
        personId: UUID,
        recordId: UUID? = nil,
        existingAttachments: [Attachment] = [],
        attachmentService: AttachmentServiceProtocol? = nil,
        primaryKeyProvider: PrimaryKeyProviderProtocol? = nil
    ) {
        self.personId = personId
        self.recordId = recordId
        self.attachments = existingAttachments

        // Use default implementations if not provided (for testing)
        self.attachmentService = attachmentService ?? Self.createDefaultAttachmentService()
        self.primaryKeyProvider = primaryKeyProvider ?? PrimaryKeyProvider()

        // Seed test attachment for UI test coverage
        seedTestAttachmentIfNeeded()
    }

    // MARK: - Test Support

    /// Seeds a synthetic test attachment when running UI tests with seeding enabled
    /// This ensures attachment-related Views are exercised for code coverage
    private func seedTestAttachmentIfNeeded() {
        guard UITestingHelpers.shouldSeedTestAttachments else { return }
        guard attachments.isEmpty else { return } // Only seed if empty

        let testData = UITestingHelpers.createTestAttachmentData()

        do {
            let attachment = try Attachment(
                id: testData.id,
                fileName: testData.fileName,
                mimeType: testData.mimeType,
                contentHMAC: Data(repeating: 0xAB, count: 32), // Synthetic HMAC
                encryptedSize: testData.thumbnailData.count,
                thumbnailData: testData.thumbnailData,
                uploadedAt: Date()
            )
            attachments.append(attachment)
            logger.debug("Seeded test attachment for UI coverage testing")
        } catch {
            logger.logError(error, context: "seedTestAttachmentIfNeeded")
        }
    }

    // MARK: - Actions

    /// Add attachment from camera capture
    ///
    /// - Parameter image: The captured UIImage
    func addFromCamera(_ image: UIImage) async {
        guard canAddMore else {
            errorMessage = ModelError.attachmentLimitExceeded(max: Self.maxAttachments).userFacingMessage
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            guard let imageData = image.jpegData(compressionQuality: 0.9) else {
                throw ModelError.imageProcessingFailed(reason: "Could not convert image to JPEG")
            }

            let fileName = "Photo_\(formatTimestamp()).jpg"
            let attachment = try await addAttachmentData(
                data: imageData,
                fileName: fileName,
                mimeType: "image/jpeg"
            )

            attachments.append(attachment)
        } catch let error as ModelError {
            errorMessage = error.userFacingMessage
            logger.logError(error, context: "AttachmentPickerViewModel.addFromCamera")
        } catch {
            errorMessage = "Unable to add photo. Please try again."
            logger.logError(error, context: "AttachmentPickerViewModel.addFromCamera")
        }

        isLoading = false
    }

    /// Add attachments from photo library selection
    ///
    /// - Parameter items: Selected PhotosPickerItem array
    func addFromPhotoLibrary(_ items: [PhotosPickerItem]) async {
        isLoading = true
        errorMessage = nil

        for item in items {
            guard canAddMore else {
                errorMessage = ModelError.attachmentLimitExceeded(max: Self.maxAttachments).userFacingMessage
                break
            }

            do {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    logger.info("Skipping item - could not load data")
                    continue
                }

                // Determine MIME type from data
                let mimeType = detectMimeType(from: data)
                let fileName = "Photo_\(formatTimestamp()).\(fileExtension(for: mimeType))"

                let attachment = try await addAttachmentData(
                    data: data,
                    fileName: fileName,
                    mimeType: mimeType
                )

                attachments.append(attachment)
            } catch let error as ModelError {
                errorMessage = error.userFacingMessage
                logger.logError(error, context: "AttachmentPickerViewModel.addFromPhotoLibrary")
            } catch {
                logger.logError(error, context: "AttachmentPickerViewModel.addFromPhotoLibrary")
            }
        }

        isLoading = false
    }

    /// Add attachment from document picker
    ///
    /// - Parameter urls: Selected file URLs
    func addFromDocumentPicker(_ urls: [URL]) async {
        isLoading = true
        errorMessage = nil

        for url in urls {
            guard canAddMore else {
                errorMessage = ModelError.attachmentLimitExceeded(max: Self.maxAttachments).userFacingMessage
                break
            }

            do {
                // Start accessing security-scoped resource
                guard url.startAccessingSecurityScopedResource() else {
                    throw ModelError.attachmentStorageFailed(reason: "Cannot access selected file")
                }
                defer { url.stopAccessingSecurityScopedResource() }

                let data = try Data(contentsOf: url)
                let fileName = url.lastPathComponent
                let mimeType = mimeType(for: url)

                let attachment = try await addAttachmentData(
                    data: data,
                    fileName: fileName,
                    mimeType: mimeType
                )

                attachments.append(attachment)
            } catch let error as ModelError {
                errorMessage = error.userFacingMessage
                logger.logError(error, context: "AttachmentPickerViewModel.addFromDocumentPicker")
            } catch {
                errorMessage = "Unable to add document. Please try again."
                logger.logError(error, context: "AttachmentPickerViewModel.addFromDocumentPicker")
            }
        }

        isLoading = false
    }

    /// Remove an attachment
    ///
    /// - Parameter attachment: The attachment to remove
    func removeAttachment(_ attachment: Attachment) async {
        isLoading = true
        errorMessage = nil

        do {
            // If we have a record ID, also delete from repository
            if let recordId {
                let primaryKey = try primaryKeyProvider.getPrimaryKey()
                try await attachmentService.deleteAttachmentWithCleanup(
                    attachmentId: attachment.id,
                    recordId: recordId,
                    personId: personId,
                    primaryKey: primaryKey
                )
            }

            // Remove from local list
            attachments.removeAll { $0.id == attachment.id }
        } catch {
            errorMessage = "Unable to remove attachment. Please try again."
            logger.logError(error, context: "AttachmentPickerViewModel.removeAttachment")
        }

        isLoading = false
    }

    /// Get attachment IDs for storage in record content
    var attachmentIds: [UUID] {
        attachments.map(\.id)
    }

    // MARK: - Private Helpers

    /// Add attachment data through the service
    private func addAttachmentData(
        data: Data,
        fileName: String,
        mimeType: String
    ) async throws -> Attachment {
        let primaryKey = try primaryKeyProvider.getPrimaryKey()

        // For new records (no recordId), we need a temporary ID
        // The actual linking happens when the record is saved
        let targetRecordId = recordId ?? UUID()

        let input = AddAttachmentInput(
            data: data,
            fileName: fileName,
            mimeType: mimeType,
            recordId: targetRecordId,
            personId: personId,
            primaryKey: primaryKey
        )
        return try await attachmentService.addAttachment(input)
    }

    /// Format current timestamp for file naming
    private func formatTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: Date())
    }

    /// Detect MIME type from image data magic bytes
    private func detectMimeType(from data: Data) -> String {
        guard data.count >= 8 else {
            return "application/octet-stream"
        }

        let bytes = [UInt8](data.prefix(8))

        // PNG: 89 50 4E 47 0D 0A 1A 0A
        if bytes[0] == 0x89, bytes[1] == 0x50, bytes[2] == 0x4E, bytes[3] == 0x47 {
            return "image/png"
        }

        // JPEG: FF D8 FF
        if bytes[0] == 0xFF, bytes[1] == 0xD8, bytes[2] == 0xFF {
            return "image/jpeg"
        }

        // PDF: 25 50 44 46 (%PDF)
        if bytes[0] == 0x25, bytes[1] == 0x50, bytes[2] == 0x44, bytes[3] == 0x46 {
            return "application/pdf"
        }

        return "application/octet-stream"
    }

    /// Get file extension for MIME type
    private func fileExtension(for mimeType: String) -> String {
        switch mimeType {
        case "image/jpeg": "jpg"
        case "image/png": "png"
        case "application/pdf": "pdf"
        default: "bin"
        }
    }

    /// Get MIME type from file URL
    private func mimeType(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "jpeg", "jpg": return "image/jpeg"
        case "png": return "image/png"
        case "pdf": return "application/pdf"
        default: return "application/octet-stream"
        }
    }

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

        // Create file storage (may fail if directory can't be created)
        let fileStorage: AttachmentFileStorageServiceProtocol
        do {
            fileStorage = try AttachmentFileStorageService()
        } catch {
            // Fallback: create with temp directory (will be recreated on next launch)
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

// MARK: - AttachmentService Extension Access

extension AttachmentServiceProtocol {
    /// Delete with cleanup - calls extended method if available
    func deleteAttachmentWithCleanup(
        attachmentId: UUID,
        recordId: UUID,
        personId: UUID,
        primaryKey: SymmetricKey
    ) async throws {
        // Check if we have the extended implementation
        if let service = self as? AttachmentService {
            try await service.deleteAttachmentWithCleanup(
                attachmentId: attachmentId,
                recordId: recordId,
                personId: personId,
                primaryKey: primaryKey
            )
        } else {
            // Fallback to basic delete
            try await deleteAttachment(attachmentId: attachmentId, recordId: recordId)
        }
    }
}
