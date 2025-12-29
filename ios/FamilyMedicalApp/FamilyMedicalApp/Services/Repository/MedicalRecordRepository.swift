import CoreData
import Foundation

/// Repository for managing encrypted medical records
///
/// Handles CRUD operations for MedicalRecord entities. Unlike PersonRepository,
/// this repository does NOT perform encryption - it expects the caller to provide
/// pre-encrypted content via RecordContentService.
///
/// Flow:
/// 1. Caller encrypts RecordContent → encrypted Data (using RecordContentService)
/// 2. Repository stores MedicalRecord with encrypted Data as-is
/// 3. Repository retrieves MedicalRecord with encrypted Data
/// 4. Caller decrypts encrypted Data → RecordContent (using RecordContentService)
protocol MedicalRecordRepositoryProtocol: Sendable {
    /// Save a medical record (insert or update)
    ///
    /// - Parameter record: The medical record to save (with pre-encrypted content)
    /// - Throws: RepositoryError if save fails
    func save(_ record: MedicalRecord) async throws

    /// Fetch a medical record by ID
    ///
    /// - Parameter id: The record ID
    /// - Returns: The medical record if found, nil otherwise
    /// - Throws: RepositoryError if fetch fails
    func fetch(id: UUID) async throws -> MedicalRecord?

    /// Fetch all medical records for a person
    ///
    /// - Parameter personId: The person's ID
    /// - Returns: Array of medical records (may be empty)
    /// - Throws: RepositoryError if fetch fails
    func fetchForPerson(personId: UUID) async throws -> [MedicalRecord]

    /// Delete a medical record by ID
    ///
    /// - Parameter id: The record ID to delete
    /// - Throws: RepositoryError if record not found or delete fails
    func delete(id: UUID) async throws

    /// Check if a record exists
    ///
    /// - Parameter id: The record ID
    /// - Returns: true if record exists, false otherwise
    /// - Throws: RepositoryError if check fails
    func exists(id: UUID) async throws -> Bool
}

final class MedicalRecordRepository: MedicalRecordRepositoryProtocol, @unchecked Sendable {
    // MARK: - Dependencies

    private let coreDataStack: CoreDataStackProtocol

    // MARK: - Initialization

    init(coreDataStack: CoreDataStackProtocol) {
        self.coreDataStack = coreDataStack
    }

    // MARK: - MedicalRecordRepositoryProtocol

    func save(_ record: MedicalRecord) async throws {
        let context = coreDataStack.viewContext

        try await context.perform {
            // Check if entity already exists
            let request: NSFetchRequest<MedicalRecordEntity> = MedicalRecordEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", record.id as CVarArg)
            request.fetchLimit = 1

            let existing = try context.fetch(request).first

            let entity = existing ?? MedicalRecordEntity(context: context)

            // Update entity properties
            entity.id = record.id
            entity.personId = record.personId

            // Preserve original creation time on updates; only set on insert
            if existing == nil {
                entity.createdAt = record.createdAt
            }

            entity.updatedAt = record.updatedAt
            entity.version = Int32(record.version)
            entity.previousVersionId = record.previousVersionId
            entity.encryptedContent = record.encryptedContent

            // Save context
            do {
                try context.save()
            } catch {
                throw RepositoryError.saveFailed(error.localizedDescription)
            }
        }
    }

    func fetch(id: UUID) async throws -> MedicalRecord? {
        let context = coreDataStack.viewContext

        return try await context.perform {
            let request: NSFetchRequest<MedicalRecordEntity> = MedicalRecordEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1

            guard let entity = try context.fetch(request).first else {
                return nil
            }

            return try self.mapEntityToModel(entity)
        }
    }

    func fetchForPerson(personId: UUID) async throws -> [MedicalRecord] {
        let context = coreDataStack.viewContext

        return try await context.perform {
            let request: NSFetchRequest<MedicalRecordEntity> = MedicalRecordEntity.fetchRequest()
            request.predicate = NSPredicate(format: "personId == %@", personId as CVarArg)
            request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]

            let entities = try context.fetch(request)

            return try entities.map { try self.mapEntityToModel($0) }
        }
    }

    func delete(id: UUID) async throws {
        let context = coreDataStack.viewContext

        try await context.perform {
            let request: NSFetchRequest<MedicalRecordEntity> = MedicalRecordEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1

            guard let entity = try context.fetch(request).first else {
                throw RepositoryError.entityNotFound("MedicalRecord with ID \(id)")
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
            let request: NSFetchRequest<NSFetchRequestResult> = MedicalRecordEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.resultType = .countResultType

            let count = try context.count(for: request)
            return count > 0
        }
    }

    // MARK: - Private Helpers

    private func mapEntityToModel(_ entity: MedicalRecordEntity) throws -> MedicalRecord {
        guard let id = entity.id,
              let personId = entity.personId,
              let createdAt = entity.createdAt,
              let updatedAt = entity.updatedAt,
              let encryptedContent = entity.encryptedContent
        else {
            throw RepositoryError.fetchFailed("MedicalRecordEntity has nil required fields")
        }

        return MedicalRecord(
            id: id,
            personId: personId,
            encryptedContent: encryptedContent,
            createdAt: createdAt,
            updatedAt: updatedAt,
            version: Int(entity.version),
            previousVersionId: entity.previousVersionId
        )
    }
}
