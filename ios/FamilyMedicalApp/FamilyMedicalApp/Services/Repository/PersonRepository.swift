import CoreData
import CryptoKit
import Foundation

/// Protocol for Person repository operations
protocol PersonRepositoryProtocol: Sendable {
    /// Save a person record (creates or updates)
    /// - Parameters:
    ///   - person: Person to save
    ///   - primaryKey: User's primary key for FMK operations
    /// - Throws: RepositoryError on failure
    func save(_ person: Person, primaryKey: SymmetricKey) async throws

    /// Fetch a person by ID
    /// - Parameters:
    ///   - id: Person identifier
    ///   - primaryKey: User's primary key for FMK operations
    /// - Returns: Person if found, nil otherwise
    /// - Throws: RepositoryError on failure
    func fetch(id: UUID, primaryKey: SymmetricKey) async throws -> Person?

    /// Fetch all persons
    /// - Parameter primaryKey: User's primary key for FMK operations
    /// - Returns: Array of all persons
    /// - Throws: RepositoryError on failure
    func fetchAll(primaryKey: SymmetricKey) async throws -> [Person]

    /// Delete a person by ID
    /// - Parameter id: Person identifier
    /// - Throws: RepositoryError on failure
    func delete(id: UUID) async throws

    /// Check if a person exists
    /// - Parameter id: Person identifier
    /// - Returns: true if person exists, false otherwise
    /// - Throws: RepositoryError on failure
    func exists(id: UUID) async throws -> Bool
}

/// Repository for Person CRUD operations with automatic encryption
final class PersonRepository: PersonRepositoryProtocol, @unchecked Sendable {
    // MARK: - Dependencies

    private let coreDataStack: CoreDataStackProtocol
    private let encryptionService: EncryptionServiceProtocol
    private let fmkService: FamilyMemberKeyServiceProtocol

    // MARK: - Initialization

    init(
        coreDataStack: CoreDataStackProtocol,
        encryptionService: EncryptionServiceProtocol,
        fmkService: FamilyMemberKeyServiceProtocol
    ) {
        self.coreDataStack = coreDataStack
        self.encryptionService = encryptionService
        self.fmkService = fmkService
    }

    // MARK: - PersonRepositoryProtocol

    func save(_ person: Person, primaryKey: SymmetricKey) async throws {
        try await coreDataStack.performBackgroundTask { context in
            // Ensure FMK exists for this person
            let fmk = try self.ensureFMK(for: person.id.uuidString, primaryKey: primaryKey)

            // Encrypt sensitive fields
            let encryptedData = try self.encryptPersonData(person, using: fmk)

            // Fetch or create entity
            let entity: PersonEntity
            let fetchRequest: NSFetchRequest<PersonEntity> = PersonEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", person.id as CVarArg)
            fetchRequest.fetchLimit = 1

            if let existingEntity = try context.fetch(fetchRequest).first {
                entity = existingEntity
            } else {
                entity = PersonEntity(context: context)
                entity.id = person.id
                entity.createdAt = person.createdAt
            }

            // Update plaintext fields
            entity.updatedAt = person.updatedAt

            // Update encrypted data
            entity.encryptedData = encryptedData

            // Save context
            do {
                try context.save()
            } catch {
                throw RepositoryError.saveFailed("Failed to save Person: \(error.localizedDescription)")
            }
        }
    }

    func fetch(id: UUID, primaryKey: SymmetricKey) async throws -> Person? {
        try await coreDataStack.performBackgroundTask { context in
            let fetchRequest: NSFetchRequest<PersonEntity> = PersonEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            fetchRequest.fetchLimit = 1

            guard let entity = try context.fetch(fetchRequest).first else {
                return nil
            }

            return try self.decryptPerson(from: entity, primaryKey: primaryKey)
        }
    }

