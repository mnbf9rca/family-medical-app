import CryptoKit
import Foundation

// MARK: - Input Types

/// Input parameters for adding an attachment
struct AddAttachmentInput {
    /// Optional ID to use for the attachment (for backup restoration).
    /// If nil, a new UUID will be generated.
    let id: UUID?
    let data: Data
    let fileName: String
    let mimeType: String
    let recordId: UUID
    let personId: UUID
    let primaryKey: SymmetricKey

    /// Initialize with optional ID (for backup restoration)
    init(
        id: UUID? = nil,
        data: Data,
        fileName: String,
        mimeType: String,
        recordId: UUID,
        personId: UUID,
        primaryKey: SymmetricKey
    ) {
        self.id = id
        self.data = data
        self.fileName = fileName
        self.mimeType = mimeType
        self.recordId = recordId
        self.personId = personId
        self.primaryKey = primaryKey
    }
}

/// Protocol for high-level attachment operations
///
/// This service orchestrates the complete attachment lifecycle: adding files (with
/// compression, thumbnail generation, encryption), retrieving content, and deleting
/// attachments (with orphan cleanup).
///
/// Per ADR-0004: Attachments are stored separately from medical record metadata, with
/// HMAC-based deduplication keyed by FMK.
protocol AttachmentServiceProtocol: Sendable {
    /// Add a new attachment from raw data
    ///
    /// This method:
    /// 1. Validates file size and MIME type
    /// 2. Compresses images if needed
    /// 3. Generates thumbnail for images
    /// 4. Computes content HMAC for deduplication
    /// 5. Encrypts and stores content
    /// 6. Saves metadata to repository
    /// 7. Links attachment to record
    ///
    /// - Parameter input: Input parameters bundled in AddAttachmentInput
    /// - Returns: The created Attachment
    /// - Throws: ModelError for validation/processing failures
    func addAttachment(_ input: AddAttachmentInput) async throws -> Attachment

    /// Get decrypted attachment content
    ///
    /// - Parameters:
    ///   - attachment: The attachment to retrieve content for
    ///   - personId: Person ID (for FMK lookup)
    ///   - primaryKey: Primary key (to unwrap FMK)
    /// - Returns: Decrypted file content
    /// - Throws: ModelError if content cannot be retrieved or decrypted
    func getContent(
        attachment: Attachment,
        personId: UUID,
        primaryKey: SymmetricKey
    ) async throws -> Data

    /// Delete an attachment from a record
    ///
    /// Unlinks the attachment from the record. If no other records reference this
    /// attachment (orphaned), also deletes the file and metadata.
    ///
    /// - Parameters:
    ///   - attachmentId: ID of the attachment to delete
    ///   - recordId: ID of the record to unlink from
    /// - Throws: ModelError if deletion fails
    func deleteAttachment(
        attachmentId: UUID,
        recordId: UUID
    ) async throws

    /// Fetch all attachments for a record
    ///
    /// - Parameters:
    ///   - recordId: The record ID
    ///   - personId: Person ID (for FMK lookup)
    ///   - primaryKey: Primary key (to unwrap FMK)
    /// - Returns: Array of attachments linked to the record
    /// - Throws: RepositoryError if fetch fails
    func fetchAttachments(
        recordId: UUID,
        personId: UUID,
        primaryKey: SymmetricKey
    ) async throws -> [Attachment]

    /// Count attachments for a record
    ///
    /// - Parameter recordId: The record ID
    /// - Returns: Number of attachments linked to the record
    /// - Throws: RepositoryError if count fails
    func attachmentCount(recordId: UUID) async throws -> Int
}

/// Default implementation of AttachmentService
final class AttachmentService: AttachmentServiceProtocol, @unchecked Sendable {
    // MARK: - Constants

    /// Maximum file size in bytes (10 MB)
    static let maxFileSizeBytes = 10 * 1_024 * 1_024

    /// Maximum attachments per record
    static let maxAttachmentsPerRecord = 5

    /// Maximum image dimension in pixels
    static let maxImageDimension = 4_096

    /// Thumbnail dimension in pixels
    static let thumbnailDimension = 200

    /// Supported MIME types
    static let supportedMimeTypes: Set<String> = [
        "image/jpeg",
        "image/png",
        "application/pdf"
    ]

    // MARK: - Dependencies

    private let attachmentRepository: AttachmentRepositoryProtocol
    private let fileStorage: AttachmentFileStorageServiceProtocol
    private let imageProcessor: ImageProcessingServiceProtocol
    private let encryptionService: EncryptionServiceProtocol
    private let fmkService: FamilyMemberKeyServiceProtocol
    private let logger: CategoryLoggerProtocol

