import CryptoKit
import Foundation
import Observation
import PhotosUI
import SwiftUI
import UIKit

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

    // MARK: - Types

    /// How to derive the title of a draft relative to the detected MIME of the blob.
    private enum TitleStrategy {
        /// Use this literal string as the title regardless of detected MIME. For the
        /// URL document-picker path, where the user already picked a real filename.
        case verbatim(String)
        /// Append the canonical extension for the detected MIME to this base. For the
        /// camera and photo-library paths, where the filename is generated.
        case derived(baseName: String)
    }

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
            try await storeAndAppend(plaintext: imageData, title: .derived(baseName: baseName))
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

    /// Remove a draft. Clears in-flight tracking so the orphan cleanup scan can
    /// reclaim the speculative blob on its next pass. Blob deletion for already-
    /// saved attachments happens via the delete flow instead.
    ///
    /// The clearInFlight call is dispatched asynchronously from a fire-and-forget
    /// Task, so a cleanup scan that runs between `removeDraft` and the clear landing
    /// will still skip the blob on that pass. This is self-healing: the very next
    /// scan will see the HMAC is no longer in-flight and reclaim it.
    func removeDraft(id: UUID) {
        guard let index = drafts.firstIndex(where: { $0.id == id }) else { return }
        let hmac = drafts[index].content.contentHMAC
        drafts.remove(at: index)
        // Fire-and-forget: removeDraft is called from the UI and shouldn't become
        // async just for this side effect. Tests await briefly to observe the clear.
        Task {
            await blobService.clearInFlight(contentHMAC: hmac)
        }
    }

    /// Clear in-flight tracking for a draft's blob after its record has been saved.
    /// Exposed so `GenericRecordFormViewModel` can release in-flight state after
    /// persisting each attachment record, without reaching into the blob service
    /// directly.
    ///
    /// Do NOT call this on form cancellation or save failure — use `removeDraft`
    /// instead, which preserves retry semantics by keeping the blob on disk for a
    /// subsequent save attempt. Calling `clearInFlightForDraft` without having
    /// persisted the referencing record leaves the blob unprotected against the
    /// next cleanup scan.
    func clearInFlightForDraft(contentHMAC: Data) async {
        await blobService.clearInFlight(contentHMAC: contentHMAC)
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
            try await storeAndAppend(plaintext: data, title: .derived(baseName: baseName))
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
            try await storeAndAppend(plaintext: data, title: .verbatim(url.lastPathComponent))
        } catch let error as ModelError {
            errorMessage = error.userFacingMessage
            logger.logError(error, context: "DocumentPickerViewModel.addFromDocumentPicker")
        } catch {
            errorMessage = "Unable to add document. Please try again."
            logger.logError(error, context: "DocumentPickerViewModel.addFromDocumentPicker")
        }
    }

    private func storeAndAppend(plaintext: Data, title: TitleStrategy) async throws {
        // `store` atomically marks the resulting HMAC as in-flight on the blob actor,
        // so the orphan cleanup scanner cannot observe the on-disk blob without also
        // observing the in-flight bit. The in-flight state is released on successful
        // record save (via `clearInFlightForDraft`) or on draft removal.
        let stored = try await blobService.store(
            plaintext: plaintext,
            personId: personId,
            primaryKey: primaryKey
        )
        let finalTitle: String = switch title {
        case let .verbatim(name):
            name
        case let .derived(baseName):
            baseName.appendingCanonicalExtension(forMimeType: stored.detectedMimeType, fallback: nil)
        }
        let doc = DocumentReferenceRecord(
            title: finalTitle,
            documentType: nil,
            mimeType: stored.detectedMimeType,
            fileSize: plaintext.count,
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
}
