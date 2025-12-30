import CryptoKit
import Foundation
import Security

/// Keychain access control levels
enum KeychainAccessControl {
    /// Key only accessible when device is unlocked, never synced to iCloud
    case whenUnlockedThisDeviceOnly

    /// Key accessible after first unlock until reboot
    case afterFirstUnlockThisDeviceOnly

    var secAttrValue: CFString {
        switch self {
        case .whenUnlockedThisDeviceOnly:
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        case .afterFirstUnlockThisDeviceOnly:
            kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        }
    }
}

/// Protocol for secure key storage in iOS Keychain
protocol KeychainServiceProtocol: Sendable {
    /// Store a symmetric key in Keychain
    /// - Parameters:
    ///   - key: SymmetricKey to store
    ///   - identifier: Unique identifier (e.g., "primary-key.userID")
    ///   - accessControl: Keychain access level
    /// - Throws: KeychainError on failure
    func storeKey(_ key: SymmetricKey, identifier: String, accessControl: KeychainAccessControl) throws

    /// Retrieve a symmetric key from Keychain
    /// - Parameter identifier: Key identifier
    /// - Returns: SymmetricKey if found
    /// - Throws: KeychainError.keyNotFound or other failures
    func retrieveKey(identifier: String) throws -> SymmetricKey

    /// Delete a key from Keychain
    /// - Parameter identifier: Key identifier
    /// - Throws: KeychainError on failure
    func deleteKey(identifier: String) throws

    /// Check if a key exists in Keychain
    /// - Parameter identifier: Key identifier
    /// - Returns: true if key exists, false otherwise
    func keyExists(identifier: String) -> Bool

    /// Store generic data in Keychain
    /// - Parameters:
    ///   - data: Data to store
    ///   - identifier: Unique identifier
    ///   - accessControl: Keychain access level
    /// - Throws: KeychainError on failure
    func storeData(_ data: Data, identifier: String, accessControl: KeychainAccessControl) throws

    /// Retrieve generic data from Keychain
    /// - Parameter identifier: Data identifier
    /// - Returns: Data if found
    /// - Throws: KeychainError.keyNotFound or other failures
    func retrieveData(identifier: String) throws -> Data

    /// Delete data from Keychain
    /// - Parameter identifier: Data identifier
    /// - Throws: KeychainError on failure
    func deleteData(identifier: String) throws

    /// Check if data exists in Keychain
    /// - Parameter identifier: Data identifier
    /// - Returns: true if data exists, false otherwise
    func dataExists(identifier: String) -> Bool
}

/// iOS Keychain wrapper for secure key storage
final class KeychainService: KeychainServiceProtocol, @unchecked Sendable {
    private let serviceName = "com.cynexia.FamilyMedicalApp"
    private let logger: CategoryLoggerProtocol

    init(logger: CategoryLoggerProtocol? = nil) {
        self.logger = logger ?? LoggingService.shared.logger(category: .crypto)
    }

    func storeKey(_ key: SymmetricKey, identifier: String, accessControl: KeychainAccessControl) throws {
        logger.debug("Storing key with identifier: \(identifier)", privacy: .private)

        // Delete existing key first (upsert pattern). Only ignore "not found" errors, propagate others.
        do {
            try deleteKey(identifier: identifier)
        } catch KeychainError.keyNotFound {
            // No existing key to delete – proceed with storing
        }

        let keyData = key.withUnsafeBytes { Data($0) }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: identifier,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: accessControl.secAttrValue
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            logger.error("Failed to store key: \(identifier), status: \(status)", privacy: .private)
            throw KeychainError.storeFailed(status)
        }

        logger.debug("Successfully stored key: \(identifier)", privacy: .private)
    }

    func retrieveKey(identifier: String) throws -> SymmetricKey {
        logger.debug("Retrieving key with identifier: \(identifier)", privacy: .private)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: identifier,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let keyData = result as? Data
        else {
            if status == errSecItemNotFound {
                logger.error("Key not found: \(identifier)", privacy: .private)
                throw KeychainError.keyNotFound(identifier)
            }
            logger.error("Failed to retrieve key: \(identifier), status: \(status)", privacy: .private)
            throw KeychainError.retrieveFailed(status)
        }

        logger.debug("Successfully retrieved key: \(identifier)", privacy: .private)
        return SymmetricKey(data: keyData)
    }

    func deleteKey(identifier: String) throws {
        logger.debug("Deleting key with identifier: \(identifier)", privacy: .private)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: identifier
        ]

        let status = SecItemDelete(query as CFDictionary)

        if status == errSecItemNotFound {
            logger.error("Cannot delete key not found: \(identifier)", privacy: .private)
            throw KeychainError.keyNotFound(identifier)
        }

        guard status == errSecSuccess else {
            logger.error("Failed to delete key: \(identifier), status: \(status)", privacy: .private)
            throw KeychainError.deleteFailed(status)
        }

        logger.debug("Successfully deleted key: \(identifier)", privacy: .private)
    }

    func keyExists(identifier: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: identifier,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    func storeData(_ data: Data, identifier: String, accessControl: KeychainAccessControl) throws {
        logger.debug("Storing data with identifier: \(identifier)", privacy: .private)

        // Delete existing data first (upsert pattern)
        do {
            try deleteData(identifier: identifier)
        } catch let error as KeychainError {
            switch error {
            case .keyNotFound:
                // No existing data to delete - proceed with storing
                break
            default:
                // Propagate other keychain errors to the caller
                throw error
            }
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: identifier,
            kSecValueData as String: data,
            kSecAttrAccessible as String: accessControl.secAttrValue
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            logger.error("Failed to store data: \(identifier), status: \(status)", privacy: .private)
            throw KeychainError.storeFailed(status)
        }

        logger.debug("Successfully stored data: \(identifier)", privacy: .private)
    }

    func retrieveData(identifier: String) throws -> Data {
        logger.debug("Retrieving data with identifier: \(identifier)", privacy: .private)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: identifier,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data
        else {
            if status == errSecItemNotFound {
                logger.error("Data not found: \(identifier)", privacy: .private)
                throw KeychainError.keyNotFound(identifier)
            }
            logger.error("Failed to retrieve data: \(identifier), status: \(status)", privacy: .private)
            throw KeychainError.retrieveFailed(status)
        }

        logger.debug("Successfully retrieved data: \(identifier)", privacy: .private)
        return data
    }

    func deleteData(identifier: String) throws {
        logger.debug("Deleting data with identifier: \(identifier)", privacy: .private)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: identifier
        ]

        let status = SecItemDelete(query as CFDictionary)

        if status == errSecItemNotFound {
            logger.error("Cannot delete data not found: \(identifier)", privacy: .private)
            throw KeychainError.keyNotFound(identifier)
        }

        guard status == errSecSuccess else {
            logger.error("Failed to delete data: \(identifier), status: \(status)", privacy: .private)
            throw KeychainError.deleteFailed(status)
        }

        logger.debug("Successfully deleted data: \(identifier)", privacy: .private)
    }

    func dataExists(identifier: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: identifier,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// Delete all items for this service (for testing only)
    /// - Throws: KeychainError on failure (except when no items found)
    func deleteAllItems() throws {
        logger.debug("Deleting all keychain items for service: \(serviceName)", privacy: .public)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName
        ]

        let status = SecItemDelete(query as CFDictionary)

        // Success or no items found are both acceptable
        guard status == errSecSuccess || status == errSecItemNotFound else {
            logger.error("Failed to delete all items, status: \(status)", privacy: .public)
            throw KeychainError.deleteFailed(status)
        }

        logger.debug("Successfully deleted all keychain items", privacy: .public)
    }
}
