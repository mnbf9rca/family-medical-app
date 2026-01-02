import CoreData
import CryptoKit
import Foundation

/// Protocol for CustomSchema repository operations
protocol CustomSchemaRepositoryProtocol: Sendable {
    /// Save a custom schema (creates or updates)
    ///
    /// On create: Validates schema ID doesn't conflict with built-in schemas
    /// On update: Validates schema evolution rules:
    ///   - Field types cannot change (breaking)
    ///   - Version must be incremented
    ///   - Optional→required allowed (soft-enforced at edit time)
    ///
    /// - Parameters:
    ///   - schema: Schema to save
    ///   - primaryKey: User's primary key for encryption
    /// - Throws: RepositoryError on failure
    func save(_ schema: RecordSchema, primaryKey: SymmetricKey) async throws

    /// Fetch a custom schema by its schema ID
    /// - Parameters:
    ///   - schemaId: The schema's logical ID (e.g., "sports-injury")
    ///   - primaryKey: User's primary key for decryption
    /// - Returns: Schema if found, nil otherwise
    /// - Throws: RepositoryError on failure
    func fetch(schemaId: String, primaryKey: SymmetricKey) async throws -> RecordSchema?

    /// Fetch all custom schemas
    /// - Parameter primaryKey: User's primary key for decryption
    /// - Returns: Array of all custom schemas
    /// - Throws: RepositoryError on failure
    func fetchAll(primaryKey: SymmetricKey) async throws -> [RecordSchema]

    /// Delete a custom schema by its schema ID
    /// - Parameter schemaId: The schema's logical ID
    /// - Throws: RepositoryError on failure
    func delete(schemaId: String) async throws

    /// Check if a custom schema exists
    /// - Parameter schemaId: The schema's logical ID
    /// - Returns: true if schema exists, false otherwise
    /// - Throws: RepositoryError on failure
    func exists(schemaId: String) async throws -> Bool
}

/// Repository for CustomSchema CRUD operations with automatic encryption
///
/// Custom schemas are encrypted at rest using the user's primary key directly
/// (unlike Person/MedicalRecord which use per-family-member keys).
final class CustomSchemaRepository: CustomSchemaRepositoryProtocol, @unchecked Sendable {
    // MARK: - Constants

    /// Built-in schema IDs (O(1) lookup)
    private static let builtInSchemaIds = Set(BuiltInSchemaType.allCases.map(\.rawValue))

    // MARK: - Dependencies

    private let coreDataStack: CoreDataStackProtocol
    private let encryptionService: EncryptionServiceProtocol

    // MARK: - Initialization

    init(
        coreDataStack: CoreDataStackProtocol,
        encryptionService: EncryptionServiceProtocol
    ) {
        self.coreDataStack = coreDataStack
        self.encryptionService = encryptionService
    }

    // MARK: - CustomSchemaRepositoryProtocol

