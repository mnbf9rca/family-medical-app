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
        self.blobService = blobService ?? Self.createDefaultBlobService()
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
            guard let imageData = image.jpegData(compressionQuality: 0.9) else {
                throw ModelError.imageProcessingFailed(reason: "Could not convert image to JPEG")
            }
            let fileName = "Photo_\(Self.formatTimestamp(dateProvider())).jpg"
            try await storeAndAppend(plaintext: imageData, fileName: fileName, mimeType: "image/jpeg")
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
            let mimeType = Self.detectMimeType(from: data)
            let fileName = "Photo_\(Self.formatTimestamp(dateProvider())).\(Self.fileExtension(for: mimeType))"
            try await storeAndAppend(plaintext: data, fileName: fileName, mimeType: mimeType)
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

    private func storeAndAppend(plaintext: Data, fileName: String, mimeType: String) async throws {
        let stored = try await blobService.store(
            plaintext: plaintext,
            mimeType: mimeType,
            personId: personId,
            primaryKey: primaryKey
        )
        let doc = DocumentReferenceRecord(
            title: fileName,
            documentType: nil,
            mimeType: mimeType,
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

    private static func detectMimeType(from data: Data) -> String {
        guard data.count >= 8 else { return "application/octet-stream" }
        let bytes = [UInt8](data.prefix(8))
        if bytes[0] == 0x89, bytes[1] == 0x50, bytes[2] == 0x4E, bytes[3] == 0x47 {
            return "image/png"
        }
        if bytes[0] == 0xFF, bytes[1] == 0xD8, bytes[2] == 0xFF {
            return "image/jpeg"
        }
        if bytes[0] == 0x25, bytes[1] == 0x50, bytes[2] == 0x44, bytes[3] == 0x46 {
            return "application/pdf"
        }
        return "application/octet-stream"
    }

    private static func fileExtension(for mimeType: String) -> String {
        switch mimeType {
        case "image/jpeg": "jpg"
        case "image/png": "png"
        case "application/pdf": "pdf"
        default: "bin"
        }
    }

    private static func mimeType(forPathExtension ext: String) -> String {
        switch ext.lowercased() {
        case "jpeg", "jpg": "image/jpeg"
        case "png": "image/png"
        case "pdf": "application/pdf"
        default: "application/octet-stream"
        }
    }

    // MARK: - Default Blob Service Factory

    private static func createDefaultBlobService() -> DocumentBlobServiceProtocol {
        let fileStorage: DocumentFileStorageServiceProtocol
        do {
            fileStorage = try DocumentFileStorageService()
        } catch {
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("Attachments")
            try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            fileStorage = DocumentFileStorageService(attachmentsDirectory: tempDir)
        }
        return DocumentBlobService(
            fileStorage: fileStorage,
            imageProcessor: ImageProcessingService(),
            encryptionService: EncryptionService(),
            fmkService: FamilyMemberKeyService()
        )
    }
}
