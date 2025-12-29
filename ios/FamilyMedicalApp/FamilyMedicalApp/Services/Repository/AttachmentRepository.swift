import CoreData
import CryptoKit
import Foundation

/// Metadata to encrypt for attachments
///
/// This struct contains the sensitive fields from Attachment that need encryption.
/// Used internally by AttachmentRepository for encrypt/decrypt operations.
private struct AttachmentMetadata: Codable {
    let fileName: String
    let mimeType: String
    let thumbnailData: Data?
}

/// Repository for managing encrypted attachment metadata
///
/// Handles CRUD operations for Attachment entities with automatic encryption
/// of fileName, mimeType, and thumbnailData fields.
///
/// Deduplication:
/// - Uses contentHMAC (HMAC-SHA256 of encrypted content with FMK) to detect duplicates
/// - Same file attached to multiple records is stored once
/// - RecordAttachment join table manages many-to-many relationships
protocol AttachmentRepositoryProtocol: Sendable {
    /// Save an attachment with encrypted metadata
    ///
    /// - Parameters:
    ///   - attachment: The attachment to save
    ///   - personId: Person ID for FMK lookup (encryption context)
    ///   - primaryKey: Primary key to unwrap FMK
    /// - Throws: RepositoryError if encryption or save fails
    func save(_ attachment: Attachment, personId: UUID, primaryKey: SymmetricKey) async throws

    /// Fetch an attachment by ID
    ///
    /// - Parameters:
    ///   - id: The attachment ID
    ///   - personId: Person ID for FMK lookup (decryption context)
    ///   - primaryKey: Primary key to unwrap FMK
    /// - Returns: The attachment if found, nil otherwise
    /// - Throws: RepositoryError if fetch or decryption fails
    func fetch(id: UUID, personId: UUID, primaryKey: SymmetricKey) async throws -> Attachment?

    /// Find attachment by content HMAC (for deduplication)
    ///
    /// - Parameter hmac: The content HMAC to search for
    /// - Returns: The attachment if found, nil otherwise
    /// - Throws: RepositoryError if fetch fails
    func findByContentHMAC(_ hmac: Data) async throws -> UUID?

    /// Link an attachment to a medical record
    ///
    /// - Parameters:
    ///   - attachmentId: The attachment ID
    ///   - recordId: The medical record ID
    /// - Throws: RepositoryError if link fails
    func linkToRecord(attachmentId: UUID, recordId: UUID) async throws

    /// Delete an attachment by ID
    ///
    /// - Parameter id: The attachment ID to delete
    /// - Throws: RepositoryError if record not found or delete fails
    func delete(id: UUID) async throws

    /// Check if an attachment exists
    ///
    /// - Parameter id: The attachment ID
    /// - Returns: true if attachment exists, false otherwise
    /// - Throws: RepositoryError if check fails
    func exists(id: UUID) async throws -> Bool
}

final class AttachmentRepository: AttachmentRepositoryProtocol, @unchecked Sendable {
    // MARK: - Dependencies

    private let coreDataStack: CoreDataStackProtocol
    private let encryptionService: EncryptionServiceProtocol
    private let fmkService: FamilyMemberKeyServiceProtocol

    // MARK: - Initialization

    init(
        coreDataStack: CoreDataStackProtocol,
        encryptionService: EncryptionServiceProtocol,
        fmkService: FamilyMemberKeyServiceProtocol
    ) {
        self.coreDataStack = coreDataStack
        self.encryptionService = encryptionService
        self.fmkService = fmkService
    }

    // MARK: - AttachmentRepositoryProtocol

    func save(_ attachment: Attachment, personId: UUID, primaryKey: SymmetricKey) async throws {
        let context = coreDataStack.viewContext

        try await context.perform {
            // Get FMK for encryption
            let fmk = try self.fmkService.retrieveFMK(familyMemberID: personId.uuidString, primaryKey: primaryKey)

            // Encrypt metadata
            let metadata = AttachmentMetadata(
                fileName: attachment.fileName,
                mimeType: attachment.mimeType,
                thumbnailData: attachment.thumbnailData
            )

            let encryptedMetadata = try self.encryptMetadata(metadata, using: fmk)

            // Check if entity already exists
            let request: NSFetchRequest<AttachmentEntity> = AttachmentEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", attachment.id as CVarArg)
            request.fetchLimit = 1

            let existing = try context.fetch(request).first

            let entity = existing ?? AttachmentEntity(context: context)

            // Update entity properties
            entity.id = attachment.id
            entity.uploadedAt = attachment.uploadedAt
            entity.contentHMAC = attachment.contentHMAC
            entity.encryptedSize = Int64(attachment.encryptedSize)
            entity.encryptedMetadata = encryptedMetadata

            // Save context
            do {
                try context.save()
            } catch {
                throw RepositoryError.saveFailed(error.localizedDescription)
            }
        }
    }

