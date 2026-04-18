import CoreData
import CryptoKit
import Foundation

/// Protocol for Provider repository operations
protocol ProviderRepositoryProtocol: Sendable {
    /// Save a provider record (creates or updates)
    /// - Parameters:
    ///   - provider: Provider to save
    ///   - personId: The person this provider belongs to
    ///   - primaryKey: User's primary key for FMK operations
    /// - Throws: RepositoryError on failure
    func save(_ provider: Provider, personId: UUID, primaryKey: SymmetricKey) async throws

    /// Fetch a provider by ID
    /// - Parameters:
    ///   - id: Provider identifier
    ///   - personId: The person this provider belongs to
    ///   - primaryKey: User's primary key for FMK operations
    /// - Returns: Provider if found, nil otherwise
    /// - Throws: RepositoryError on failure
    func fetch(byId id: UUID, personId: UUID, primaryKey: SymmetricKey) async throws -> Provider?

    /// Fetch all providers for a person
    /// - Parameters:
    ///   - personId: The person's ID
    ///   - primaryKey: User's primary key for FMK operations
    /// - Returns: Array of all providers for this person
    /// - Throws: RepositoryError on failure
    func fetchAll(forPerson personId: UUID, primaryKey: SymmetricKey) async throws -> [Provider]

    /// Delete a provider by ID
    /// - Parameter id: Provider identifier
    /// - Throws: RepositoryError on failure
    func delete(id: UUID) async throws

    /// Search providers for a person by name or organization (case-insensitive)
    /// - Parameters:
    ///   - query: Search term
    ///   - personId: The person's ID
    ///   - primaryKey: User's primary key for FMK operations
    /// - Returns: Providers whose name or organization contains the query
    /// - Throws: RepositoryError on failure
    func search(query: String, forPerson personId: UUID, primaryKey: SymmetricKey) async throws -> [Provider]
}

/// Repository for Provider CRUD operations with automatic encryption
final class ProviderRepository: ProviderRepositoryProtocol, @unchecked Sendable {
    // MARK: - Dependencies

    private let coreDataStack: CoreDataStackProtocol
    private let encryptionService: EncryptionServiceProtocol
    private let fmkService: FamilyMemberKeyServiceProtocol
    private let logger: TracingCategoryLogger

    // MARK: - Initialization

    init(
        coreDataStack: CoreDataStackProtocol,
        encryptionService: EncryptionServiceProtocol,
        fmkService: FamilyMemberKeyServiceProtocol,
        logger: CategoryLoggerProtocol? = nil
    ) {
        self.coreDataStack = coreDataStack
        self.encryptionService = encryptionService
        self.fmkService = fmkService
        self.logger = TracingCategoryLogger(
            wrapping: logger ?? LoggingService.shared.logger(category: .storage)
        )
    }

    // MARK: - ProviderRepositoryProtocol

    func save(_ provider: Provider, personId: UUID, primaryKey: SymmetricKey) async throws {
        let start = ContinuousClock.now
        logger.entry("save", "providerId=\(provider.id), personId=\(personId)")

        do {
            try await coreDataStack.performBackgroundTask { context in
                let fmk = try self.ensureFMK(for: personId.uuidString, primaryKey: primaryKey)
                let encryptedData = try self.encryptProviderData(provider, using: fmk)

                let fetchRequest: NSFetchRequest<ProviderEntity> = ProviderEntity.fetchRequest()
                fetchRequest.predicate = NSPredicate(
                    format: "id == %@ AND personId == %@",
                    provider.id as CVarArg,
                    personId as CVarArg
                )
                fetchRequest.fetchLimit = 1

                let entity: ProviderEntity
                if let existing = try context.fetch(fetchRequest).first {
                    entity = existing
                } else {
                    entity = ProviderEntity(context: context)
                    entity.id = provider.id
                    entity.personId = personId
                    entity.createdAt = provider.createdAt
                }

                entity.updatedAt = provider.updatedAt
                entity.version = Int32(provider.version)
                entity.encryptedContent = encryptedData

                do {
                    try context.save()
                } catch {
                    throw RepositoryError.saveFailed("Failed to save Provider: \(error.localizedDescription)")
                }
            }
            logger.exit("save", duration: ContinuousClock.now - start)
        } catch {
            logger.exitWithError("save", error: error, duration: ContinuousClock.now - start)
            throw error
        }
    }

    func fetch(byId id: UUID, personId: UUID, primaryKey: SymmetricKey) async throws -> Provider? {
        let start = ContinuousClock.now
        logger.entry("fetch", "providerId=\(id), personId=\(personId)")

        do {
            let result = try await coreDataStack.performBackgroundTask { context in
                let fetchRequest: NSFetchRequest<ProviderEntity> = ProviderEntity.fetchRequest()
                fetchRequest.predicate = NSPredicate(
                    format: "id == %@ AND personId == %@",
                    id as CVarArg,
                    personId as CVarArg
                )
                fetchRequest.fetchLimit = 1

                guard let entity = try context.fetch(fetchRequest).first else {
                    return nil as Provider?
                }

                return try self.decryptProvider(from: entity, personId: personId, primaryKey: primaryKey)
            }
            logger.exit("fetch", duration: ContinuousClock.now - start)
            return result
        } catch {
            logger.exitWithError("fetch", error: error, duration: ContinuousClock.now - start)
            throw error
        }
    }

