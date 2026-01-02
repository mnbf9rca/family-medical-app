import CryptoKit
import Foundation
@testable import FamilyMedicalApp

/// Mock encryption service for testing
/// Thread-safe: uses NSLock to protect mutable state for concurrent test scenarios
final class MockEncryptionService: EncryptionServiceProtocol, @unchecked Sendable {
    // MARK: - Thread Safety

    private let lock = NSLock()

    // MARK: - Configuration

    var shouldFailEncryption = false
    var shouldFailDecryption = false

    // MARK: - Storage (protected by lock)

    /// Store encrypted data for proper decryption (ciphertext -> plaintext mapping)
    private var storage: [Data: Data] = [:]

    /// Counter to generate unique ciphertexts
    private var encryptCounter: UInt64 = 0

    // MARK: - Tracking (protected by lock)

    private var _encryptCalls: [(data: Data, key: SymmetricKey)] = []
    private var _decryptCalls: [(payload: EncryptedPayload, key: SymmetricKey)] = []

    var encryptCalls: [(data: Data, key: SymmetricKey)] {
        lock.lock()
        defer { lock.unlock() }
        return _encryptCalls
    }

    var decryptCalls: [(payload: EncryptedPayload, key: SymmetricKey)] {
        lock.lock()
        defer { lock.unlock() }
        return _decryptCalls
    }

    // MARK: - EncryptionServiceProtocol

    func encrypt(_ data: Data, using key: SymmetricKey) throws -> EncryptedPayload {
        lock.lock()
        _encryptCalls.append((data, key))

        if shouldFailEncryption {
            lock.unlock()
            throw CryptoError.encryptionFailed("Mock encryption failure")
        }

        // Generate unique mock encrypted payload using counter
        encryptCounter += 1
        let counter = encryptCounter
        var nonceData = Data(repeating: 0x01, count: 12) // 96-bit nonce
        // Embed counter in nonce to make each encryption unique
        withUnsafeBytes(of: counter.bigEndian) { counterBytes in
            nonceData.replaceSubrange(0 ..< 8, with: counterBytes)
        }

        // Use counter-based prefix to ensure unique ciphertext
        var ciphertext = Data(capacity: data.count + 8)
        withUnsafeBytes(of: counter.bigEndian) { counterBytes in
            ciphertext.append(contentsOf: counterBytes)
        }
        ciphertext.append(Data(repeating: 0x02, count: data.count))

        let tag = Data(repeating: 0x03, count: 16) // 128-bit tag

        // Store mapping for later decryption
        storage[ciphertext] = data
        lock.unlock()

        // swiftlint:disable:next force_try
        return try! EncryptedPayload(nonce: nonceData, ciphertext: ciphertext, tag: tag)
    }

    func decrypt(_ payload: EncryptedPayload, using key: SymmetricKey) throws -> Data {
        lock.lock()
        _decryptCalls.append((payload, key))

        if shouldFailDecryption {
            lock.unlock()
            throw CryptoError.decryptionFailed("Mock decryption failure")
        }

        // Return the original plaintext that was encrypted
        guard let plaintext = storage[payload.ciphertext] else {
            lock.unlock()
            throw CryptoError.decryptionFailed("Mock: No stored plaintext for this ciphertext")
        }

        lock.unlock()
        return plaintext
    }

    func generateNonce() -> AES.GCM.Nonce {
        // Return a fixed nonce for predictable testing
        // swiftlint:disable:next force_try
        try! AES.GCM.Nonce(data: Data(repeating: 0x01, count: 12))
    }

    // MARK: - Test Helpers

    func reset() {
        lock.lock()
        defer { lock.unlock() }
        _encryptCalls.removeAll()
        _decryptCalls.removeAll()
        storage.removeAll()
        encryptCounter = 0
        shouldFailEncryption = false
        shouldFailDecryption = false
    }
}