    func fetchAll(primaryKey: SymmetricKey) async throws -> [Person] {
        try await coreDataStack.performBackgroundTask { context in
            let fetchRequest: NSFetchRequest<PersonEntity> = PersonEntity.fetchRequest()
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]

            let entities = try context.fetch(fetchRequest)
            return try entities.map { try self.decryptPerson(from: $0, primaryKey: primaryKey) }
        }
    }

    func delete(id: UUID) async throws {
        try await coreDataStack.performBackgroundTask { context in
            let fetchRequest: NSFetchRequest<PersonEntity> = PersonEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            fetchRequest.fetchLimit = 1

            guard let entity = try context.fetch(fetchRequest).first else {
                throw RepositoryError.entityNotFound("Person not found: \(id)")
            }

            context.delete(entity)

            do {
                try context.save()
            } catch {
                throw RepositoryError.deleteFailed("Failed to delete Person: \(error.localizedDescription)")
            }
        }
    }

    func exists(id: UUID) async throws -> Bool {
        try await coreDataStack.performBackgroundTask { context in
            let fetchRequest: NSFetchRequest<PersonEntity> = PersonEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            fetchRequest.fetchLimit = 1

            let count = try context.count(for: fetchRequest)
            return count > 0
        }
    }

    // MARK: - Private Helpers

    /// Ensure FMK exists for a person (creates if needed)
    private func ensureFMK(for personID: String, primaryKey: SymmetricKey) throws -> SymmetricKey {
        do {
            // Try to retrieve existing FMK
            return try fmkService.retrieveFMK(familyMemberID: personID, primaryKey: primaryKey)
        } catch KeychainError.keyNotFound {
            // Generate new FMK for this person
            let fmk = fmkService.generateFMK()
            do {
                try fmkService.storeFMK(fmk, familyMemberID: personID, primaryKey: primaryKey)
                return fmk
            } catch {
                throw RepositoryError.keyNotAvailable("Failed to store FMK: \(error.localizedDescription)")
            }
        } catch {
            throw RepositoryError.keyNotAvailable("Failed to retrieve FMK: \(error.localizedDescription)")
        }
    }

    /// Encrypt Person's sensitive fields
    private func encryptPersonData(_ person: Person, using fmk: SymmetricKey) throws -> Data {
        // Create encrypted payload from sensitive fields
        let encryptedFields = PersonEncryptedData(
            name: person.name,
            dateOfBirth: person.dateOfBirth,
            labels: person.labels,
            notes: person.notes
        )

        // Encode to JSON
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let json = try? encoder.encode(encryptedFields) else {
            throw RepositoryError.serializationFailed("Failed to encode Person encrypted fields")
        }

        // Encrypt JSON
        do {
            let encryptedPayload = try encryptionService.encrypt(json, using: fmk)
            return encryptedPayload.combined
        } catch {
            throw RepositoryError.encryptionFailed("Failed to encrypt Person data: \(error.localizedDescription)")
        }
    }

    /// Decrypt PersonEntity to Person model
    private func decryptPerson(from entity: PersonEntity, primaryKey: SymmetricKey) throws -> Person {
        guard let id = entity.id,
              let createdAt = entity.createdAt,
              let updatedAt = entity.updatedAt,
              let encryptedData = entity.encryptedData
        else {
            throw RepositoryError.deserializationFailed("PersonEntity missing required fields")
        }

        // Retrieve FMK
        let fmk: SymmetricKey
        do {
            fmk = try fmkService.retrieveFMK(familyMemberID: id.uuidString, primaryKey: primaryKey)
        } catch {
            throw RepositoryError
                .keyNotAvailable("Failed to retrieve FMK for person \(id): \(error.localizedDescription)")
        }

        // Decrypt encrypted data
        let encryptedPayload: EncryptedPayload
        do {
            encryptedPayload = try EncryptedPayload(combined: encryptedData)
        } catch {
            throw RepositoryError
                .deserializationFailed("Invalid encrypted payload format: \(error.localizedDescription)")
        }

        let decryptedJSON: Data
        do {
            decryptedJSON = try encryptionService.decrypt(encryptedPayload, using: fmk)
        } catch {
            throw RepositoryError.decryptionFailed("Failed to decrypt Person data: \(error.localizedDescription)")
        }

        // Decode JSON
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let encryptedFields: PersonEncryptedData
        do {
            encryptedFields = try decoder.decode(PersonEncryptedData.self, from: decryptedJSON)
        } catch {
            throw RepositoryError
                .deserializationFailed("Failed to decode Person encrypted fields: \(error.localizedDescription)")
        }

        // Reconstruct Person model
        do {
            return try Person(
                id: id,
                name: encryptedFields.name,
                dateOfBirth: encryptedFields.dateOfBirth,
                labels: encryptedFields.labels,
                notes: encryptedFields.notes,
                createdAt: createdAt,
                updatedAt: updatedAt
            )
        } catch {
            throw RepositoryError.validationFailed("Failed to reconstruct Person: \(error.localizedDescription)")
        }
    }
}

// MARK: - PersonEncryptedData

/// Encrypted portion of Person data
private struct PersonEncryptedData: Codable {
    let name: String
    let dateOfBirth: Date?
    let labels: [String]
    let notes: String?
}
