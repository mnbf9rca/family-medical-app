import CoreData
import Foundation

public extension MigrationCheckpointEntity {
    @nonobjc
    class func fetchRequest() -> NSFetchRequest<MigrationCheckpointEntity> {
        NSFetchRequest<MigrationCheckpointEntity>(entityName: "MigrationCheckpointEntity")
    }

    @NSManaged var id: UUID
    @NSManaged var migrationId: UUID
    @NSManaged var personId: UUID
    @NSManaged var schemaId: String
    @NSManaged var createdAt: Date
    @NSManaged var recordBackups: Data
}

extension MigrationCheckpointEntity: Identifiable {}
