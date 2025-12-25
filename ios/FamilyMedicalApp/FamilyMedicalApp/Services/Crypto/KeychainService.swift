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
protocol KeychainServiceProtocol {
    /// Store a symmetric key in Keychain
    /// - Parameters:
    ///   - key: SymmetricKey to store
    ///   - identifier: Unique identifier (e.g., "master-key.userID")
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
}

/// iOS Keychain wrapper for secure key storage
final class KeychainService: KeychainServiceProtocol {
    private let serviceName = "com.cynexia.FamilyMedicalApp"

    func storeKey(_ key: SymmetricKey, identifier: String, accessControl: KeychainAccessControl) throws {
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
            throw KeychainError.storeFailed(status)
        }
    }

    func retrieveKey(identifier: String) throws -> SymmetricKey {
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
                throw KeychainError.keyNotFound(identifier)
            }
            throw KeychainError.retrieveFailed(status)
        }

        return SymmetricKey(data: keyData)
    }

    func deleteKey(identifier: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: identifier
        ]

        let status = SecItemDelete(query as CFDictionary)

        if status == errSecItemNotFound {
            throw KeychainError.keyNotFound(identifier)
        }

        guard status == errSecSuccess else {
            throw KeychainError.deleteFailed(status)
        }
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
        // Delete existing data first (upsert pattern)
        do {
            try deleteData(identifier: identifier)
        } catch KeychainError.keyNotFound {
            // No existing data to delete – proceed with storing
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
            throw KeychainError.storeFailed(status)
        }
    }

    func retrieveData(identifier: String) throws -> Data {
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
                throw KeychainError.keyNotFound(identifier)
            }
            throw KeychainError.retrieveFailed(status)
        }

        return data
    }

    func deleteData(identifier: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: identifier
        ]

        let status = SecItemDelete(query as CFDictionary)

        if status == errSecItemNotFound {
            throw KeychainError.keyNotFound(identifier)
        }

        guard status == errSecSuccess else {
            throw KeychainError.deleteFailed(status)
        }
    }
}