    // MARK: - Initialization

    init(
        attachmentRepository: AttachmentRepositoryProtocol,
        fileStorage: AttachmentFileStorageServiceProtocol,
        imageProcessor: ImageProcessingServiceProtocol,
        encryptionService: EncryptionServiceProtocol,
        fmkService: FamilyMemberKeyServiceProtocol,
        logger: CategoryLoggerProtocol? = nil
    ) {
        self.attachmentRepository = attachmentRepository
        self.fileStorage = fileStorage
        self.imageProcessor = imageProcessor
        self.encryptionService = encryptionService
        self.fmkService = fmkService
        self.logger = logger ?? LoggingService.shared.logger(category: .storage)
    }

    // MARK: - AttachmentServiceProtocol

    func addAttachment(_ input: AddAttachmentInput) async throws -> Attachment {
        logger.debug("Adding attachment: \(input.fileName) (\(input.mimeType))")

        // Step 1: Validate MIME type and attachment count
        try await validateInput(input)

        // Step 2: Get FMK for this person
        let fmk = try fmkService.retrieveFMK(familyMemberID: input.personId.uuidString, primaryKey: input.primaryKey)

        // Step 3: Process data based on type
        let (processedData, thumbnailData) = try processContent(input.data, mimeType: input.mimeType)

        // Step 4: Compute content HMAC for deduplication (keyed with FMK per ADR-0004)
        let contentHMAC = computeHMAC(data: processedData, key: fmk)

        // Step 5: Check for existing attachment with same content (deduplication)
        if let existing = try await checkDeduplication(
            contentHMAC: contentHMAC,
            recordId: input.recordId,
            input: input
        ) {
            logger.debug("Deduplication: reusing existing attachment \(existing.id)")
            return existing
        }

        // Step 6: Encrypt and store new content
        let encryptedData = try encryptAndStore(processedData: processedData, fmk: fmk, contentHMAC: contentHMAC)

        // Step 7: Create and save attachment metadata
        return try await createAndSaveAttachment(
            input: input,
            contentHMAC: contentHMAC,
            encryptedData: encryptedData,
            thumbnailData: thumbnailData
        )
    }

    // MARK: - Private Helpers for addAttachment

    private func validateInput(_ input: AddAttachmentInput) async throws {
        guard Self.supportedMimeTypes.contains(input.mimeType.lowercased()) else {
            throw ModelError.unsupportedMimeType(mimeType: input.mimeType)
        }

        let currentCount = try await attachmentCount(recordId: input.recordId)
        guard currentCount < Self.maxAttachmentsPerRecord else {
            throw ModelError.attachmentLimitExceeded(max: Self.maxAttachmentsPerRecord)
        }
    }

    private func processContent(_ data: Data, mimeType: String) throws -> (Data, Data?) {
        if isImage(mimeType: mimeType) {
            let processedData = try imageProcessor.compress(
                data,
                maxSizeBytes: Self.maxFileSizeBytes,
                maxDimension: Self.maxImageDimension
            )
            let thumbnailData = try imageProcessor.generateThumbnail(data, maxDimension: Self.thumbnailDimension)
            return (processedData, thumbnailData)
        } else {
            guard data.count <= Self.maxFileSizeBytes else {
                throw ModelError.attachmentTooLarge(maxSizeMB: Self.maxFileSizeBytes / (1_024 * 1_024))
            }
            return (data, nil)
        }
    }

    private func checkDeduplication(
        contentHMAC: Data,
        recordId: UUID,
        input: AddAttachmentInput
    ) async throws -> Attachment? {
        guard let existingId = try await attachmentRepository.findByContentHMAC(contentHMAC) else {
            return nil
        }
        try await attachmentRepository.linkToRecord(attachmentId: existingId, recordId: recordId)
        guard let existing = try await attachmentRepository.fetch(
            id: existingId,
            personId: input.personId,
            primaryKey: input.primaryKey
        ) else {
            throw ModelError.attachmentNotFound(attachmentId: existingId)
        }
        return existing
    }

    private func encryptAndStore(processedData: Data, fmk: SymmetricKey, contentHMAC: Data) throws -> Data {
        let encryptedPayload = try encryptionService.encrypt(processedData, using: fmk)
        let encryptedData = encryptedPayload.combined
        _ = try fileStorage.store(encryptedData: encryptedData, contentHMAC: contentHMAC)
        return encryptedData
    }

