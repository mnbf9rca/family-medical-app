import Foundation

/// Attachment metadata for medical records
///
/// Represents metadata for file attachments (photos, PDFs, etc.) linked to medical records.
/// Note: fileName and mimeType are encrypted when stored (per ADR-0004).
///
/// Attachment Storage (per ADR-0004):
/// - Content is stored separately from metadata for bandwidth efficiency
/// - Content is identified by HMAC-SHA256(content, FMK) for deduplication
/// - Same photo attached to multiple records is stored once
struct Attachment: Codable, Equatable, Identifiable {
    // MARK: - Validation Constants

    static let fileNameMaxLength = 255
    static let mimeTypeMaxLength = 100

    // MARK: - Plaintext Properties (sync coordination)

    /// Unique identifier for this attachment
    let id: UUID

    /// When this attachment was uploaded
    let uploadedAt: Date

    /// HMAC-SHA256 of the encrypted content for deduplication (per ADR-0004)
    ///
    /// - Keyed with FMK to prevent rainbow table attacks
    /// - Used by server to deduplicate identical content
    /// - Server cannot decrypt without FMK, so HMAC is opaque
    let contentHMAC: Data

    /// Size of the encrypted attachment data in bytes
    ///
    /// - Server can see this for storage allocation
    /// - Used for upload/download progress tracking
    let encryptedSize: Int

    // MARK: - Encrypted Properties

    /// File name (encrypted when stored)
    ///
    /// Examples: "vaccine-card.jpg", "prescription.pdf"
    var fileName: String

    /// MIME type (encrypted when stored)
    ///
    /// Examples: "image/jpeg", "application/pdf"
    /// Encrypted to prevent server from inferring health data patterns
    var mimeType: String

    /// Optional encrypted thumbnail data
    ///
    /// - Small preview image for quick display in UI
    /// - Encrypted like the main content
    var thumbnailData: Data?

    // MARK: - Initialization

    /// Initialize a new attachment record
    ///
    /// - Parameters:
    ///   - id: Unique identifier (defaults to new UUID)
    ///   - fileName: Name of the file (trimmed, validated for length)
    ///   - mimeType: MIME type of the file (validated for length)
    ///   - contentHMAC: HMAC of the encrypted content for deduplication
    ///   - encryptedSize: Size of encrypted data in bytes (must be non-negative)
    ///   - thumbnailData: Optional encrypted thumbnail
    ///   - uploadedAt: Upload timestamp (defaults to now)
    /// - Throws: ModelError if validation fails
    init(
        id: UUID = UUID(),
        fileName: String,
        mimeType: String,
        contentHMAC: Data,
        encryptedSize: Int,
        thumbnailData: Data? = nil,
        uploadedAt: Date = Date()
    ) throws {
        // Validate fileName
        let trimmedFileName = fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedFileName.isEmpty else {
            throw ModelError.fileNameEmpty
        }
        guard trimmedFileName.count <= Self.fileNameMaxLength else {
            throw ModelError.fileNameTooLong(maxLength: Self.fileNameMaxLength)
        }

        // Validate mimeType
        let trimmedMimeType = mimeType.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedMimeType.count <= Self.mimeTypeMaxLength else {
            throw ModelError.mimeTypeTooLong(maxLength: Self.mimeTypeMaxLength)
        }

        // Validate encryptedSize
        guard encryptedSize >= 0 else {
            throw ModelError.invalidFileSize
        }

        self.id = id
        self.fileName = trimmedFileName
        self.mimeType = trimmedMimeType
        self.contentHMAC = contentHMAC
        self.encryptedSize = encryptedSize
        self.thumbnailData = thumbnailData
        self.uploadedAt = uploadedAt
    }

    // MARK: - Helpers

    /// File extension extracted from fileName
    var fileExtension: String? {
        guard let dotIndex = fileName.lastIndex(of: ".") else {
            return nil
        }
        let extensionStartIndex = fileName.index(after: dotIndex)
        return String(fileName[extensionStartIndex...])
    }

    /// Check if this is an image based on MIME type
    var isImage: Bool {
        mimeType.hasPrefix("image/")
    }

    /// Check if this is a PDF based on MIME type
    var isPDF: Bool {
        mimeType == "application/pdf"
    }

    /// Human-readable file size string
    var fileSizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: Int64(encryptedSize), countStyle: .file)
    }
}
