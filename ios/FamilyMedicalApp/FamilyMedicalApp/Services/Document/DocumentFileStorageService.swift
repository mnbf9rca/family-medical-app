import Foundation

/// Protocol for storing and retrieving encrypted document content on the filesystem
///
/// This service handles the actual file storage of encrypted document data, separate from
/// the metadata stored in Core Data. Files are named by their content HMAC for deduplication.
///
/// Per ADR-0004: Document blobs are stored separately from medical record metadata to enable
/// efficient sync (editing a note field doesn't re-upload attached photos).
///
/// Blobs are stored under `Attachments/{personId}/{hmac}.enc` to enable per-person orphan cleanup.
protocol DocumentFileStorageServiceProtocol: Sendable {
    /// Store encrypted data and return the storage URL
    ///
    /// - Parameters:
    ///   - encryptedData: The encrypted document content
    ///   - contentHMAC: HMAC-SHA256 of the plaintext content (keyed with FMK)
    ///   - personId: The person whose subdirectory should hold the blob
    /// - Returns: URL where the data was stored
    /// - Throws: ModelError.documentStorageFailed if storage fails
    func store(encryptedData: Data, contentHMAC: Data, personId: UUID) throws -> URL

    /// Retrieve encrypted content by its HMAC
    ///
    /// - Parameters:
    ///   - contentHMAC: The content HMAC used as filename
    ///   - personId: The person whose subdirectory contains the blob
    /// - Returns: The encrypted document data
    /// - Throws: ModelError.documentNotFound if file doesn't exist,
    ///           ModelError.documentContentCorrupted if read fails
    func retrieve(contentHMAC: Data, personId: UUID) throws -> Data

    /// Delete content by its HMAC
    ///
    /// - Parameters:
    ///   - contentHMAC: The content HMAC of the file to delete
    ///   - personId: The person whose subdirectory contains the blob
    /// - Throws: ModelError.documentStorageFailed if deletion fails
    func delete(contentHMAC: Data, personId: UUID) throws

    /// Check if content exists for the given HMAC
    ///
    /// - Parameters:
    ///   - contentHMAC: The content HMAC to check
    ///   - personId: The person whose subdirectory to check
    /// - Returns: true if file exists, false otherwise
    func exists(contentHMAC: Data, personId: UUID) -> Bool

    /// List all blob HMACs stored for a person
    ///
    /// - Parameter personId: The person whose subdirectory to enumerate
    /// - Returns: Set of HMAC Data values for every `.enc` file found
    /// - Throws: ModelError.documentStorageFailed if directory enumeration fails
    func listBlobs(personId: UUID) throws -> Set<Data>

    /// Return the on-disk size of a stored blob in bytes
    ///
    /// - Parameters:
    ///   - contentHMAC: The content HMAC of the file
    ///   - personId: The person whose subdirectory contains the blob
    /// - Returns: File size in bytes
    /// - Throws: ModelError.documentStorageFailed if attributes cannot be read
    func blobSize(contentHMAC: Data, personId: UUID) throws -> UInt64
}

/// Default implementation storing documents in Application Support/Attachments/{personId}/
final class DocumentFileStorageService: DocumentFileStorageServiceProtocol, @unchecked Sendable {
    // MARK: - Properties

    private let fileManager: FileManager
    private let attachmentsDirectory: URL
    private let logger: TracingCategoryLogger

    // MARK: - Initialization

    /// Initialize with default Application Support directory
    init(logger: CategoryLoggerProtocol? = nil) throws {
        self.fileManager = FileManager.default
        self.attachmentsDirectory = try Self.createAttachmentsDirectory(fileManager: fileManager)
        self.logger = TracingCategoryLogger(
            wrapping: logger ?? LoggingService.shared.logger(category: .storage)
        )
    }

    /// Initialize with custom directory (for testing)
    init(attachmentsDirectory: URL, fileManager: FileManager = .default, logger: CategoryLoggerProtocol? = nil) {
        self.fileManager = fileManager
        self.attachmentsDirectory = attachmentsDirectory
        self.logger = TracingCategoryLogger(
            wrapping: logger ?? LoggingService.shared.logger(category: .storage)
        )
    }

    // MARK: - DocumentFileStorageServiceProtocol

