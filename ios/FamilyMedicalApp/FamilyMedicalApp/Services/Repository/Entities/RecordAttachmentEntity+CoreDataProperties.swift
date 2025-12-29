import CoreData
import Foundation

public extension RecordAttachmentEntity {
    @nonobjc
    class func fetchRequest() -> NSFetchRequest<RecordAttachmentEntity> {
        NSFetchRequest<RecordAttachmentEntity>(entityName: "RecordAttachmentEntity")
    }

    @NSManaged var recordId: UUID?
    @NSManaged var attachmentId: UUID?
}

extension RecordAttachmentEntity: Identifiable {}
