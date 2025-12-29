import CoreData
import Foundation

public extension PersonEntity {
    @nonobjc
    class func fetchRequest() -> NSFetchRequest<PersonEntity> {
        NSFetchRequest<PersonEntity>(entityName: "PersonEntity")
    }

    @NSManaged var id: UUID?
    @NSManaged var createdAt: Date?
    @NSManaged var updatedAt: Date?
    @NSManaged var encryptedData: Data?
}

extension PersonEntity: Identifiable {}
