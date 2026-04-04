import CoreData
import Foundation

public extension ProviderEntity {
    @nonobjc
    class func fetchRequest() -> NSFetchRequest<ProviderEntity> {
        NSFetchRequest<ProviderEntity>(entityName: "ProviderEntity")
    }

    @NSManaged var id: UUID?
    @NSManaged var personId: UUID?
    @NSManaged var encryptedContent: Data?
    @NSManaged var createdAt: Date?
    @NSManaged var updatedAt: Date?
    @NSManaged var version: Int32
}

extension ProviderEntity: Identifiable {}
