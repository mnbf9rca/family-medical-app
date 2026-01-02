import CryptoKit
import Foundation

/// Service for executing schema migrations
///
/// Handles the migration of medical records when a schema changes.
/// The process:
/// 1. Create checkpoint (backup) of affected records
/// 2. For each record: decrypt → transform fields → re-encrypt → save
/// 3. On success: delete checkpoint
/// 4. On failure: restore from checkpoint
protocol SchemaMigrationServiceProtocol: Sendable {
    /// Preview a migration (count affected records, generate warnings)
    ///
    /// - Parameters:
    ///   - migration: The migration to preview
    ///   - personId: The person whose records to migrate
    ///   - primaryKey: The primary key for encryption/decryption
    /// - Returns: A preview of the migration
    /// - Throws: RepositoryError if preview fails
    func previewMigration(
        _ migration: SchemaMigration,
        forPerson personId: UUID,
        primaryKey: SymmetricKey
    ) async throws -> MigrationPreview

    /// Execute a migration
    ///
    /// - Parameters:
    ///   - migration: The migration to execute
    ///   - personId: The person whose records to migrate
    ///   - primaryKey: The primary key for encryption/decryption
    ///   - options: User-selected options for conflict handling
    ///   - progressHandler: Called with progress updates
    /// - Returns: The result of the migration
    /// - Throws: RepositoryError if migration fails (records will be rolled back)
    func executeMigration(
        _ migration: SchemaMigration,
        forPerson personId: UUID,
        primaryKey: SymmetricKey,
        options: MigrationOptions,
        progressHandler: @escaping @Sendable (MigrationProgress) -> Void
    ) async throws -> MigrationResult
}

final class SchemaMigrationService: SchemaMigrationServiceProtocol, @unchecked Sendable {
    // MARK: - Dependencies

    private let medicalRecordRepository: MedicalRecordRepositoryProtocol
    private let recordContentService: RecordContentServiceProtocol
    private let checkpointService: MigrationCheckpointServiceProtocol
    private let fmkService: FamilyMemberKeyServiceProtocol

    // MARK: - Initialization

    init(
        medicalRecordRepository: MedicalRecordRepositoryProtocol,
        recordContentService: RecordContentServiceProtocol,
        checkpointService: MigrationCheckpointServiceProtocol,
        fmkService: FamilyMemberKeyServiceProtocol
    ) {
        self.medicalRecordRepository = medicalRecordRepository
        self.recordContentService = recordContentService
        self.checkpointService = checkpointService
        self.fmkService = fmkService
    }

    // MARK: - SchemaMigrationServiceProtocol

    func previewMigration(
        _ migration: SchemaMigration,
        forPerson personId: UUID,
        primaryKey: SymmetricKey
    ) async throws -> MigrationPreview {
        // Get the FMK for this person
        let fmk = try fmkService.retrieveFMK(
            familyMemberID: personId.uuidString,
            primaryKey: primaryKey
        )

        // Fetch all records for the person
        let allRecords = try await medicalRecordRepository.fetchForPerson(personId: personId)

        // Filter to records matching the schema
        var matchingRecords: [MedicalRecord] = []
        var warnings: [String] = []

        for record in allRecords {
            let content = try recordContentService.decrypt(record.encryptedContent, using: fmk)
            if content.schemaId == migration.schemaId {
                matchingRecords.append(record)

                // Check for potential conversion issues
                for transformation in migration.transformations {
                    if case let .typeConvert(fieldId, toType) = transformation {
                        if let value = content[fieldId] {
                            let converted = FieldValueConverter.convert(value, to: toType)
                            if converted == nil {
                                warnings.append(
                                    "Record \(record.id) has field '\(fieldId)' that cannot be converted to \(toType.displayName)"
                                )
                            }
                        }
                    }
                }
            }
        }

        return MigrationPreview(
            recordCount: matchingRecords.count,
            sampleRecordId: matchingRecords.first?.id,
            warnings: warnings
        )
    }

