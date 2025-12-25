import CryptoKit
import Foundation

/// Protocol for Family Member Key (FMK) operations
protocol FamilyMemberKeyServiceProtocol {
    /// Generate a new random 256-bit Family Member Key
    /// - Returns: Fresh 256-bit SymmetricKey
    func generateFMK() -> SymmetricKey

    /// Wrap an FMK with the primary key for secure storage
    /// - Parameters:
    ///   - fmk: Family Member Key to wrap
    ///   - primaryKey: User's primary key
    /// - Returns: Wrapped key data (encrypted FMK)
    /// - Throws: CryptoError on wrapping failure
    func wrapFMK(_ fmk: SymmetricKey, with primaryKey: SymmetricKey) throws -> Data

    /// Unwrap an FMK using the primary key
    /// - Parameters:
    ///   - wrappedFMK: Encrypted FMK data
    ///   - primaryKey: User's primary key
    /// - Returns: Unwrapped FMK
    /// - Throws: CryptoError on unwrapping failure
    func unwrapFMK(_ wrappedFMK: Data, with primaryKey: SymmetricKey) throws -> SymmetricKey
}

/// Family Member Key management service
final class FamilyMemberKeyService: FamilyMemberKeyServiceProtocol {
    private let keychainService: KeychainServiceProtocol

    init(keychainService: KeychainServiceProtocol = KeychainService()) {
        self.keychainService = keychainService
    }

    func generateFMK() -> SymmetricKey {
        // Generate random 256-bit key (NOT password-derived)
        SymmetricKey(size: .bits256)
    }

    func wrapFMK(_ fmk: SymmetricKey, with primaryKey: SymmetricKey) throws -> Data {
        do {
            // Use AES Key Wrap (RFC 3394) via CryptoKit
            return try AES.KeyWrap.wrap(fmk, using: primaryKey)
        } catch {
            throw CryptoError.encryptionFailed("FMK wrapping failed: \(error.localizedDescription)")
        }
    }

    func unwrapFMK(_ wrappedFMK: Data, with primaryKey: SymmetricKey) throws -> SymmetricKey {
        do {
            // Use AES Key Unwrap (RFC 3394) via CryptoKit
            return try AES.KeyWrap.unwrap(wrappedFMK, using: primaryKey)
        } catch {
            throw CryptoError.decryptionFailed("FMK unwrapping failed: \(error.localizedDescription)")
        }
    }

    /// Store an FMK in Keychain (wrapped with primary key internally)
    /// - Parameters:
    ///   - fmk: Family Member Key to store
    ///   - familyMemberID: Unique identifier for the family member
    ///   - primaryKey: User's primary key for wrapping
    /// - Throws: CryptoError or KeychainError on failure
    func storeFMK(_ fmk: SymmetricKey, familyMemberID: String, primaryKey: SymmetricKey) throws {
        let wrappedFMK = try wrapFMK(fmk, with: primaryKey)
        let wrappedKey = SymmetricKey(data: wrappedFMK)

        let identifier = "fmk.\(familyMemberID)"
        try keychainService.storeKey(
            wrappedKey,
            identifier: identifier,
            accessControl: .whenUnlockedThisDeviceOnly
        )
    }

    /// Retrieve an FMK from Keychain
    /// - Parameters:
    ///   - familyMemberID: Unique identifier for the family member
    ///   - primaryKey: User's primary key for unwrapping
    /// - Returns: Unwrapped FMK
    /// - Throws: KeychainError or CryptoError on failure
    func retrieveFMK(familyMemberID: String, primaryKey: SymmetricKey) throws -> SymmetricKey {
        let identifier = "fmk.\(familyMemberID)"
        let wrappedKey = try keychainService.retrieveKey(identifier: identifier)

        let wrappedFMK = wrappedKey.withUnsafeBytes { Data($0) }
        return try unwrapFMK(wrappedFMK, with: primaryKey)
    }
}