    func fetch(id: UUID, personId: UUID, primaryKey: SymmetricKey) async throws -> Attachment? {
        let context = coreDataStack.viewContext

        return try await context.perform {
            let request: NSFetchRequest<AttachmentEntity> = AttachmentEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1

            guard let entity = try context.fetch(request).first else {
                return nil
            }

            return try self.mapEntityToModel(entity, personId: personId, primaryKey: primaryKey)
        }
    }

    func findByContentHMAC(_ hmac: Data) async throws -> UUID? {
        let context = coreDataStack.viewContext

        return try await context.perform {
            let request: NSFetchRequest<AttachmentEntity> = AttachmentEntity.fetchRequest()
            request.predicate = NSPredicate(format: "contentHMAC == %@", hmac as CVarArg)
            request.fetchLimit = 1

            guard let entity = try context.fetch(request).first,
                  let id = entity.id
            else {
                return nil
            }

            return id
        }
    }

    func linkToRecord(attachmentId: UUID, recordId: UUID) async throws {
        let context = coreDataStack.viewContext

        try await context.perform {
            // Check if link already exists
            let request: NSFetchRequest<RecordAttachmentEntity> = RecordAttachmentEntity.fetchRequest()
            request.predicate = NSPredicate(
                format: "attachmentId == %@ AND recordId == %@",
                attachmentId as CVarArg,
                recordId as CVarArg
            )
            request.fetchLimit = 1

            let existing = try context.fetch(request).first

            // Only create if doesn't exist
            if existing == nil {
                let link = RecordAttachmentEntity(context: context)
                link.attachmentId = attachmentId
                link.recordId = recordId

                do {
                    try context.save()
                } catch {
                    throw RepositoryError.saveFailed(error.localizedDescription)
                }
            }
        }
    }

    func delete(id: UUID) async throws {
        let context = coreDataStack.viewContext

        try await context.perform {
            let request: NSFetchRequest<AttachmentEntity> = AttachmentEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1

            guard let entity = try context.fetch(request).first else {
                throw RepositoryError.entityNotFound("Attachment with ID \(id)")
            }

            context.delete(entity)

            do {
                try context.save()
            } catch {
                throw RepositoryError.deleteFailed(error.localizedDescription)
            }
        }
    }

    func exists(id: UUID) async throws -> Bool {
        let context = coreDataStack.viewContext

        return try await context.perform {
            let request: NSFetchRequest<NSFetchRequestResult> = AttachmentEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.resultType = .countResultType

            let count = try context.count(for: request)
            return count > 0
        }
    }

    // MARK: - Private Helpers

    private func encryptMetadata(_ metadata: AttachmentMetadata, using key: SymmetricKey) throws -> Data {
        do {
            let jsonData = try JSONEncoder().encode(metadata)
            let encryptedPayload = try encryptionService.encrypt(jsonData, using: key)
            return encryptedPayload.combined
        } catch let error as CryptoError {
            throw RepositoryError.encryptionFailed(error.localizedDescription)
        } catch {
            throw RepositoryError.serializationFailed(error.localizedDescription)
        }
    }

    private func decryptMetadata(_ encryptedData: Data, using key: SymmetricKey) throws -> AttachmentMetadata {
        do {
            let payload = try EncryptedPayload(combined: encryptedData)
            let jsonData = try encryptionService.decrypt(payload, using: key)
            let metadata = try JSONDecoder().decode(AttachmentMetadata.self, from: jsonData)
            return metadata
        } catch let error as CryptoError {
            throw RepositoryError.decryptionFailed(error.localizedDescription)
        } catch {
            throw RepositoryError.deserializationFailed(error.localizedDescription)
        }
    }

    private func mapEntityToModel(
        _ entity: AttachmentEntity,
        personId: UUID,
        primaryKey: SymmetricKey
    ) throws -> Attachment {
        guard let id = entity.id,
              let uploadedAt = entity.uploadedAt,
              let contentHMAC = entity.contentHMAC,
              let encryptedMetadata = entity.encryptedMetadata
        else {
            throw RepositoryError.fetchFailed("AttachmentEntity has nil required fields")
        }

        // Get FMK for decryption
        let fmk = try fmkService.retrieveFMK(familyMemberID: personId.uuidString, primaryKey: primaryKey)

        // Decrypt metadata
        let metadata = try decryptMetadata(encryptedMetadata, using: fmk)

        // Construct Attachment model
        return try Attachment(
            id: id,
            fileName: metadata.fileName,
            mimeType: metadata.mimeType,
            contentHMAC: contentHMAC,
            encryptedSize: Int(entity.encryptedSize),
            thumbnailData: metadata.thumbnailData,
            uploadedAt: uploadedAt
        )
    }
}