    func executeMigration(
        _ migration: SchemaMigration,
        forPerson personId: UUID,
        primaryKey: SymmetricKey,
        options: MigrationOptions,
        progressHandler: @escaping @Sendable (MigrationProgress) -> Void
    ) async throws -> MigrationResult {
        let startTime = Date()
        let fmk = try fmkService.retrieveFMK(familyMemberID: personId.uuidString, primaryKey: primaryKey)
        let recordsToMigrate = try await fetchRecordsToMigrate(migration: migration, personId: personId, fmk: fmk)

        progressHandler(MigrationProgress(
            totalRecords: recordsToMigrate.count,
            processedRecords: 0,
            currentRecordId: nil
        ))

        try await checkpointService.createCheckpoint(
            migrationId: migration.id, personId: personId, schemaId: migration.schemaId, records: recordsToMigrate
        )

        let errors = try await processRecords(
            recordsToMigrate, migration: migration, options: options, fmk: fmk, progressHandler: progressHandler
        )

        try await checkpointService.deleteCheckpoint(migrationId: migration.id)

        progressHandler(MigrationProgress(
            totalRecords: recordsToMigrate.count, processedRecords: recordsToMigrate.count, currentRecordId: nil
        ))

        return MigrationResult(
            migration: migration,
            recordsProcessed: recordsToMigrate.count,
            recordsSucceeded: recordsToMigrate.count - errors.count,
            recordsFailed: errors.count,
            errors: errors,
            startTime: startTime,
            endTime: Date()
        )
    }

    private func fetchRecordsToMigrate(
        migration: SchemaMigration,
        personId: UUID,
        fmk: SymmetricKey
    ) async throws -> [MedicalRecord] {
        let allRecords = try await medicalRecordRepository.fetchForPerson(personId: personId)
        var recordsToMigrate: [MedicalRecord] = []
        for record in allRecords {
            let content = try recordContentService.decrypt(record.encryptedContent, using: fmk)
            if content.schemaId == migration.schemaId {
                recordsToMigrate.append(record)
            }
        }
        return recordsToMigrate
    }

    private func processRecords(
        _ records: [MedicalRecord],
        migration: SchemaMigration,
        options: MigrationOptions,
        fmk: SymmetricKey,
        progressHandler: @escaping @Sendable (MigrationProgress) -> Void
    ) async throws -> [MigrationRecordError] {
        var errors: [MigrationRecordError] = []
        var processedCount = 0
        let totalRecords = records.count

        for record in records {
            progressHandler(MigrationProgress(
                totalRecords: totalRecords, processedRecords: processedCount, currentRecordId: record.id
            ))

            do {
                try await migrateRecord(record, migration: migration, options: options, fmk: fmk)
            } catch {
                errors.append(MigrationRecordError(
                    recordId: record.id,
                    fieldId: nil,
                    reason: error.localizedDescription
                ))
            }
            processedCount += 1
        }
        return errors
    }

    // MARK: - Private Helpers

    private func migrateRecord(
        _ record: MedicalRecord,
        migration: SchemaMigration,
        options: MigrationOptions,
        fmk: SymmetricKey
    ) async throws {
        // Decrypt the content
        var content = try recordContentService.decrypt(record.encryptedContent, using: fmk)

        // Apply each transformation
        for transformation in migration.transformations {
            applyTransformation(transformation, to: &content, options: options)
        }

        // Re-encrypt and save
        let encryptedData = try recordContentService.encrypt(content, using: fmk)

        var updatedRecord = record
        updatedRecord.encryptedContent = encryptedData
        updatedRecord.updatedAt = Date()
        updatedRecord.version += 1

        try await medicalRecordRepository.save(updatedRecord)
    }

    private func applyTransformation(
        _ transformation: FieldTransformation,
        to content: inout RecordContent,
        options: MigrationOptions
    ) {
        switch transformation {
        case let .remove(fieldId):
            content.removeField(fieldId)

        case let .typeConvert(fieldId, toType):
            applyTypeConvert(fieldId: fieldId, toType: toType, to: &content)

        case let .merge(fieldId, into):
            applyMerge(sourceFieldId: fieldId, targetFieldId: into, to: &content, options: options)
        }
    }

    private func applyTypeConvert(
        fieldId: String,
        toType: FieldType,
        to content: inout RecordContent
    ) {
        guard let currentValue = content[fieldId] else {
            // Field doesn't exist - nothing to convert
            return
        }

        guard let convertedValue = FieldValueConverter.convert(currentValue, to: toType) else {
            // Conversion failed - keep original value
            return
        }

        // Apply the converted value
        content[fieldId] = convertedValue
    }

    private func applyMerge(
        sourceFieldId: String,
        targetFieldId: String,
        to content: inout RecordContent,
        options: MigrationOptions
    ) {
        // Get source and target values
        let sourceValue = content[sourceFieldId]
        let targetValue = content[targetFieldId]

        // Merge: [source, target] - source merges INTO target
        let values: [FieldValue?] = [sourceValue, targetValue]

        // Merge using the strategy
        guard let mergedValue = FieldValueConverter.merge(values, using: options.mergeStrategy) else {
            // No values to merge
            return
        }

        // Set the merged value on target
        content[targetFieldId] = mergedValue

        // Remove the source field
        content.removeField(sourceFieldId)
    }
}