    func store(encryptedData: Data, contentHMAC: Data, personId: UUID) throws -> URL {
        let start = ContinuousClock.now
        logger.entry("store", "personId=\(personId), size=\(encryptedData.count)")
        do {
            let dirURL = try ensurePersonDirectory(for: personId)
            let fileURL = blobURL(for: contentHMAC, in: dirURL)

            // If file already exists (deduplication), skip write
            if fileManager.fileExists(atPath: fileURL.path) {
                logger.exit("store", duration: ContinuousClock.now - start)
                return fileURL
            }

            do {
                try encryptedData.write(to: fileURL, options: [.atomic, .completeFileProtection])
            } catch {
                throw ModelError.documentStorageFailed(reason: error.localizedDescription)
            }
            logger.exit("store", duration: ContinuousClock.now - start)
            return fileURL
        } catch {
            logger.exitWithError("store", error: error, duration: ContinuousClock.now - start)
            throw error
        }
    }

    func retrieve(contentHMAC: Data, personId: UUID) throws -> Data {
        let start = ContinuousClock.now
        logger.entry("retrieve", "personId=\(personId)")
        do {
            let fileURL = fileURL(for: contentHMAC, personId: personId)

            guard fileManager.fileExists(atPath: fileURL.path) else {
                throw ModelError.documentNotFound()
            }

            let data: Data
            do {
                data = try Data(contentsOf: fileURL)
            } catch {
                throw ModelError.documentContentCorrupted
            }
            logger.exit("retrieve", duration: ContinuousClock.now - start)
            return data
        } catch {
            logger.exitWithError("retrieve", error: error, duration: ContinuousClock.now - start)
            throw error
        }
    }

    func delete(contentHMAC: Data, personId: UUID) throws {
        let start = ContinuousClock.now
        logger.entry("delete", "personId=\(personId)")
        do {
            let fileURL = fileURL(for: contentHMAC, personId: personId)

            // If file doesn't exist, consider it already deleted (idempotent)
            guard fileManager.fileExists(atPath: fileURL.path) else {
                logger.exit("delete", duration: ContinuousClock.now - start)
                return
            }

            do {
                try fileManager.removeItem(at: fileURL)
            } catch {
                throw ModelError.documentStorageFailed(reason: error.localizedDescription)
            }
            logger.exit("delete", duration: ContinuousClock.now - start)
        } catch {
            logger.exitWithError("delete", error: error, duration: ContinuousClock.now - start)
            throw error
        }
    }

    func exists(contentHMAC: Data, personId: UUID) -> Bool {
        let start = ContinuousClock.now
        logger.entry("exists", "personId=\(personId)")
        let fileURL = fileURL(for: contentHMAC, personId: personId)
        let present = fileManager.fileExists(atPath: fileURL.path)
        logger.exit("exists", duration: ContinuousClock.now - start)
        return present
    }

    func listBlobs(personId: UUID) throws -> Set<Data> {
        let start = ContinuousClock.now
        logger.entry("listBlobs", "personId=\(personId)")
        do {
            let dirURL = personDirectory(for: personId)
            guard fileManager.fileExists(atPath: dirURL.path) else {
                logger.exit("listBlobs", duration: ContinuousClock.now - start)
                return [] // no directory yet = no blobs
            }
            let files: [URL]
            do {
                files = try fileManager.contentsOfDirectory(
                    at: dirURL,
                    includingPropertiesForKeys: nil,
                    options: .skipsHiddenFiles
                )
            } catch {
                throw ModelError.documentStorageFailed(reason: error.localizedDescription)
            }
            var hmacs = Set<Data>()
            for file in files where file.pathExtension == "enc" {
                if let hmac = hmacFromFilename(file.deletingPathExtension().lastPathComponent) {
                    hmacs.insert(hmac)
                }
            }
            logger.debug("listBlobs returned \(hmacs.count) blobs")
            logger.exit("listBlobs", duration: ContinuousClock.now - start)
            return hmacs
        } catch {
            logger.exitWithError("listBlobs", error: error, duration: ContinuousClock.now - start)
            throw error
        }
    }

