import Foundation

/// Protocol for storing and retrieving encrypted attachment content on the filesystem
///
/// This service handles the actual file storage of encrypted attachment data, separate from
/// the metadata stored in Core Data. Files are named by their content HMAC for deduplication.
///
/// Per ADR-0004: Attachments are stored separately from medical record metadata to enable
/// efficient sync (editing a note field doesn't re-upload attached photos).
protocol AttachmentFileStorageServiceProtocol: Sendable {
    /// Store encrypted data and return the storage URL
    ///
    /// - Parameters:
    ///   - encryptedData: The encrypted attachment content
    ///   - contentHMAC: HMAC-SHA256 of the plaintext content (keyed with FMK)
    /// - Returns: URL where the data was stored
    /// - Throws: ModelError.attachmentStorageFailed if storage fails
    func store(encryptedData: Data, contentHMAC: Data) throws -> URL

    /// Retrieve encrypted content by its HMAC
    ///
    /// - Parameter contentHMAC: The content HMAC used as filename
    /// - Returns: The encrypted attachment data
    /// - Throws: ModelError.attachmentNotFound if file doesn't exist,
    ///           ModelError.attachmentContentCorrupted if read fails
    func retrieve(contentHMAC: Data) throws -> Data

    /// Delete content by its HMAC
    ///
    /// - Parameter contentHMAC: The content HMAC of the file to delete
    /// - Throws: ModelError.attachmentStorageFailed if deletion fails
    func delete(contentHMAC: Data) throws

    /// Check if content exists for the given HMAC
    ///
    /// - Parameter contentHMAC: The content HMAC to check
    /// - Returns: true if file exists, false otherwise
    func exists(contentHMAC: Data) -> Bool
}

/// Default implementation storing attachments in Application Support/Attachments/
final class AttachmentFileStorageService: AttachmentFileStorageServiceProtocol, @unchecked Sendable {
    // MARK: - Properties

    private let fileManager: FileManager
    private let attachmentsDirectory: URL
    private let logger: CategoryLoggerProtocol

    // MARK: - Initialization

    /// Initialize with default Application Support directory
    init(logger: CategoryLoggerProtocol? = nil) throws {
        self.fileManager = FileManager.default
        self.attachmentsDirectory = try Self.createAttachmentsDirectory(fileManager: fileManager)
        self.logger = logger ?? LoggingService.shared.logger(category: .storage)
    }

    /// Initialize with custom directory (for testing)
    init(attachmentsDirectory: URL, fileManager: FileManager = .default, logger: CategoryLoggerProtocol? = nil) {
        self.fileManager = fileManager
        self.attachmentsDirectory = attachmentsDirectory
        self.logger = logger ?? LoggingService.shared.logger(category: .storage)
    }

    // MARK: - AttachmentFileStorageServiceProtocol

    func store(encryptedData: Data, contentHMAC: Data) throws -> URL {
        let fileURL = fileURL(for: contentHMAC)

        // If file already exists (deduplication), skip write
        if fileManager.fileExists(atPath: fileURL.path) {
            return fileURL
        }

        do {
            try encryptedData.write(to: fileURL, options: [.atomic, .completeFileProtection])
            logger.debug("Stored attachment: \(encryptedData.count) bytes")
            return fileURL
        } catch {
            logger.logError(error, context: "AttachmentFileStorageService.store")
            throw ModelError.attachmentStorageFailed(reason: error.localizedDescription)
        }
    }

    func retrieve(contentHMAC: Data) throws -> Data {
        let fileURL = fileURL(for: contentHMAC)

        guard fileManager.fileExists(atPath: fileURL.path) else {
            logger.error("Attachment file not found")
            throw ModelError.attachmentNotFound(attachmentId: UUID()) // Generic UUID since we only have HMAC
        }

        do {
            return try Data(contentsOf: fileURL)
        } catch {
            logger.logError(error, context: "AttachmentFileStorageService.retrieve")
            throw ModelError.attachmentContentCorrupted
        }
    }

    func delete(contentHMAC: Data) throws {
        let fileURL = fileURL(for: contentHMAC)

        // If file doesn't exist, consider it already deleted (idempotent)
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return
        }

        do {
            try fileManager.removeItem(at: fileURL)
            logger.debug("Deleted attachment file")
        } catch {
            logger.logError(error, context: "AttachmentFileStorageService.delete")
            throw ModelError.attachmentStorageFailed(reason: error.localizedDescription)
        }
    }

    func exists(contentHMAC: Data) -> Bool {
        let fileURL = fileURL(for: contentHMAC)
        return fileManager.fileExists(atPath: fileURL.path)
    }

    // MARK: - Private Helpers

    /// Generate file URL from content HMAC
    ///
    /// Files are named as `<hmac-hex>.enc` where the HMAC is the hex-encoded
    /// HMAC-SHA256 of the plaintext content.
    private func fileURL(for contentHMAC: Data) -> URL {
        let hexName = contentHMAC.map { String(format: "%02x", $0) }.joined()
        return attachmentsDirectory.appendingPathComponent("\(hexName).enc")
    }

    /// Create the attachments directory if it doesn't exist
    private static func createAttachmentsDirectory(fileManager: FileManager) throws -> URL {
        guard
            let appSupportURL = fileManager.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first
        else {
            throw ModelError.attachmentStorageFailed(reason: "Application Support directory not found")
        }

        let attachmentsURL = appSupportURL.appendingPathComponent("Attachments", isDirectory: true)

        if !fileManager.fileExists(atPath: attachmentsURL.path) {
            do {
                try fileManager.createDirectory(
                    at: attachmentsURL,
                    withIntermediateDirectories: true,
                    attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
                )
            } catch {
                throw ModelError.attachmentStorageFailed(reason: error.localizedDescription)
            }
        }

        return attachmentsURL
    }
}
