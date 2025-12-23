import CryptoKit
import Foundation

/// Protocol for AES-256-GCM encryption operations
protocol EncryptionServiceProtocol {
    /// Encrypt data using AES-256-GCM
    /// - Parameters:
    ///   - data: Plaintext data to encrypt
    ///   - key: 256-bit symmetric key
    /// - Returns: EncryptedPayload containing nonce, ciphertext, and tag
    /// - Throws: CryptoError on failure
    func encrypt(_ data: Data, using key: SymmetricKey) throws -> EncryptedPayload

    /// Decrypt data using AES-256-GCM
    /// - Parameters:
    ///   - payload: EncryptedPayload to decrypt
    ///   - key: 256-bit symmetric key
    /// - Returns: Decrypted plaintext data
    /// - Throws: CryptoError on failure (wrong key, corrupted data, tampered tag)
    func decrypt(_ payload: EncryptedPayload, using key: SymmetricKey) throws -> Data

    /// Generate a cryptographically secure random nonce (96-bit for AES-GCM)
    /// - Returns: Fresh nonce for encryption
    func generateNonce() -> AES.GCM.Nonce
}

/// AES-256-GCM encryption service using CryptoKit
final class EncryptionService: EncryptionServiceProtocol {
    func encrypt(_ data: Data, using key: SymmetricKey) throws -> EncryptedPayload {
        let nonce = generateNonce()

        do {
            let sealedBox = try AES.GCM.seal(data, using: key, nonce: nonce)

            // Extract components from sealed box
            return EncryptedPayload(
                nonce: Data(nonce),
                ciphertext: sealedBox.ciphertext,
                tag: Data(sealedBox.tag)
            )
        } catch let error as CryptoError {
            throw error
        } catch {
            throw CryptoError.encryptionFailed(error.localizedDescription)
        }
    }

    func decrypt(_ payload: EncryptedPayload, using key: SymmetricKey) throws -> Data {
        do {
            let nonce = try AES.GCM.Nonce(data: payload.nonce)
            let sealedBox = try AES.GCM.SealedBox(
                nonce: nonce,
                ciphertext: payload.ciphertext,
                tag: payload.tag
            )

            return try AES.GCM.open(sealedBox, using: key)
        } catch CryptoKitError.authenticationFailure {
            // Wrong key or tampered data - constant-time comparison built into CryptoKit
            // Per security best practice: don't distinguish between wrong key and corrupted data
            throw CryptoError.decryptionFailed("Authentication failed - wrong key or corrupted data")
        } catch let error as CryptoError {
            throw error
        } catch {
            throw CryptoError.decryptionFailed(error.localizedDescription)
        }
    }

    func generateNonce() -> AES.GCM.Nonce {
        // CryptoKit generates cryptographically secure random nonce
        AES.GCM.Nonce()
    }
}
