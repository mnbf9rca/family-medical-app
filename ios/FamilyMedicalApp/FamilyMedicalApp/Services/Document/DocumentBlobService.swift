import CryptoKit
import Foundation
import PDFKit

/// Storage of encrypted document blobs on disk, keyed by HMAC-SHA256 of plaintext (keyed with FMK).
///
/// Per ADR-0004: blobs live separately from record metadata so that syncing a text-field edit does
/// not re-upload the blob. HMAC keying with the Family Member Key prevents rainbow-table attacks
/// on known content.
protocol DocumentBlobServiceProtocol: Sendable {
    /// Encrypt, store, and return storage metadata for a plaintext blob. The content type
    /// is detected from the bytes themselves (PDF via `%PDF-` magic bytes, images via
    /// CGImageSource); callers do not pass a MIME hint.
    ///
    /// Stored blobs are automatically marked in-flight as part of the same actor-isolated
    /// body that writes the blob to disk — no interleaving window exists where the orphan
    /// cleanup scanner could observe the on-disk blob without also observing the in-flight
    /// bit. Callers must `clearInFlight` after the referencing record is saved, or
    /// `clearInFlight` (typically via `removeDraft`) when the draft is discarded, otherwise
    /// the cleanup scanner will perpetually skip the blob for the process lifetime.
    func store(
        plaintext: Data,
        personId: UUID,
        primaryKey: SymmetricKey
    ) async throws -> DocumentBlobService.StoredBlob

    /// Fetch and decrypt a previously stored blob.
    func retrieve(
        contentHMAC: Data,
        personId: UUID,
        primaryKey: SymmetricKey
    ) async throws -> Data

    /// Delete a blob from disk if no DocumentReferenceRecord still references it.
    /// Callers determine `isReferencedElsewhere` by querying DocumentReferenceQueryService.
    ///
    /// - Parameters:
    ///   - contentHMAC: The HMAC of the blob to potentially delete.
    ///   - personId: The person whose subdirectory holds the blob. Required so the
    ///     underlying file-storage service can locate the per-person `.enc` file.
    ///   - isReferencedElsewhere: If `true`, the blob is preserved (another record still
    ///     points at this HMAC).
    func deleteIfUnreferenced(contentHMAC: Data, personId: UUID, isReferencedElsewhere: Bool) async throws

    // MARK: - Cleanup Support

    /// List every blob HMAC currently on disk for a person.
    /// Used by the orphan cleanup scanner to compare against the set of
    /// referenced HMACs from the database.
    func listBlobs(personId: UUID) async throws -> Set<Data>

    /// Return the on-disk size of a specific blob in bytes.
    func blobSize(contentHMAC: Data, personId: UUID) async throws -> UInt64

    /// Delete a blob unconditionally (no reference check). Used by the cleanup
    /// scanner, which has already determined the blob is an orphan.
    func deleteDirect(contentHMAC: Data, personId: UUID) async throws

    // MARK: - In-Flight Tracking

    /// Mark a content HMAC as "currently being written" so the cleanup scanner
    /// does not delete it as an orphan during the gap between blob storage
    /// and Core Data commit.
    ///
    /// The common `store`-then-save flow does NOT need to call this: `store` marks
    /// its output HMAC in-flight as part of the same actor-serialized body that
    /// writes the blob. This entry point is retained for external callers (mocks,
    /// import flows, future features) that want to mark an HMAC without first
    /// calling `store`.
    func markInFlight(contentHMAC: Data) async

    /// Clear a previously marked in-flight HMAC (on commit or rollback).
    func clearInFlight(contentHMAC: Data) async

    /// Check whether an HMAC is currently marked as in-flight.
    func isInFlight(contentHMAC: Data) async -> Bool
}

