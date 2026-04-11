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
    func deleteIfUnreferenced(contentHMAC: Data, isReferencedElsewhere: Bool) async throws
}

final class DocumentBlobService: DocumentBlobServiceProtocol, @unchecked Sendable {
    // MARK: - Constants

    static let maxFileSizeBytes = 10 * 1_024 * 1_024
    static let thumbnailDimension = 200

    // MARK: - Types

    struct StoredBlob: Equatable {
        let contentHMAC: Data
        let encryptedSize: Int
        let thumbnailData: Data?
        let detectedMimeType: String
    }

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
        do {
            let fmk = try fmkService.retrieveFMK(familyMemberID: personId.uuidString, primaryKey: primaryKey)
            let processed = try process(plaintext: plaintext)
            logger.entry("store", "detectedMime=\(processed.detectedMimeType), plaintextSize=\(plaintext.count)")
            let hmac = Data(HMAC<SHA256>.authenticationCode(for: processed.data, using: fmk))

            let encryptedSize: Int
            if fileStorage.exists(contentHMAC: hmac) {
                // Dedup: blob already on disk — skip re-encryption and re-write.
                // Return 0 as placeholder since we don't know the encrypted size without reading the file.
                encryptedSize = 0
            } else {
                let encrypted = try encryptionService.encrypt(processed.data, using: fmk).combined
                _ = try fileStorage.store(encryptedData: encrypted, contentHMAC: hmac)
                encryptedSize = encrypted.count
            }
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
        logger.entry("retrieve")
        do {
            let fmk = try fmkService.retrieveFMK(familyMemberID: personId.uuidString, primaryKey: primaryKey)
            let encrypted = try fileStorage.retrieve(contentHMAC: contentHMAC)
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

    func deleteIfUnreferenced(contentHMAC: Data, isReferencedElsewhere: Bool) async throws {
        guard !isReferencedElsewhere else { return }
        try fileStorage.delete(contentHMAC: contentHMAC)
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