    func fetchAll(forPerson personId: UUID, primaryKey: SymmetricKey) async throws -> [Provider] {
        let start = ContinuousClock.now
        logger.entry("fetchAll", "personId=\(personId)")

        do {
            let result = try await coreDataStack.performBackgroundTask { context in
                let fetchRequest: NSFetchRequest<ProviderEntity> = ProviderEntity.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "personId == %@", personId as CVarArg)
                fetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]

                let entities = try context.fetch(fetchRequest)
                return try entities.map {
                    try self.decryptProvider(from: $0, personId: personId, primaryKey: primaryKey)
                }
            }
            logger.exit("fetchAll", duration: ContinuousClock.now - start)
            return result
        } catch {
            logger.exitWithError("fetchAll", error: error, duration: ContinuousClock.now - start)
            throw error
        }
    }

    func delete(id: UUID) async throws {
        let start = ContinuousClock.now
        logger.entry("delete", "providerId=\(id)")

        do {
            try await coreDataStack.performBackgroundTask { context in
                let fetchRequest: NSFetchRequest<ProviderEntity> = ProviderEntity.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
                fetchRequest.fetchLimit = 1

                guard let entity = try context.fetch(fetchRequest).first else {
                    throw RepositoryError.entityNotFound("Provider not found: \(id)")
                }

                context.delete(entity)

                do {
                    try context.save()
                } catch {
                    throw RepositoryError.deleteFailed("Failed to delete Provider: \(error.localizedDescription)")
                }
            }
            logger.exit("delete", duration: ContinuousClock.now - start)
        } catch {
            logger.exitWithError("delete", error: error, duration: ContinuousClock.now - start)
            throw error
        }
    }

    func search(query: String, forPerson personId: UUID, primaryKey: SymmetricKey) async throws -> [Provider] {
        let start = ContinuousClock.now
        logger.entry("search", "personId=\(personId)")

        do {
            let all = try await fetchAll(forPerson: personId, primaryKey: primaryKey)
            let lowercasedQuery = query.lowercased()
            let result = all.filter { provider in
                let nameMatch = provider.name?.lowercased().contains(lowercasedQuery) ?? false
                let orgMatch = provider.organization?.lowercased().contains(lowercasedQuery) ?? false
                return nameMatch || orgMatch
            }
            logger.exit("search", duration: ContinuousClock.now - start)
            return result
        } catch {
            logger.exitWithError("search", error: error, duration: ContinuousClock.now - start)
            throw error
        }
    }

    // MARK: - Private Helpers

    /// Retrieve the Family Member Key for the Person that owns this Provider.
    ///
    /// Invariant: Providers always belong to an existing Person, so the FMK
    /// must pre-exist at the time this is called. Any failure here therefore
    /// indicates either an upstream bug (e.g. a Person-deletion race that
    /// left Provider rows referencing a vanished owner) or keychain
    /// corruption — **not** a legitimate "this key hasn't been generated
    /// yet" condition. Generating a new FMK here would silently re-key the
    /// Person's data and break decryption of every other record under that
    /// Person.
    ///
    /// Contrast with `PersonRepository.ensureFMK(for:primaryKey:)`, which is
    /// the correct home for the "generate on first use" branch — it runs at
    /// Person-creation time.
    ///
    /// All underlying errors are flattened into
    /// `RepositoryError.keyNotAvailable` for the public surface (callers
    /// cannot meaningfully act on keychain-internal failure types). The
    /// original error is logged before wrapping so the underlying failure
    /// mode is preserved in diagnostics.
    private func ensureFMK(for personId: String, primaryKey: SymmetricKey) throws -> SymmetricKey {
        do {
            return try fmkService.retrieveFMK(personId: personId, primaryKey: primaryKey)
        } catch {
            logger.logError(
                error,
                context: "ProviderRepository.ensureFMK personId=\(personId)"
            )
            throw RepositoryError.keyNotAvailable("Failed to retrieve FMK: \(error.localizedDescription)")
        }
    }

    /// Encrypt Provider content
    private func encryptProviderData(_ provider: Provider, using fmk: SymmetricKey) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let json: Data
        do {
            json = try encoder.encode(provider)
        } catch {
            throw RepositoryError.serializationFailed(
                "Failed to encode Provider: \(error.localizedDescription)"
            )
        }

        do {
            let encryptedPayload = try encryptionService.encrypt(json, using: fmk)
            return encryptedPayload.combined
        } catch {
            throw RepositoryError.encryptionFailed("Failed to encrypt Provider data: \(error.localizedDescription)")
        }
    }

    /// Decrypt ProviderEntity to Provider model
    private func decryptProvider(
        from entity: ProviderEntity,
        personId: UUID,
        primaryKey: SymmetricKey
    ) throws -> Provider {
        guard entity.id != nil,
              let encryptedContent = entity.encryptedContent
        else {
            throw RepositoryError.deserializationFailed("ProviderEntity missing required fields")
        }

        let fmk = try ensureFMK(for: personId.uuidString, primaryKey: primaryKey)

        let encryptedPayload: EncryptedPayload
        do {
            encryptedPayload = try EncryptedPayload(combined: encryptedContent)
        } catch {
            throw RepositoryError
                .deserializationFailed("Invalid encrypted payload format: \(error.localizedDescription)")
        }

        let decryptedJSON: Data
        do {
            decryptedJSON = try encryptionService.decrypt(encryptedPayload, using: fmk)
        } catch {
            throw RepositoryError.decryptionFailed("Failed to decrypt Provider data: \(error.localizedDescription)")
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode(Provider.self, from: decryptedJSON)
        } catch {
            throw RepositoryError
                .deserializationFailed("Failed to decode Provider: \(error.localizedDescription)")
        }
    }
}
