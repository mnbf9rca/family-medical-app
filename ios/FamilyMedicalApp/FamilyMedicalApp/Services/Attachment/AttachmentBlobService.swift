import CryptoKit
import Foundation

/// Storage of encrypted attachment blobs on disk, keyed by HMAC-SHA256 of plaintext (keyed with FMK).
///
/// Per ADR-0004: blobs live separately from record metadata so that syncing a text-field edit does
/// not re-upload the blob. HMAC keying with the Family Member Key prevents rainbow-table attacks
/// on known content.
protocol AttachmentBlobServiceProtocol: Sendable {
    /// Encrypt, store, and return storage metadata for a plaintext blob.
    func store(
        plaintext: Data,
        mimeType: String,
        personId: UUID,
        primaryKey: SymmetricKey
    ) async throws -> AttachmentBlobService.StoredBlob

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

final class AttachmentBlobService: AttachmentBlobServiceProtocol, @unchecked Sendable {
    // MARK: - Constants

    static let maxFileSizeBytes = 10 * 1_024 * 1_024
    static let maxImageDimension = 4_096
    static let thumbnailDimension = 200
    static let supportedMimeTypes: Set<String> = [
        "image/jpeg",
        "image/png",
        "application/pdf"
    ]

    // MARK: - Types

    struct StoredBlob: Equatable {
        let contentHMAC: Data
        let encryptedSize: Int
        let thumbnailData: Data?
    }

    // MARK: - Dependencies

    private let fileStorage: AttachmentFileStorageServiceProtocol
    private let imageProcessor: ImageProcessingServiceProtocol
    private let encryptionService: EncryptionServiceProtocol
    private let fmkService: FamilyMemberKeyServiceProtocol
    private let logger: TracingCategoryLogger

    init(
        fileStorage: AttachmentFileStorageServiceProtocol,
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

    // MARK: - AttachmentBlobServiceProtocol

    func store(
        plaintext: Data,
        mimeType: String,
        personId: UUID,
        primaryKey: SymmetricKey
    ) async throws -> StoredBlob {
        let start = ContinuousClock.now
        logger.entry("store", "mimeType=\(mimeType)")
        do {
            guard Self.supportedMimeTypes.contains(mimeType.lowercased()) else {
                throw ModelError.unsupportedMimeType(mimeType: mimeType)
            }
            let fmk = try fmkService.retrieveFMK(familyMemberID: personId.uuidString, primaryKey: primaryKey)
            let (processed, thumbnail) = try process(plaintext: plaintext, mimeType: mimeType)
            let hmac = Data(HMAC<SHA256>.authenticationCode(for: processed, using: fmk))

            let encryptedSize: Int
            if fileStorage.exists(contentHMAC: hmac) {
                // Dedup: blob already on disk — skip re-encryption and re-write.
                // Return 0 as placeholder since we don't know the encrypted size without reading the file.
                encryptedSize = 0
            } else {
                let encrypted = try encryptionService.encrypt(processed, using: fmk).combined
                _ = try fileStorage.store(encryptedData: encrypted, contentHMAC: hmac)
                encryptedSize = encrypted.count
            }
            logger.exit("store", duration: ContinuousClock.now - start)
            return StoredBlob(contentHMAC: hmac, encryptedSize: encryptedSize, thumbnailData: thumbnail)
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
                logger.logError(error, context: "AttachmentBlobService.retrieve.decrypt")
                throw ModelError.attachmentContentCorrupted
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

    // MARK: - Private

    private func process(plaintext: Data, mimeType: String) throws -> (Data, Data?) {
        if mimeType.lowercased().hasPrefix("image/") {
            let compressed = try imageProcessor.compress(
                plaintext,
                maxSizeBytes: Self.maxFileSizeBytes,
                maxDimension: Self.maxImageDimension
            )
            let thumbnail = try imageProcessor.generateThumbnail(plaintext, maxDimension: Self.thumbnailDimension)
            return (compressed, thumbnail)
        } else {
            guard plaintext.count <= Self.maxFileSizeBytes else {
                throw ModelError.attachmentTooLarge(maxSizeMB: Self.maxFileSizeBytes / (1_024 * 1_024))
            }
            return (plaintext, nil)
        }
    }
}
