import CryptoKit
import Foundation

/// Encrypts `UserPreferences` with the user's Primary Key and stores the
/// result as a single combined blob in the Keychain.
///
/// Key rotation is the caller's responsibility: re-save with the new Primary
/// Key after rotation; this service only encrypts / decrypts.
final class UserPreferencesService: @unchecked Sendable {
    // MARK: - Constants

    private static let keychainIdentifier = "user_preferences"

    // MARK: - Dependencies

    private let encryptionService: EncryptionServiceProtocol
    private let keychainService: KeychainServiceProtocol
    private let logger: TracingCategoryLogger

    // MARK: - Initialization

    init(
        encryptionService: EncryptionServiceProtocol,
        keychainService: KeychainServiceProtocol,
        logger: CategoryLoggerProtocol? = nil
    ) {
        self.encryptionService = encryptionService
        self.keychainService = keychainService
        self.logger = TracingCategoryLogger(
            wrapping: logger ?? LoggingService.shared.logger(category: .storage)
        )
    }

    func load(primaryKey: SymmetricKey) throws -> UserPreferences {
        let start = ContinuousClock.now
        logger.entry("load")

        do {
            let combined = try keychainService.retrieveData(
                identifier: Self.keychainIdentifier
            )

            let payload = try EncryptedPayload(combined: combined)
            let jsonData = try encryptionService.decrypt(payload, using: primaryKey)
            let preferences = try JSONDecoder().decode(UserPreferences.self, from: jsonData)

            logger.exit("load", duration: ContinuousClock.now - start)
            return preferences
        } catch KeychainError.keyNotFound {
            // No preferences stored yet – return defaults
            logger.exit("load", duration: ContinuousClock.now - start)
            return UserPreferences()
        } catch {
            logger.exitWithError("load", error: error, duration: ContinuousClock.now - start)
            throw error
        }
    }

    func save(_ preferences: UserPreferences, primaryKey: SymmetricKey) throws {
        let start = ContinuousClock.now
        logger.entry("save")

        do {
            let jsonData = try JSONEncoder().encode(preferences)
            let payload = try encryptionService.encrypt(jsonData, using: primaryKey)
            try keychainService.storeData(
                payload.combined,
                identifier: Self.keychainIdentifier,
                accessControl: .whenUnlockedThisDeviceOnly
            )

            logger.exit("save", duration: ContinuousClock.now - start)
        } catch {
            logger.exitWithError("save", error: error, duration: ContinuousClock.now - start)
            throw error
        }
    }

    func delete() throws {
        let start = ContinuousClock.now
        logger.entry("delete")

        do {
            try keychainService.deleteData(identifier: Self.keychainIdentifier)
            logger.exit("delete", duration: ContinuousClock.now - start)
        } catch KeychainError.keyNotFound {
            // Nothing stored – treat as success
            logger.exit("delete", duration: ContinuousClock.now - start)
        } catch {
            logger.exitWithError("delete", error: error, duration: ContinuousClock.now - start)
            throw error
        }
    }
}
