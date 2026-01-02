import CoreData
import Foundation

/// Service for creating and restoring migration checkpoints
///
/// Checkpoints provide rollback capability for schema migrations.
/// Before a migration starts, the affected records are backed up.
/// If the migration fails, the checkpoint can be restored.
protocol MigrationCheckpointServiceProtocol: Sendable {
    /// Create a checkpoint by backing up records
    ///
    /// - Parameters:
    ///   - migrationId: The ID of the migration being performed
    ///   - personId: The person whose records are being migrated
    ///   - schemaId: The schema being migrated
    ///   - records: The records to back up
    /// - Throws: RepositoryError if checkpoint creation fails
    func createCheckpoint(
        migrationId: UUID,
        personId: UUID,
        schemaId: String,
        records: [MedicalRecord]
    ) async throws

    /// Restore records from a checkpoint
    ///
    /// This overwrites the current records with the backed-up versions.
    ///
    /// - Parameter migrationId: The migration ID to restore from
    /// - Returns: The restored records
    /// - Throws: RepositoryError if checkpoint not found or restore fails
    func restoreCheckpoint(migrationId: UUID) async throws -> [MedicalRecord]

    /// Delete a checkpoint (after successful migration)
    ///
    /// - Parameter migrationId: The migration ID to delete
    /// - Throws: RepositoryError if deletion fails
    func deleteCheckpoint(migrationId: UUID) async throws

    /// Check if an active checkpoint exists for a migration
    ///
    /// - Parameter migrationId: The migration ID to check
    /// - Returns: True if a checkpoint exists
    /// - Throws: RepositoryError if check fails
    func hasCheckpoint(migrationId: UUID) async throws -> Bool
}

final class MigrationCheckpointService: MigrationCheckpointServiceProtocol, @unchecked Sendable {
    // MARK: - Dependencies

    private let coreDataStack: CoreDataStackProtocol
    private let medicalRecordRepository: MedicalRecordRepositoryProtocol

    // MARK: - Initialization

    init(
        coreDataStack: CoreDataStackProtocol,
        medicalRecordRepository: MedicalRecordRepositoryProtocol
    ) {
        self.coreDataStack = coreDataStack
        self.medicalRecordRepository = medicalRecordRepository
    }

    // MARK: - MigrationCheckpointServiceProtocol

    func createCheckpoint(
        migrationId: UUID,
        personId: UUID,
        schemaId: String,
        records: [MedicalRecord]
    ) async throws {
        let context = coreDataStack.viewContext

        // Serialize records to JSON
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let recordData: Data
        do {
            recordData = try encoder.encode(records)
        } catch {
            throw RepositoryError
                .serializationFailed("Failed to serialize records for checkpoint: \(error.localizedDescription)")
        }

        try await context.perform {
            // Check if checkpoint already exists
            let request: NSFetchRequest<MigrationCheckpointEntity> = MigrationCheckpointEntity.fetchRequest()
            request.predicate = NSPredicate(format: "migrationId == %@", migrationId as CVarArg)
            request.fetchLimit = 1

            if try context.fetch(request).first != nil {
                throw RepositoryError.checkpointAlreadyExists(migrationId)
            }

            // Create new checkpoint
            let entity = MigrationCheckpointEntity(context: context)
            entity.id = UUID()
            entity.migrationId = migrationId
            entity.personId = personId
            entity.schemaId = schemaId
            entity.createdAt = Date()
            entity.recordBackups = recordData

            do {
                try context.save()
            } catch {
                throw RepositoryError.saveFailed("Failed to save checkpoint: \(error.localizedDescription)")
            }
        }
    }

    func restoreCheckpoint(migrationId: UUID) async throws -> [MedicalRecord] {
        let context = coreDataStack.viewContext

        // Fetch the checkpoint
        let checkpoint = try await context.perform {
            let request: NSFetchRequest<MigrationCheckpointEntity> = MigrationCheckpointEntity.fetchRequest()
            request.predicate = NSPredicate(format: "migrationId == %@", migrationId as CVarArg)
            request.fetchLimit = 1

            guard let entity = try context.fetch(request).first else {
                throw RepositoryError.checkpointNotFound(migrationId)
            }

            return entity
        }

        // Deserialize the backed-up records
        let recordData = checkpoint.recordBackups

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let records: [MedicalRecord]
        do {
            records = try decoder.decode([MedicalRecord].self, from: recordData)
        } catch {
            throw RepositoryError
                .deserializationFailed("Failed to deserialize checkpoint records: \(error.localizedDescription)")
        }

        // Restore each record
        for record in records {
            try await medicalRecordRepository.save(record)
        }

        return records
    }

    func deleteCheckpoint(migrationId: UUID) async throws {
        let context = coreDataStack.viewContext

        try await context.perform {
            let request: NSFetchRequest<MigrationCheckpointEntity> = MigrationCheckpointEntity.fetchRequest()
            request.predicate = NSPredicate(format: "migrationId == %@", migrationId as CVarArg)
            request.fetchLimit = 1

            guard let entity = try context.fetch(request).first else {
                // Not found is not an error - checkpoint may have already been deleted
                return
            }

            context.delete(entity)

            do {
                try context.save()
            } catch {
                throw RepositoryError.deleteFailed("Failed to delete checkpoint: \(error.localizedDescription)")
            }
        }
    }

    func hasCheckpoint(migrationId: UUID) async throws -> Bool {
        let context = coreDataStack.viewContext

        return try await context.perform {
            let request: NSFetchRequest<NSFetchRequestResult> = MigrationCheckpointEntity.fetchRequest()
            request.predicate = NSPredicate(format: "migrationId == %@", migrationId as CVarArg)
            request.resultType = .countResultType

            let count = try context.count(for: request)
            return count > 0
        }
    }
}
