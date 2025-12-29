import CryptoKit
import Foundation
@testable import FamilyMedicalApp

/// Mock encryption service for testing
/// @unchecked Sendable: Safe for tests where mocks are only used from MainActor test contexts
final class MockEncryptionService: EncryptionServiceProtocol, @unchecked Sendable {
    // MARK: - Configuration

    var shouldFailEncryption = false
    var shouldFailDecryption = false

    // MARK: - Storage

    /// Store encrypted data for proper decryption (ciphertext -> plaintext mapping)
    private var storage: [Data: Data] = [:]

    // MARK: - Tracking

    private(set) var encryptCalls: [(data: Data, key: SymmetricKey)] = []
    private(set) var decryptCalls: [(payload: EncryptedPayload, key: SymmetricKey)] = []

    // MARK: - EncryptionServiceProtocol

    func encrypt(_ data: Data, using key: SymmetricKey) throws -> EncryptedPayload {
        encryptCalls.append((data, key))

        if shouldFailEncryption {
            throw CryptoError.encryptionFailed("Mock encryption failure")
        }

        // Generate predictable mock encrypted payload
        let nonce = Data(repeating: 0x01, count: 12) // 96-bit nonce
        let ciphertext = Data(repeating: 0x02, count: data.count) // Same length as input
        let tag = Data(repeating: 0x03, count: 16) // 128-bit tag

        // Store mapping for later decryption
        storage[ciphertext] = data

        // swiftlint:disable:next force_try
        return try! EncryptedPayload(nonce: nonce, ciphertext: ciphertext, tag: tag)
    }

    func decrypt(_ payload: EncryptedPayload, using key: SymmetricKey) throws -> Data {
        decryptCalls.append((payload, key))

        if shouldFailDecryption {
            throw CryptoError.decryptionFailed("Mock decryption failure")
        }

        // Return the original plaintext that was encrypted
        guard let plaintext = storage[payload.ciphertext] else {
            throw CryptoError.decryptionFailed("Mock: No stored plaintext for this ciphertext")
        }

        return plaintext
    }

    func generateNonce() -> AES.GCM.Nonce {
        // Return a fixed nonce for predictable testing
        // swiftlint:disable:next force_try
        try! AES.GCM.Nonce(data: Data(repeating: 0x01, count: 12))
    }

    // MARK: - Test Helpers

    func reset() {
        encryptCalls.removeAll()
        decryptCalls.removeAll()
        storage.removeAll()
        shouldFailEncryption = false
        shouldFailDecryption = false
    }
}
