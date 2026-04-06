import CryptoKit
import Foundation
import PDFKit

/// Storage of encrypted document blobs on disk, keyed by HMAC-SHA256 of plaintext (keyed with FMK).
///
/// Per ADR-0004: blobs live separately from record metadata so that syncing a text-field edit does
/// not re-upload the blob. HMAC keying with the Family Member Key prevents rainbow-table attacks
/// on known content.
protocol DocumentBlobServiceProtocol: Sendable {
    /// Encrypt, store, and return storage metadata for a plaintext blob.
    func store(
        plaintext: Data,
        mimeType: String,
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
        mimeType: String,
        personId: UUID,
        primaryKey: SymmetricKey
    ) async throws -> StoredBlob {
        let start = ContinuousClock.now
        logger.entry("store", "mimeType=\(mimeType)")
        do {
            let fmk = try fmkService.retrieveFMK(familyMemberID: personId.uuidString, primaryKey: primaryKey)
            let processed = try process(plaintext: plaintext, mimeType: mimeType)
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
            return StoredBlob(contentHMAC: hmac, encryptedSize: encryptedSize, thumbnailData: processed.thumbnailData)
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

    /// Returns `(data, thumbnail, detectedMimeType)`.
    ///
    /// - Images: validated via CGImageSource, original bytes stored as-is, JPEG thumbnail generated.
    /// - PDFs: validated via PDFDocument, stored as-is.
    /// - Other: rejected.
    private func process(plaintext: Data, mimeType: String) throws -> ProcessedBlob {
        if mimeType.lowercased().hasPrefix("image/") || isImageData(plaintext) {
            let detectedMime = try imageProcessor.validateImage(plaintext)
            guard plaintext.count <= Self.maxFileSizeBytes else {
                throw ModelError.documentTooLarge(maxSizeMB: Self.maxFileSizeBytes / (1_024 * 1_024))
            }
            let thumbnail = try imageProcessor.generateThumbnail(
                plaintext,
                maxDimension: Self.thumbnailDimension
            )
            return ProcessedBlob(data: plaintext, thumbnailData: thumbnail, detectedMimeType: detectedMime)
        } else if mimeType.lowercased() == "application/pdf" {
            guard plaintext.count <= Self.maxFileSizeBytes else {
                throw ModelError.documentTooLarge(maxSizeMB: Self.maxFileSizeBytes / (1_024 * 1_024))
            }
            guard PDFDocument(data: plaintext) != nil else {
                throw ModelError.imageProcessingFailed(reason: "File content is not a valid PDF")
            }
            return ProcessedBlob(data: plaintext, thumbnailData: nil, detectedMimeType: "application/pdf")
        } else {
            throw ModelError.unsupportedMimeType(mimeType: mimeType)
        }
    }

    /// Quick header check to detect image data regardless of the declared MIME type.
    private func isImageData(_ data: Data) -> Bool {
        guard data.count >= 4 else { return false }
        let bytes = [UInt8](data.prefix(4))
        // JPEG
        if bytes[0] == 0xFF, bytes[1] == 0xD8 { return true }
        // PNG
        if bytes[0] == 0x89, bytes[1] == 0x50, bytes[2] == 0x4E, bytes[3] == 0x47 { return true }
        // GIF
        if bytes[0] == 0x47, bytes[1] == 0x49, bytes[2] == 0x46 { return true }
        // TIFF (little-endian and big-endian)
        if bytes[0] == 0x49, bytes[1] == 0x49 { return true }
        if bytes[0] == 0x4D, bytes[1] == 0x4D { return true }
        // BMP
        if bytes[0] == 0x42, bytes[1] == 0x4D { return true }
        // WebP (RIFF header)
        if bytes[0] == 0x52, bytes[1] == 0x49, bytes[2] == 0x46, bytes[3] == 0x46 { return true }
        return false
    }
}
