import CoreData
import CryptoKit
import Foundation

/// Protocol for CustomSchema repository operations
///
/// Schemas are stored per-Person and encrypted with the Person's FamilyMemberKey.
/// This allows schemas to travel with Person data when shared between devices/users.
protocol CustomSchemaRepositoryProtocol: Sendable {
    /// Save a schema for a Person (creates or updates)
    ///
    /// On update: Validates schema evolution rules:
    ///   - Field types cannot change (breaking)
    ///   - Version must be incremented
    ///   - Optional→required allowed (soft-enforced at edit time)
    ///
    /// - Parameters:
    ///   - schema: Schema to save
    ///   - personId: UUID of the Person who owns this schema
    ///   - familyMemberKey: Person's FMK for encryption
    /// - Throws: RepositoryError on failure
    func save(_ schema: RecordSchema, forPerson personId: UUID, familyMemberKey: SymmetricKey) async throws

    /// Fetch a schema by its schema ID for a specific Person
    /// - Parameters:
    ///   - schemaId: The schema's logical ID (e.g., "vaccine", "sports-injury")
    ///   - personId: UUID of the Person who owns this schema
    ///   - familyMemberKey: Person's FMK for decryption
    /// - Returns: Schema if found, nil otherwise
    /// - Throws: RepositoryError on failure
    func fetch(schemaId: String, forPerson personId: UUID, familyMemberKey: SymmetricKey) async throws -> RecordSchema?

    /// Fetch all schemas for a Person
    /// - Parameters:
    ///   - personId: UUID of the Person who owns the schemas
    ///   - familyMemberKey: Person's FMK for decryption
    /// - Returns: Array of all schemas for this Person
    /// - Throws: RepositoryError on failure
    func fetchAll(forPerson personId: UUID, familyMemberKey: SymmetricKey) async throws -> [RecordSchema]

    /// Delete a schema for a Person
    /// - Parameters:
    ///   - schemaId: The schema's logical ID
    ///   - personId: UUID of the Person who owns this schema
    /// - Throws: RepositoryError on failure
    func delete(schemaId: String, forPerson personId: UUID) async throws

    /// Check if a schema exists for a Person
    /// - Parameters:
    ///   - schemaId: The schema's logical ID
    ///   - personId: UUID of the Person who owns this schema
    /// - Returns: true if schema exists, false otherwise
    /// - Throws: RepositoryError on failure
    func exists(schemaId: String, forPerson personId: UUID) async throws -> Bool
}

/// Repository for schema CRUD operations with automatic encryption
///
/// Schemas are stored per-Person and encrypted with the Person's FamilyMemberKey (FMK).
/// This enables schemas to travel with Person data when shared between users/devices.
///
/// Both built-in schemas (seeded at Person creation) and user-created custom schemas
/// are stored in the same table, distinguished by their schemaId and isBuiltIn flag.
final class CustomSchemaRepository: CustomSchemaRepositoryProtocol, @unchecked Sendable {
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

    func save(_ schema: RecordSchema, forPerson personId: UUID, familyMemberKey: SymmetricKey) async throws {
        try await coreDataStack.performBackgroundTask { context in
            // Check if updating existing schema for this Person
            let fetchRequest: NSFetchRequest<CustomSchemaEntity> = CustomSchemaEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(
                format: "personId == %@ AND schemaId == %@",
                personId as CVarArg,
                schema.id
            )
            fetchRequest.fetchLimit = 1

            let existingEntity = try context.fetch(fetchRequest).first

            // If updating, validate schema evolution rules
            if let existingEntity {
                try self.validateSchemaEvolution(
                    existing: existingEntity,
                    updated: schema,
                    familyMemberKey: familyMemberKey
                )
            }

            // Encrypt schema definition
            let encryptedData = try self.encryptSchema(schema, using: familyMemberKey)

            // Create or update entity
            let entity: CustomSchemaEntity
            if let existingEntity {
                entity = existingEntity
            } else {
                entity = CustomSchemaEntity(context: context)
                entity.id = UUID()
                entity.personId = personId
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
                throw RepositoryError.saveFailed("Failed to save schema: \(error.localizedDescription)")
            }
        }
    }

    func fetch(
        schemaId: String,
        forPerson personId: UUID,
        familyMemberKey: SymmetricKey
    ) async throws -> RecordSchema? {
        try await coreDataStack.performBackgroundTask { context in
            let fetchRequest: NSFetchRequest<CustomSchemaEntity> = CustomSchemaEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(
                format: "personId == %@ AND schemaId == %@",
                personId as CVarArg,
                schemaId
            )
            fetchRequest.fetchLimit = 1

            guard let entity = try context.fetch(fetchRequest).first else {
                return nil
            }

            return try self.decryptSchema(from: entity, familyMemberKey: familyMemberKey)
        }
    }

    func fetchAll(forPerson personId: UUID, familyMemberKey: SymmetricKey) async throws -> [RecordSchema] {
        try await coreDataStack.performBackgroundTask { context in
            let fetchRequest: NSFetchRequest<CustomSchemaEntity> = CustomSchemaEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "personId == %@", personId as CVarArg)
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]

            let entities = try context.fetch(fetchRequest)
            return try entities.map { try self.decryptSchema(from: $0, familyMemberKey: familyMemberKey) }
        }
    }

    func delete(schemaId: String, forPerson personId: UUID) async throws {
        try await coreDataStack.performBackgroundTask { context in
            let fetchRequest: NSFetchRequest<CustomSchemaEntity> = CustomSchemaEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(
                format: "personId == %@ AND schemaId == %@",
                personId as CVarArg,
                schemaId
            )
            fetchRequest.fetchLimit = 1

            guard let entity = try context.fetch(fetchRequest).first else {
                throw RepositoryError.customSchemaNotFound(schemaId)
            }

            context.delete(entity)

            do {
                try context.save()
            } catch {
                throw RepositoryError.deleteFailed("Failed to delete schema: \(error.localizedDescription)")
            }
        }
    }

    func exists(schemaId: String, forPerson personId: UUID) async throws -> Bool {
        try await coreDataStack.performBackgroundTask { context in
            let fetchRequest: NSFetchRequest<CustomSchemaEntity> = CustomSchemaEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(
                format: "personId == %@ AND schemaId == %@",
                personId as CVarArg,
                schemaId
            )
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
        familyMemberKey: SymmetricKey
    ) throws {
        // Decrypt existing schema for comparison
        let existingSchema = try decryptSchema(from: existing, familyMemberKey: familyMemberKey)

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
                    fieldId: fieldId.uuidString,
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
    private func decryptSchema(from entity: CustomSchemaEntity, familyMemberKey: SymmetricKey) throws -> RecordSchema {
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
            decryptedJSON = try encryptionService.decrypt(encryptedPayload, using: familyMemberKey)
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
