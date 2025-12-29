import CoreData
import Foundation

public extension MedicalRecordEntity {
    @nonobjc
    class func fetchRequest() -> NSFetchRequest<MedicalRecordEntity> {
        NSFetchRequest<MedicalRecordEntity>(entityName: "MedicalRecordEntity")
    }

    @NSManaged var id: UUID?
    @NSManaged var personId: UUID?
    @NSManaged var createdAt: Date?
    @NSManaged var updatedAt: Date?
    @NSManaged var version: Int32
    @NSManaged var previousVersionId: UUID?
    @NSManaged var encryptedContent: Data?
}

extension MedicalRecordEntity: Identifiable {}