actor DocumentBlobService: DocumentBlobServiceProtocol {
    // MARK: - Constants

    /// Maximum accepted plaintext size for a single document blob: 10 MB.
    ///
    /// Enforced at `store(plaintext:personId:primaryKey:)`; exceeding this
    /// surfaces to callers (and ultimately the UI) as
    /// `ModelError.documentTooLarge(maxSizeMB:)`.
    ///
    /// Rationale: bounds the in-memory cost of encrypting blobs and generating
    /// thumbnails, and keeps the on-disk footprint and eventual sync-payload size
    /// tractable. No ADR pins this value; it is a pragmatic cap that should be
    /// revisited when sync lands and real-world payload distributions are known.
    static let maxFileSizeBytes = 10 * 1_024 * 1_024

    /// Target maximum edge length of generated thumbnails: 200 px.
    ///
    /// This value is passed to image resizing as a pixel dimension. The thumbnail
    /// renderer uses a fixed scale of 1.0 (see ImageProcessingService.resizeIfNeeded),
    /// so the stored bitmap's maximum edge length matches this value rather than
    /// being multiplied by the device display scale. Sized for list-row thumbnails
    /// where low decode cost matters more than full-fidelity rendering.
    static let thumbnailDimension = 200

    // MARK: - Types

    // swiftformat:disable redundantSendable
    /// Explicit Sendable to prevent silent regression if fields change — auto-inference is fragile under future edits.
    struct StoredBlob: Equatable, Sendable {
        let contentHMAC: Data
        let encryptedSize: Int
        let thumbnailData: Data?
        let detectedMimeType: String
    }

    // swiftformat:enable redundantSendable

    /// Result of `process()`: the data to store, optional thumbnail, and detected MIME.
    private struct ProcessedBlob {
        let data: Data
        let thumbnailData: Data?
        let detectedMimeType: String
    }

    // MARK: - Dependencies

    private let fileStorage: DocumentFileStorageServiceProtocol
    private let imageProcessor: ImageProcessingServiceProtocol
    private let encryptionService: EncryptionServiceProtocol
    private let fmkService: FamilyMemberKeyServiceProtocol
    private let logger: TracingCategoryLogger

    // MARK: - In-Flight State

    /// HMACs that have been speculatively written to disk but not yet committed
    /// to Core Data. Cleared on commit or rollback. Process-local: a crash mid-flight
    /// is safe because the blob either already landed on disk (benign orphan the
    /// next cleanup scan will remove) or never did.
    private var inFlightHMACs: Set<Data> = []

    init(
        fileStorage: DocumentFileStorageServiceProtocol,
        imageProcessor: ImageProcessingServiceProtocol,
        encryptionService: EncryptionServiceProtocol,
        fmkService: FamilyMemberKeyServiceProtocol,
        logger: CategoryLoggerProtocol? = nil
    ) {
        self.fileStorage = fileStorage
        self.imageProcessor = imageProcessor
        self.encryptionService = encryptionService
        self.fmkService = fmkService
        self.logger = TracingCategoryLogger(
            wrapping: logger ?? LoggingService.shared.logger(category: .storage)
        )
    }

    // MARK: - DocumentBlobServiceProtocol

    func store(
        plaintext: Data,
        personId: UUID,
        primaryKey: SymmetricKey
    ) async throws -> StoredBlob {
        let start = ContinuousClock.now
        // Emit entry *before* any fallible work so every error path has a matching
        // `exitWithError`. Details that depend on downstream results (detected MIME,
        // processed size) are logged later via a regular debug line.
        logger.entry("store", "personId=\(personId), plaintextSize=\(plaintext.count)")
        do {
            let fmk = try fmkService.retrieveFMK(personId: personId.uuidString, primaryKey: primaryKey)
            let processed = try process(plaintext: plaintext)
            logger.debug("store detectedMime=\(processed.detectedMimeType), processedSize=\(processed.data.count)")
            let hmac = Data(HMAC<SHA256>.authenticationCode(for: processed.data, using: fmk))

            let encryptedSize: Int
            if fileStorage.exists(contentHMAC: hmac, personId: personId) {
                // Dedup: blob already on disk — skip re-encryption and re-write.
                // Return 0 as placeholder since we don't know the encrypted size without reading the file.
                encryptedSize = 0
            } else {
                let encrypted = try encryptionService.encrypt(processed.data, using: fmk).combined
                _ = try fileStorage.store(encryptedData: encrypted, contentHMAC: hmac, personId: personId)
                encryptedSize = encrypted.count
            }
            // Atomically mark the HMAC in-flight inside this same actor-isolated method
            // body, before returning. Because the insert and the file-storage write are
            // both serialized on this actor, no cleanup scanner can observe the on-disk
            // blob without also observing the in-flight bit — closing the race where a
            // scan would otherwise delete a just-stored blob before the caller's record
            // save could reference it.
            inFlightHMACs.insert(hmac)
            logger.exit("store", duration: ContinuousClock.now - start)
            return StoredBlob(
                contentHMAC: hmac,
                encryptedSize: encryptedSize,
                thumbnailData: processed.thumbnailData,
                detectedMimeType: processed.detectedMimeType
            )
        } catch {
            logger.exitWithError("store", error: error, duration: ContinuousClock.now - start)
            throw error
        }
    }

    func retrieve(
        contentHMAC: Data,
        personId: UUID,
        primaryKey: SymmetricKey
    ) async throws -> Data {
        let start = ContinuousClock.now
        logger.entry("retrieve", "personId=\(personId)")
        do {
            let fmk = try fmkService.retrieveFMK(personId: personId.uuidString, primaryKey: primaryKey)
            let encrypted = try fileStorage.retrieve(contentHMAC: contentHMAC, personId: personId)
            let plaintext: Data
            do {
                let payload = try EncryptedPayload(combined: encrypted)
                plaintext = try encryptionService.decrypt(payload, using: fmk)
            } catch {
                logger.logError(error, context: "DocumentBlobService.retrieve.decrypt")
                throw ModelError.documentContentCorrupted
            }
            logger.exit("retrieve", duration: ContinuousClock.now - start)
            return plaintext
        } catch {
            logger.exitWithError("retrieve", error: error, duration: ContinuousClock.now - start)
            throw error
        }
    }

    func deleteIfUnreferenced(contentHMAC: Data, personId: UUID, isReferencedElsewhere: Bool) async throws {
        let start = ContinuousClock.now
        logger.entry("deleteIfUnreferenced", "personId=\(personId), referenced=\(isReferencedElsewhere)")
        guard !isReferencedElsewhere else {
            logger.exit("deleteIfUnreferenced", duration: ContinuousClock.now - start)
            return
        }
        do {
            try fileStorage.delete(contentHMAC: contentHMAC, personId: personId)
            logger.exit("deleteIfUnreferenced", duration: ContinuousClock.now - start)
        } catch {
            logger.exitWithError("deleteIfUnreferenced", error: error, duration: ContinuousClock.now - start)
            throw error
        }
    }

    // MARK: - Cleanup Support

    func listBlobs(personId: UUID) async throws -> Set<Data> {
        let start = ContinuousClock.now
        logger.entry("listBlobs", "personId=\(personId)")
        do {
            let blobs = try fileStorage.listBlobs(personId: personId)
            logger.debug("listBlobs returned \(blobs.count) blobs")
            logger.exit("listBlobs", duration: ContinuousClock.now - start)
            return blobs
        } catch {
            logger.exitWithError("listBlobs", error: error, duration: ContinuousClock.now - start)
            throw error
        }
    }

    func blobSize(contentHMAC: Data, personId: UUID) async throws -> UInt64 {
        let start = ContinuousClock.now
        logger.entry("blobSize", "personId=\(personId)")
        do {
            let size = try fileStorage.blobSize(contentHMAC: contentHMAC, personId: personId)
            logger.exit("blobSize", duration: ContinuousClock.now - start)
            return size
        } catch {
            logger.exitWithError("blobSize", error: error, duration: ContinuousClock.now - start)
            throw error
        }
    }

    func deleteDirect(contentHMAC: Data, personId: UUID) async throws {
        let start = ContinuousClock.now
        logger.entry("deleteDirect", "personId=\(personId)")
        do {
            try fileStorage.delete(contentHMAC: contentHMAC, personId: personId)
            logger.exit("deleteDirect", duration: ContinuousClock.now - start)
        } catch {
            logger.exitWithError("deleteDirect", error: error, duration: ContinuousClock.now - start)
            throw error
        }
    }

    // MARK: - In-Flight Tracking

    func markInFlight(contentHMAC: Data) {
        let (inserted, _) = inFlightHMACs.insert(contentHMAC)
        if !inserted {
            logger.debug("markInFlight: HMAC already in flight, count=\(inFlightHMACs.count)")
        } else {
            logger.debug("markInFlight: added, count=\(inFlightHMACs.count)")
        }
    }

    func clearInFlight(contentHMAC: Data) {
        if inFlightHMACs.remove(contentHMAC) == nil {
            logger.debug("clearInFlight: HMAC not in flight, count=\(inFlightHMACs.count)")
        } else {
            logger.debug("clearInFlight: removed, count=\(inFlightHMACs.count)")
        }
    }

    /// No debug log on isInFlight: called per-blob in cleanup scans, would flood logs.
    func isInFlight(contentHMAC: Data) -> Bool {
        inFlightHMACs.contains(contentHMAC)
    }

    // MARK: - Factory

    /// Shared default factory for production use. Replaces copy-pasted
    /// `createDefaultBlobService()` helpers in individual ViewModels.
    static func makeDefault() -> DocumentBlobServiceProtocol {
        let fileStorage: DocumentFileStorageServiceProtocol
        do {
            fileStorage = try DocumentFileStorageService()
        } catch {
            fatalError("Failed to create DocumentFileStorageService: \(error)")
        }
        return DocumentBlobService(
            fileStorage: fileStorage,
            imageProcessor: ImageProcessingService(),
            encryptionService: EncryptionService(),
            fmkService: FamilyMemberKeyService()
        )
    }

    // MARK: - Private

    /// Detect content type from the bytes and process accordingly.
    ///
    /// - PDFs: detected by `%PDF-` magic bytes, then validated via `PDFDocument(data:)`,
    ///   stored as-is with no thumbnail.
    /// - Images: detected via CGImageSource, original bytes stored as-is, JPEG thumbnail generated.
    /// - Everything else: rejected.
    ///
    /// PDF is checked before images because CGImageSource also accepts PDF data and would
    /// otherwise mis-route PDFs into the image path.
    private func process(plaintext: Data) throws -> ProcessedBlob {
        guard plaintext.count <= Self.maxFileSizeBytes else {
            throw ModelError.documentTooLarge(maxSizeMB: Self.maxFileSizeBytes / (1_024 * 1_024))
        }
        if Self.isPDFContent(plaintext) {
            guard PDFDocument(data: plaintext) != nil else {
                throw ModelError.imageProcessingFailed(reason: "File content is not a valid PDF")
            }
            return ProcessedBlob(data: plaintext, thumbnailData: nil, detectedMimeType: "application/pdf")
        }
        // Single CGImageSource pass: validateImage is the only image probe.
        // Failures here mean the bytes are neither a recognized image format
        // nor a recognizable container — re-throw as unsupportedContent so the
        // error type matches the post-PDF "not a known content type" branch.
        let detectedMime: String
        do {
            detectedMime = try imageProcessor.validateImage(plaintext)
        } catch {
            logger.debug("validateImage rejected bytes: \(error)")
            throw ModelError.unsupportedContent
        }
        let thumbnail = try imageProcessor.generateThumbnail(
            plaintext,
            maxDimension: Self.thumbnailDimension
        )
        return ProcessedBlob(data: plaintext, thumbnailData: thumbnail, detectedMimeType: detectedMime)
    }

    /// PDF files begin with `%PDF-` (25 50 44 46 2D). Cheap byte-prefix check so we can
    /// avoid the heavier `PDFDocument(data:)` parse for non-PDF inputs.
    private static func isPDFContent(_ data: Data) -> Bool {
        let magic: [UInt8] = [0x25, 0x50, 0x44, 0x46, 0x2D]
        guard data.count >= magic.count else { return false }
        return data.prefix(magic.count).elementsEqual(magic)
    }
}
