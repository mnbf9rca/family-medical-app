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

    /// Counter to generate unique ciphertexts
    private var encryptCounter: UInt64 = 0

    // MARK: - Tracking

    private(set) var encryptCalls: [(data: Data, key: SymmetricKey)] = []
    private(set) var decryptCalls: [(payload: EncryptedPayload, key: SymmetricKey)] = []

    // MARK: - EncryptionServiceProtocol

    func encrypt(_ data: Data, using key: SymmetricKey) throws -> EncryptedPayload {
        encryptCalls.append((data, key))

        if shouldFailEncryption {
            throw CryptoError.encryptionFailed("Mock encryption failure")
        }

        // Generate unique mock encrypted payload using counter
        encryptCounter += 1
        var nonceData = Data(repeating: 0x01, count: 12) // 96-bit nonce
        // Embed counter in nonce to make each encryption unique
        withUnsafeBytes(of: encryptCounter.bigEndian) { counterBytes in
            nonceData.replaceSubrange(0 ..< 8, with: counterBytes)
        }

        // Use counter-based prefix to ensure unique ciphertext
        var ciphertext = Data(capacity: data.count + 8)
        withUnsafeBytes(of: encryptCounter.bigEndian) { counterBytes in
            ciphertext.append(contentsOf: counterBytes)
        }
        ciphertext.append(Data(repeating: 0x02, count: data.count))

        let tag = Data(repeating: 0x03, count: 16) // 128-bit tag

        // Store mapping for later decryption
        storage[ciphertext] = data

        // swiftlint:disable:next force_try
        return try! EncryptedPayload(nonce: nonceData, ciphertext: ciphertext, tag: tag)
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
        encryptCounter = 0
        shouldFailEncryption = false
        shouldFailDecryption = false
    }
}