    func save(_ schema: RecordSchema, primaryKey: SymmetricKey) async throws {
        // Validate schema ID doesn't conflict with built-in schemas
        if Self.builtInSchemaIds.contains(schema.id) {
            throw RepositoryError.schemaIdConflictsWithBuiltIn(schema.id)
        }

        try await coreDataStack.performBackgroundTask { context in
            // Check if updating existing schema
            let fetchRequest: NSFetchRequest<CustomSchemaEntity> = CustomSchemaEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "schemaId == %@", schema.id)
            fetchRequest.fetchLimit = 1

            let existingEntity = try context.fetch(fetchRequest).first

            // If updating, validate schema evolution rules
            if let existingEntity {
                try self.validateSchemaEvolution(
                    existing: existingEntity,
                    updated: schema,
                    primaryKey: primaryKey
                )
            }

            // Encrypt schema definition
            let encryptedData = try self.encryptSchema(schema, using: primaryKey)

            // Create or update entity
            let entity: CustomSchemaEntity
            if let existingEntity {
                entity = existingEntity
            } else {
                entity = CustomSchemaEntity(context: context)
                entity.id = UUID()
                entity.schemaId = schema.id
                entity.createdAt = Date()
            }

            // Update fields
            entity.updatedAt = Date()
            entity.version = Int32(schema.version)
            entity.encryptedDefinition = encryptedData

            // Save context
            do {
                try context.save()
            } catch {
                throw RepositoryError.saveFailed("Failed to save CustomSchema: \(error.localizedDescription)")
            }
        }
    }

    func fetch(schemaId: String, primaryKey: SymmetricKey) async throws -> RecordSchema? {
        try await coreDataStack.performBackgroundTask { context in
            let fetchRequest: NSFetchRequest<CustomSchemaEntity> = CustomSchemaEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "schemaId == %@", schemaId)
            fetchRequest.fetchLimit = 1

            guard let entity = try context.fetch(fetchRequest).first else {
                return nil
            }

            return try self.decryptSchema(from: entity, primaryKey: primaryKey)
        }
    }

    func fetchAll(primaryKey: SymmetricKey) async throws -> [RecordSchema] {
        try await coreDataStack.performBackgroundTask { context in
            let fetchRequest: NSFetchRequest<CustomSchemaEntity> = CustomSchemaEntity.fetchRequest()
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]

            let entities = try context.fetch(fetchRequest)
            return try entities.map { try self.decryptSchema(from: $0, primaryKey: primaryKey) }
        }
    }

    func delete(schemaId: String) async throws {
        try await coreDataStack.performBackgroundTask { context in
            let fetchRequest: NSFetchRequest<CustomSchemaEntity> = CustomSchemaEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "schemaId == %@", schemaId)
            fetchRequest.fetchLimit = 1

            guard let entity = try context.fetch(fetchRequest).first else {
                throw RepositoryError.customSchemaNotFound(schemaId)
            }

            context.delete(entity)

            do {
                try context.save()
            } catch {
                throw RepositoryError.deleteFailed("Failed to delete CustomSchema: \(error.localizedDescription)")
            }
        }
    }

    func exists(schemaId: String) async throws -> Bool {
        try await coreDataStack.performBackgroundTask { context in
            let fetchRequest: NSFetchRequest<CustomSchemaEntity> = CustomSchemaEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "schemaId == %@", schemaId)
            fetchRequest.fetchLimit = 1

            let count = try context.count(for: fetchRequest)
            return count > 0
        }
    }

    // MARK: - Schema Evolution Validation

    /// Validate that schema updates follow evolution rules
    private func validateSchemaEvolution(
        existing: CustomSchemaEntity,
        updated: RecordSchema,
        primaryKey: SymmetricKey
    ) throws {
        // Decrypt existing schema for comparison
        let existingSchema = try decryptSchema(from: existing, primaryKey: primaryKey)

        // Check version is incremented
        if updated.version <= existingSchema.version {
            throw RepositoryError.schemaVersionNotIncremented(
                current: existingSchema.version,
                expected: existingSchema.version + 1
            )
        }

        // Build field lookup by ID for existing schema
        let existingFields = Dictionary(uniqueKeysWithValues: existingSchema.fields.map { ($0.id, $0) })
        let updatedFields = Dictionary(uniqueKeysWithValues: updated.fields.map { ($0.id, $0) })

        // Check for breaking changes on existing fields
        for (fieldId, existingField) in existingFields {
            guard let updatedField = updatedFields[fieldId] else {
                // Field was removed - this is allowed (data preserved, just not displayed)
                continue
            }

            // Check field type hasn't changed (would corrupt existing data)
            if updatedField.fieldType != existingField.fieldType {
                throw RepositoryError.fieldTypeChangeNotAllowed(
                    fieldId: fieldId,
                    from: existingField.fieldType,
                    to: updatedField.fieldType
                )
            }

            // Note: optional→required changes ARE allowed (soft enforcement at edit time)
        }

        // Schema evolution uses "soft enforcement" for required fields:
        // - Adding new required fields: Allowed
        // - Changing optional→required: Allowed
        // - Existing records remain valid
        // - User must populate required fields when editing a record
        //
        // Allowed changes:
        // - Adding/removing fields (data preserved for removed fields)
        // - Changing displayName, placeholder, helpText, validation rules
        // - Changing isRequired (enforcement happens at record edit time)
    }

    // MARK: - Encryption/Decryption

    /// Encrypt schema definition
    private func encryptSchema(_ schema: RecordSchema, using key: SymmetricKey) throws -> Data {
        // Encode schema to JSON
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let json: Data
        do {
            json = try encoder.encode(schema)
        } catch {
            throw RepositoryError.serializationFailed(
                "Failed to encode schema: \(error.localizedDescription)"
            )
        }

        // Encrypt JSON
        do {
            let encryptedPayload = try encryptionService.encrypt(json, using: key)
            return encryptedPayload.combined
        } catch {
            throw RepositoryError.encryptionFailed("Failed to encrypt schema: \(error.localizedDescription)")
        }
    }

    /// Decrypt schema from entity
    private func decryptSchema(from entity: CustomSchemaEntity, primaryKey: SymmetricKey) throws -> RecordSchema {
        guard let encryptedData = entity.encryptedDefinition else {
            throw RepositoryError.deserializationFailed("CustomSchemaEntity missing encryptedDefinition")
        }

        // Parse encrypted payload
        let encryptedPayload: EncryptedPayload
        do {
            encryptedPayload = try EncryptedPayload(combined: encryptedData)
        } catch {
            throw RepositoryError.deserializationFailed(
                "Invalid encrypted payload format: \(error.localizedDescription)"
            )
        }

        // Decrypt
        let decryptedJSON: Data
        do {
            decryptedJSON = try encryptionService.decrypt(encryptedPayload, using: primaryKey)
        } catch {
            throw RepositoryError.decryptionFailed("Failed to decrypt schema: \(error.localizedDescription)")
        }

        // Decode JSON
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            return try decoder.decode(RecordSchema.self, from: decryptedJSON)
        } catch {
            throw RepositoryError.deserializationFailed(
                "Failed to decode schema: \(error.localizedDescription)"
            )
        }
    }
}
