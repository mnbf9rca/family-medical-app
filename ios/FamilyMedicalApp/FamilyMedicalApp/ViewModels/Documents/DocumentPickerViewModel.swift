import CryptoKit
import Foundation
import Observation
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// ViewModel for selecting and managing DocumentReferenceRecord drafts in a medical record form.
///
/// The picker maintains an in-memory list of drafts produced from camera, photo-library, or
/// document-picker input. Each draft wraps a `DocumentReferenceRecord` whose `contentHMAC` points
/// at an encrypted blob stored via `DocumentBlobService`. The parent form reads
/// `allDocumentReferences` at save time and persists the records itself.
@MainActor
@Observable
final class DocumentPickerViewModel {
    // MARK: - Types

    /// A draft attachment — a DocumentReferenceRecord that has been blob-stored but whose
    /// metadata has not yet been committed into the record stream.
    struct Draft: Identifiable {
        let id: UUID
        var content: DocumentReferenceRecord
    }

    // MARK: - State

    /// Drafts collected by the picker during this editing session.
    var drafts: [Draft] = []

    /// Loading state for async operations.
    var isLoading = false

    /// Error message for display.
    var errorMessage: String?

    /// Whether camera sheet should be shown.
    var showingCamera = false

    /// Whether photo library picker should be shown.
    var showingPhotoLibrary = false

    /// Whether document picker should be shown.
    var showingDocumentPicker = false

    // MARK: - Context

    /// The person this record belongs to.
    let personId: UUID

    /// The parent MedicalRecord.id these attachments will be linked to, nil if standalone.
    let sourceRecordId: UUID?

    /// The primary key used to derive the FMK inside the blob service.
    @ObservationIgnored private let primaryKey: SymmetricKey

    // MARK: - Constants

    /// Maximum drafts per record.
    static let maxPerRecord: Int = 5

    /// Sentinel MIME hint passed to `DocumentBlobService.store` when the caller has not
    /// sniffed the bytes yet. The service runs `CGImageSource` detection regardless of
    /// the hint and returns the real MIME as `stored.detectedMimeType` — this string is
    /// only a marker meaning "I don't know, please detect."
    private static let unknownMimeHint = "image/unknown"

    // MARK: - Dependencies

    @ObservationIgnored private let blobService: DocumentBlobServiceProtocol
    @ObservationIgnored private let logger: TracingCategoryLogger
    @ObservationIgnored private let dateProvider: @Sendable () -> Date
    @ObservationIgnored private let uuidProvider: @Sendable () -> UUID

    // MARK: - Computed Properties

    var canAddMore: Bool {
        drafts.count < Self.maxPerRecord
    }

    var remainingSlots: Int {
        max(0, Self.maxPerRecord - drafts.count)
    }

    var countSummary: String {
        "\(drafts.count) of \(Self.maxPerRecord) attachments"
    }

    /// The DocumentReferenceRecord values inside each draft, in display order.
    var allDocumentReferences: [DocumentReferenceRecord] {
        drafts.map(\.content)
    }

    // MARK: - Initialization

    init(
        personId: UUID,
        sourceRecordId: UUID?,
        primaryKey: SymmetricKey,
        existing: [DocumentReferenceRecord] = [],
        blobService: DocumentBlobServiceProtocol? = nil,
        logger: CategoryLoggerProtocol? = nil,
        dateProvider: (@Sendable () -> Date)? = nil,
        uuidProvider: (@Sendable () -> UUID)? = nil
    ) {
        self.personId = personId
        self.sourceRecordId = sourceRecordId
        self.primaryKey = primaryKey
        self.blobService = blobService ?? DocumentBlobService.makeDefault()
        self.logger = TracingCategoryLogger(
            wrapping: logger ?? LoggingService.shared.logger(category: .storage)
        )
        self.dateProvider = dateProvider ?? { Date() }
        self.uuidProvider = uuidProvider ?? { UUID() }
        self.drafts = existing.map { Draft(id: self.uuidProvider(), content: $0) }
    }

    // MARK: - Actions

    /// Add a draft from a camera-captured image.
    func addFromCamera(_ image: UIImage) async {
        guard canAddMore else {
            errorMessage = ModelError.documentLimitExceeded(max: Self.maxPerRecord).userFacingMessage
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            // UIImagePickerController hands us an already-decoded UIImage, so the camera's
            // original encoded bytes are not recoverable here; we re-encode to JPEG.
            // See Issue #160 for the AVCapturePhotoOutput rework that would lift this.
            guard let imageData = image.jpegData(compressionQuality: 0.9) else {
                throw ModelError.imageProcessingFailed(reason: "Could not convert image to JPEG")
            }
            let baseName = "Photo_\(Self.formatTimestamp(dateProvider()))"
            try await storeAndAppendGenerated(plaintext: imageData, baseName: baseName, mimeType: "image/jpeg")
        } catch let error as ModelError {
            errorMessage = error.userFacingMessage
            logger.logError(error, context: "DocumentPickerViewModel.addFromCamera")
        } catch {
            errorMessage = "Unable to add photo. Please try again."
            logger.logError(error, context: "DocumentPickerViewModel.addFromCamera")
        }
        isLoading = false
    }