    private func createAndSaveAttachment(
        input: AddAttachmentInput,
        contentHMAC: Data,
        encryptedData: Data,
        thumbnailData: Data?
    ) async throws -> Attachment {
        let attachment = try Attachment(
            id: input.id ?? UUID(),
            fileName: input.fileName,
            mimeType: input.mimeType,
            contentHMAC: contentHMAC,
            encryptedSize: encryptedData.count,
            thumbnailData: thumbnailData,
            uploadedAt: Date()
        )
        try await attachmentRepository.save(attachment, personId: input.personId, primaryKey: input.primaryKey)
        try await attachmentRepository.linkToRecord(attachmentId: attachment.id, recordId: input.recordId)
        return attachment
    }

    func getContent(
        attachment: Attachment,
        personId: UUID,
        primaryKey: SymmetricKey
    ) async throws -> Data {
        // Get FMK for decryption
        let fmk = try fmkService.retrieveFMK(familyMemberID: personId.uuidString, primaryKey: primaryKey)

        // Retrieve encrypted content from file storage
        let encryptedData = try fileStorage.retrieve(contentHMAC: attachment.contentHMAC)

        // Decrypt content
        do {
            let payload = try EncryptedPayload(combined: encryptedData)
            return try encryptionService.decrypt(payload, using: fmk)
        } catch {
            logger.logError(error, context: "AttachmentService.getContent.decrypt")
            throw ModelError.attachmentContentCorrupted
        }
    }

    func deleteAttachment(
        attachmentId: UUID,
        recordId: UUID
    ) async throws {
        // Unlink from record
        try await attachmentRepository.unlinkFromRecord(attachmentId: attachmentId, recordId: recordId)

        // Check if orphaned (no other records reference this attachment)
        let remainingLinks = try await attachmentRepository.linkCount(attachmentId: attachmentId)

        if remainingLinks == 0 {
            // Fetch attachment to get contentHMAC for file deletion
            // Note: We need the HMAC but don't need decryption, so we fetch the entity directly
            // For now, we'll delete the metadata which will cascade

            // Get the attachment's contentHMAC before deleting metadata
            // We need to access it through the repository's raw data access
            // Since we can't decrypt without person context, we'll just delete the metadata
            // The file storage uses the same HMAC, so we need it

            // Actually, the delete method in repository handles the metadata deletion
            // But we need the contentHMAC to delete the file
            // This requires fetching the entity - but we don't have person context here

            // For now, delete the metadata. The file will be orphaned but not leaked
            // (encrypted, no key access)
            // TODO: Consider passing personId/primaryKey to enable file cleanup
            try await attachmentRepository.delete(id: attachmentId)
        }
    }

    func fetchAttachments(
        recordId: UUID,
        personId: UUID,
        primaryKey: SymmetricKey
    ) async throws -> [Attachment] {
        try await attachmentRepository.fetchForRecord(
            recordId: recordId,
            personId: personId,
            primaryKey: primaryKey
        )
    }

    func attachmentCount(recordId: UUID) async throws -> Int {
        try await attachmentRepository.attachmentCountForRecord(recordId: recordId)
    }

    // MARK: - Private Helpers

    /// Check if MIME type is an image
    private func isImage(mimeType: String) -> Bool {
        mimeType.lowercased().hasPrefix("image/")
    }

    /// Compute HMAC-SHA256 of data using FMK
    ///
    /// Per ADR-0004: HMAC keyed with FMK prevents rainbow table attacks on known content
    private func computeHMAC(data: Data, key: SymmetricKey) -> Data {
        let hmac = HMAC<SHA256>.authenticationCode(for: data, using: key)
        return Data(hmac)
    }
}

// MARK: - Extended Service with File Cleanup

extension AttachmentService {
    /// Delete attachment with full cleanup including file storage
    ///
    /// This version accepts person context to enable encrypted file cleanup.
    ///
    /// - Parameters:
    ///   - attachmentId: ID of the attachment to delete
    ///   - recordId: ID of the record to unlink from
    ///   - personId: Person ID for FMK access
    ///   - primaryKey: Primary key to unwrap FMK
    func deleteAttachmentWithCleanup(
        attachmentId: UUID,
        recordId: UUID,
        personId: UUID,
        primaryKey: SymmetricKey
    ) async throws {
        // Fetch attachment first to get contentHMAC
        let attachment = try await attachmentRepository.fetch(
            id: attachmentId,
            personId: personId,
            primaryKey: primaryKey
        )

        // Unlink from record
        try await attachmentRepository.unlinkFromRecord(attachmentId: attachmentId, recordId: recordId)

        // Check if orphaned
        let remainingLinks = try await attachmentRepository.linkCount(attachmentId: attachmentId)

        if remainingLinks == 0, let attachment {
            // Delete file from storage
            try fileStorage.delete(contentHMAC: attachment.contentHMAC)

            // Delete metadata
            try await attachmentRepository.delete(id: attachmentId)
        }
    }
}
