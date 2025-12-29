import CoreData
import Foundation

public extension AttachmentEntity {
    @nonobjc
    class func fetchRequest() -> NSFetchRequest<AttachmentEntity> {
        NSFetchRequest<AttachmentEntity>(entityName: "AttachmentEntity")
    }

    @NSManaged var id: UUID?
    @NSManaged var uploadedAt: Date?
    @NSManaged var contentHMAC: Data?
    @NSManaged var encryptedSize: Int64
    @NSManaged var encryptedMetadata: Data?
}

extension AttachmentEntity: Identifiable {}