    func blobSize(contentHMAC: Data, personId: UUID) throws -> UInt64 {
        let start = ContinuousClock.now
        logger.entry("blobSize", "personId=\(personId)")
        do {
            let fileURL = fileURL(for: contentHMAC, personId: personId)
            // Distinguish "file missing" (a race with concurrent deletion — expected
            // during cleanup scans) from "attributes unreadable" (permissions/IO error).
            // The cleanup scanner can swallow `documentNotFound` safely.
            guard fileManager.fileExists(atPath: fileURL.path) else {
                throw ModelError.documentNotFound()
            }
            let attrs: [FileAttributeKey: Any]
            do {
                attrs = try fileManager.attributesOfItem(atPath: fileURL.path)
            } catch {
                throw ModelError.documentStorageFailed(reason: error.localizedDescription)
            }
            // Guard lives outside the FileManager do/catch so its crafted reason string
            // reaches the outer exitWithError tracing intact — an inner catch would
            // rewrap this typed error via error.localizedDescription and drop the detail.
            guard let size = attrs[.size] as? UInt64 else {
                let actualType = attrs[.size].map { "\(type(of: $0))" } ?? "nil"
                throw ModelError.documentStorageFailed(
                    reason: "Unexpected file size attribute type '\(actualType)' for \(fileURL.lastPathComponent)"
                )
            }
            logger.exit("blobSize", duration: ContinuousClock.now - start)
            return size
        } catch {
            logger.exitWithError("blobSize", error: error, duration: ContinuousClock.now - start)
            throw error
        }
    }

    // MARK: - Private Helpers

    /// Return the per-person subdirectory URL (may not exist yet)
    private func personDirectory(for personId: UUID) -> URL {
        attachmentsDirectory.appendingPathComponent(personId.uuidString, isDirectory: true)
    }

    /// Generate a blob file URL given its HMAC and parent directory
    ///
    /// Files are named as `<hmac-hex>.enc` where the HMAC is the hex-encoded
    /// HMAC-SHA256 of the plaintext content.
    private func blobURL(for contentHMAC: Data, in directory: URL) -> URL {
        let hexName = contentHMAC.map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent("\(hexName).enc")
    }

    /// Generate file URL from content HMAC and person ID
    private func fileURL(for contentHMAC: Data, personId: UUID) -> URL {
        blobURL(for: contentHMAC, in: personDirectory(for: personId))
    }

    /// Create the per-person subdirectory if it doesn't exist, and return its URL.
    ///
    /// `createDirectory(withIntermediateDirectories: true)` is idempotent — it succeeds
    /// whether or not the directory exists, so no pre-`fileExists` guard is needed.
    /// `.protectionKey` is only applied on actual creation; re-calling on an existing
    /// directory is a no-op for attributes.
    private func ensurePersonDirectory(for personId: UUID) throws -> URL {
        let dirURL = personDirectory(for: personId)
        do {
            try fileManager.createDirectory(
                at: dirURL,
                withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.complete]
            )
        } catch {
            throw ModelError.documentStorageFailed(reason: error.localizedDescription)
        }
        return dirURL
    }

    /// Decode a hex string back to Data; returns nil on malformed input.
    ///
    /// An empty string produces `nil` so a stray `.enc` file (or any zero-length
    /// filename stem) is rejected rather than inserting an empty-HMAC entry into
    /// the caller's Set.
    private func hmacFromFilename(_ hex: String) -> Data? {
        guard !hex.isEmpty, hex.count.isMultiple(of: 2) else { return nil }
        var data = Data(capacity: hex.count / 2)
        var index = hex.startIndex
        while index < hex.endIndex {
            let nextIndex = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index ..< nextIndex], radix: 16) else { return nil }
            data.append(byte)
            index = nextIndex
        }
        return data
    }

    /// Create the top-level attachments directory if it doesn't exist
    private static func createAttachmentsDirectory(fileManager: FileManager) throws -> URL {
        guard
            let appSupportURL = fileManager.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first
        else {
            throw ModelError.documentStorageFailed(reason: "Application Support directory not found")
        }

        let attachmentsURL = appSupportURL.appendingPathComponent("Attachments", isDirectory: true)

        if !fileManager.fileExists(atPath: attachmentsURL.path) {
            do {
                try fileManager.createDirectory(
                    at: attachmentsURL,
                    withIntermediateDirectories: true,
                    attributes: [.protectionKey: FileProtectionType.complete]
                )
            } catch {
                throw ModelError.documentStorageFailed(reason: error.localizedDescription)
            }
        }

        return attachmentsURL
    }
}
