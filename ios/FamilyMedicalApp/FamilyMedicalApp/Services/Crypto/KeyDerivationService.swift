import CryptoKit
import Foundation
import Sodium

/// Protocol for password-based key derivation using Argon2id
protocol KeyDerivationServiceProtocol: Sendable {
    /// Derive a primary key from password using Argon2id
    /// - Parameters:
    ///   - password: User's password
    ///   - salt: 16-byte salt (generate new for new users, retrieve for existing)
    /// - Returns: 256-bit SymmetricKey
    /// - Throws: CryptoError on derivation failure
    func derivePrimaryKey(from password: String, salt: Data) throws -> SymmetricKey

    /// Derive a primary key from OPAQUE export key using HKDF
    ///
    /// When using OPAQUE authentication, the export key replaces password-based
    /// derivation. The export key is already memory-hard (OPAQUE uses Argon2
    /// internally), so we only need HKDF expansion.
    ///
    /// - Parameter exportKey: 256-bit OPAQUE export key
    /// - Returns: 256-bit SymmetricKey
    /// - Throws: CryptoError on derivation failure
    func derivePrimaryKey(fromExportKey exportKey: Data) throws -> SymmetricKey

    /// Generate a cryptographically secure random salt (16 bytes)
    /// - Returns: 16-byte salt
    /// - Throws: CryptoError on random generation failure
    func generateSalt() throws -> Data

    /// Securely clear sensitive data from memory using libsodium's sodium_memzero
    /// - Parameter data: Data to securely zero
    func secureZero(_ data: inout Data)

    /// Securely clear sensitive byte array from memory
    /// - Parameter bytes: Byte array to securely zero
    func secureZero(_ bytes: inout [UInt8])
}

/// Argon2id key derivation service using Swift-Sodium (libsodium wrapper)
final class KeyDerivationService: KeyDerivationServiceProtocol, @unchecked Sendable {
    private let sodium = Sodium()

    // Argon2id parameters from ADR-0002
    // These provide strong security while remaining performant on iOS devices
    private let saltLength = 16 // crypto_pwhash_SALTBYTES (libsodium constant)
    private let opsLimit = 3 // 3 iterations
    private let memLimit = 64 * 1_024 * 1_024 // 64 MB memory
    private let outputLength = 32 // 256-bit key

    func derivePrimaryKey(from password: String, salt: Data) throws -> SymmetricKey {
        guard salt.count == saltLength else {
            throw CryptoError.invalidSalt("Salt must be \(saltLength) bytes, got \(salt.count)")
        }

        let passwordData = Data(password.utf8)

        guard let derivedKey = sodium.pwHash.hash(
            outputLength: outputLength,
            passwd: passwordData.bytes,
            salt: salt.bytes,
            opsLimit: opsLimit,
            memLimit: memLimit,
            alg: .Argon2ID13
        ) else {
            // Securely clear password data before throwing
            var passwordBytes = [UInt8](passwordData)
            sodium.utils.zero(&passwordBytes)
            throw CryptoError.keyDerivationFailed("Argon2id derivation failed")
        }

        // Convert to CryptoKit SymmetricKey
        let key = SymmetricKey(data: Data(derivedKey))

        // Securely clear the intermediate arrays
        var mutableDerivedKey = derivedKey
        sodium.utils.zero(&mutableDerivedKey)

        var passwordBytes = [UInt8](passwordData)
        sodium.utils.zero(&passwordBytes)

        return key
    }

    func derivePrimaryKey(fromExportKey exportKey: Data) throws -> SymmetricKey {
        // opaque-ke with Sha512 produces 64-byte export keys
        // Accept both 32-byte (legacy) and 64-byte (current) keys
        guard exportKey.count == 32 || exportKey.count == 64 else {
            throw CryptoError.keyDerivationFailed("Export key must be 32 or 64 bytes, got \(exportKey.count)")
        }

        // Use HKDF to derive primary key from OPAQUE export key
        // The export key is already memory-hard (OPAQUE uses Argon2 internally)
        // HKDF provides domain separation and deterministic derivation
        let inputKey = SymmetricKey(data: exportKey)
        let info = Data("family-medical-app-primary-key-v1".utf8)

        let derivedKey = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: inputKey,
            info: info,
            outputByteCount: outputLength
        )

        return derivedKey
    }

    func generateSalt() throws -> Data {
        // Generate cryptographically secure random data (Argon2id salt size)
        var salt = [UInt8](repeating: 0, count: saltLength)
        let status = SecRandomCopyBytes(kSecRandomDefault, saltLength, &salt)

        guard status == errSecSuccess else {
            throw CryptoError.keyDerivationFailed("Salt generation failed")
        }

        return Data(salt)
    }

    func secureZero(_ data: inout Data) {
        data.withUnsafeMutableBytes { (ptr: UnsafeMutableRawBufferPointer) in
            if let baseAddress = ptr.baseAddress {
                let result = memset_s(baseAddress, ptr.count, 0, ptr.count)
                precondition(result == 0, "memset_s failed with error code \(result)")
            }
        }
    }

    func secureZero(_ bytes: inout [UInt8]) {
        sodium.utils.zero(&bytes)
    }
}
