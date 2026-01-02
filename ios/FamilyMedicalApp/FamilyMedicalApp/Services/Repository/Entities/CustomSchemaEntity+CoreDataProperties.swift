import CoreData
import Foundation

public extension CustomSchemaEntity {
    @nonobjc
    class func fetchRequest() -> NSFetchRequest<CustomSchemaEntity> {
        NSFetchRequest<CustomSchemaEntity>(entityName: "CustomSchemaEntity")
    }

    @NSManaged var id: UUID
    @NSManaged var schemaId: String
    @NSManaged var createdAt: Date
    @NSManaged var updatedAt: Date
    @NSManaged var version: Int32
    @NSManaged var encryptedDefinition: Data?
}

extension CustomSchemaEntity: Identifiable {}
