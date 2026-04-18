import CryptoKit
import Foundation
import Sodium

/// Key derivation primitives used by the encrypted-backup import/export path.
///
/// Account authentication derives its key material via OPAQUE (see
/// `OpaqueAuthService` / `derivePrimaryKey(fromExportKey:)`); that path does
/// **not** use this Argon2id primitive. The only remaining production caller
/// of `derivePrimaryKey(from:salt:)` is `BackupFileService`, which derives a
/// wrapping key from the user's backup passphrase to encrypt/decrypt the
/// backup envelope. See ADR-0002 for the wider key hierarchy.
protocol KeyDerivationServiceProtocol: Sendable {
    /// Derive a backup-envelope wrapping key from a passphrase using Argon2id.
    ///
    /// Used by `BackupFileService` on backup export (with a freshly-generated
    /// salt stored in the backup envelope) and on backup import (with the salt
    /// read back from the envelope the user is restoring).
    ///
    /// `passwordBytes` is taken by value so the caller retains ownership and
    /// can securely zero the buffer once the derivation returns (per RFC 9807
    /// handling of password material); this service does not zero on the
    /// caller's behalf.
    ///
    /// - Parameters:
    ///   - passwordBytes: Backup passphrase as bytes. Caller is responsible
    ///     for zeroing the buffer after the call (use `secureZero`).
    ///   - salt: 16-byte Argon2id salt. On export: generated via
    ///     `generateSalt()` and stored alongside the ciphertext in the backup
    ///     envelope. On import: read back from the envelope being restored.
    /// - Returns: 256-bit `SymmetricKey` suitable as the backup-envelope
    ///   wrapping key.
    /// - Throws: `CryptoError` on invalid salt length or Argon2id failure.
    func derivePrimaryKey(from passwordBytes: [UInt8], salt: Data) throws -> SymmetricKey

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

    func derivePrimaryKey(from passwordBytes: [UInt8], salt: Data) throws -> SymmetricKey {
        guard salt.count == saltLength else {
            throw CryptoError.invalidSalt("Salt must be \(saltLength) bytes, got \(salt.count)")
        }

        guard let derivedKey = sodium.pwHash.hash(
            outputLength: outputLength,
            passwd: passwordBytes,
            salt: salt.bytes,
            opsLimit: opsLimit,
            memLimit: memLimit,
            alg: .Argon2ID13
        ) else {
            throw CryptoError.keyDerivationFailed("Argon2id derivation failed")
        }

        // Convert to CryptoKit SymmetricKey
        let key = SymmetricKey(data: Data(derivedKey))

        // Zero the derived key copy after creating SymmetricKey
        var mutableDerivedKey = derivedKey
        sodium.utils.zero(&mutableDerivedKey)

        return key
    }

    func derivePrimaryKey(fromExportKey exportKey: Data) throws -> SymmetricKey {
        // opaque-ke with SHA-512 produces 64-byte export keys
        guard exportKey.count == 64 else {
            throw CryptoError.keyDerivationFailed("Export key must be 64 bytes, got \(exportKey.count)")
        }

        // Use HKDF to derive primary key from OPAQUE export key
        // The export key is already memory-hard (OPAQUE uses Argon2 internally)
        // HKDF provides domain separation and deterministic derivation
        let inputKey = SymmetricKey(data: exportKey)
        let info = Data("family-medical-app-primary-key-v1".utf8)

        return HKDF<SHA256>.deriveKey(
            inputKeyMaterial: inputKey,
            info: info,
            outputByteCount: outputLength
        )
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