    /// Add drafts from photo-library selection.
    func addFromPhotoLibrary(_ items: [PhotosPickerItem]) async {
        isLoading = true
        errorMessage = nil
        for item in items {
            guard canAddMore else {
                errorMessage = ModelError.documentLimitExceeded(max: Self.maxPerRecord).userFacingMessage
                break
            }
            await loadAndAppendPhotoItem(item)
        }
        isLoading = false
    }

    /// Add drafts from document-picker URLs.
    func addFromDocumentPicker(_ urls: [URL]) async {
        isLoading = true
        errorMessage = nil
        for url in urls {
            guard canAddMore else {
                errorMessage = ModelError.documentLimitExceeded(max: Self.maxPerRecord).userFacingMessage
                break
            }
            await loadAndAppendURL(url)
        }
        isLoading = false
    }

    /// Remove a draft. Blob orphan cleanup happens via the delete flow later.
    func removeDraft(id: UUID) {
        drafts.removeAll { $0.id == id }
    }

    /// Update a draft's title.
    func setTitle(_ title: String, for draftId: UUID) {
        guard let index = drafts.firstIndex(where: { $0.id == draftId }) else { return }
        drafts[index].content.title = title
    }

    // MARK: - Private Helpers

    private func loadAndAppendPhotoItem(_ item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                logger.info("Skipping photo item - could not load data")
                return
            }
            let baseName = "Photo_\(Self.formatTimestamp(dateProvider()))"
            try await storeAndAppendGenerated(plaintext: data, baseName: baseName, mimeType: Self.unknownMimeHint)
        } catch let error as ModelError {
            errorMessage = error.userFacingMessage
            logger.logError(error, context: "DocumentPickerViewModel.addFromPhotoLibrary")
        } catch {
            logger.logError(error, context: "DocumentPickerViewModel.addFromPhotoLibrary")
        }
    }

    private func loadAndAppendURL(_ url: URL) async {
        do {
            let didAccess = url.startAccessingSecurityScopedResource()
            defer {
                if didAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            let data = try Data(contentsOf: url)
            let fileName = url.lastPathComponent
            let mimeType = Self.mimeType(forPathExtension: url.pathExtension)
            try await storeAndAppend(plaintext: data, fileName: fileName, mimeType: mimeType)
        } catch let error as ModelError {
            errorMessage = error.userFacingMessage
            logger.logError(error, context: "DocumentPickerViewModel.addFromDocumentPicker")
        } catch {
            errorMessage = "Unable to add document. Please try again."
            logger.logError(error, context: "DocumentPickerViewModel.addFromDocumentPicker")
        }
    }

    /// URL document-picker path — uses the user's chosen filename verbatim.
    private func storeAndAppend(plaintext: Data, fileName: String, mimeType: String) async throws {
        let stored = try await blobService.store(
            plaintext: plaintext,
            mimeType: mimeType,
            personId: personId,
            primaryKey: primaryKey
        )
        appendDraft(stored: stored, fileSize: plaintext.count, title: fileName)
    }

    /// Camera and photo-library paths — synthesizes the title from `baseName` plus the
    /// canonical extension for the MIME that `DocumentBlobService` detected, so the title
    /// agrees with the actually-stored bytes instead of whatever the caller guessed.
    private func storeAndAppendGenerated(plaintext: Data, baseName: String, mimeType: String) async throws {
        let stored = try await blobService.store(
            plaintext: plaintext,
            mimeType: mimeType,
            personId: personId,
            primaryKey: primaryKey
        )
        let title = baseName.appendingCanonicalExtension(
            forMimeType: stored.detectedMimeType,
            fallback: nil
        )
        appendDraft(stored: stored, fileSize: plaintext.count, title: title)
    }

    private func appendDraft(
        stored: DocumentBlobService.StoredBlob,
        fileSize: Int,
        title: String
    ) {
        let doc = DocumentReferenceRecord(
            title: title,
            documentType: nil,
            mimeType: stored.detectedMimeType,
            fileSize: fileSize,
            contentHMAC: stored.contentHMAC,
            thumbnailData: stored.thumbnailData,
            sourceRecordId: sourceRecordId,
            notes: nil,
            tags: []
        )
        drafts.append(Draft(id: uuidProvider(), content: doc))
    }

    // MARK: - Static Helpers

    private static func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter.string(from: date)
    }

    private static func mimeType(forPathExtension ext: String) -> String {
        UTType(filenameExtension: ext)?.preferredMIMEType ?? "application/octet-stream"
    }
}
