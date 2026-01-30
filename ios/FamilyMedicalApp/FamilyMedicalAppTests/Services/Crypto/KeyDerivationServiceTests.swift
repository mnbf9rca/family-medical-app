import CryptoKit
import Foundation
import Testing
@testable import FamilyMedicalApp

struct KeyDerivationServiceTests {
    let service = KeyDerivationService()

    /// Test key derivation consistency (same password + same salt = same key)
    @Test
    func derivePrimaryKey_consistency() throws {
        let passwordBytes: [UInt8] = Array("correct-horse-battery-staple".utf8)
        let salt = try service.generateSalt()

        let key1 = try service.derivePrimaryKey(from: passwordBytes, salt: salt)
        let key2 = try service.derivePrimaryKey(from: passwordBytes, salt: salt)

        // Keys should be identical
        let data1 = key1.withUnsafeBytes { Data($0) }
        let data2 = key2.withUnsafeBytes { Data($0) }
        #expect(data1 == data2)
    }

    /// Test different passwords produce different keys
    @Test
    func derivePrimaryKey_differentPassword() throws {
        let passwordBytes1: [UInt8] = Array("password1".utf8)
        let passwordBytes2: [UInt8] = Array("password2".utf8)
        let salt = try service.generateSalt()

        let key1 = try service.derivePrimaryKey(from: passwordBytes1, salt: salt)
        let key2 = try service.derivePrimaryKey(from: passwordBytes2, salt: salt)

        // Keys should be different
        let data1 = key1.withUnsafeBytes { Data($0) }
        let data2 = key2.withUnsafeBytes { Data($0) }
        #expect(data1 != data2)
    }

    /// Test different salts produce different keys
    @Test
    func derivePrimaryKey_differentSalt() throws {
        let passwordBytes: [UInt8] = Array("same-password".utf8)
        let salt1 = try service.generateSalt()
        let salt2 = try service.generateSalt()

        let key1 = try service.derivePrimaryKey(from: passwordBytes, salt: salt1)
        let key2 = try service.derivePrimaryKey(from: passwordBytes, salt: salt2)

        // Keys should be different
        let data1 = key1.withUnsafeBytes { Data($0) }
        let data2 = key2.withUnsafeBytes { Data($0) }
        #expect(data1 != data2)
    }

    /// Test invalid salt length throws error
    @Test
    func derivePrimaryKey_invalidSaltLength() throws {
        let passwordBytes: [UInt8] = Array("password".utf8)
        let shortSalt = Data([0x01, 0x02, 0x03]) // Only 3 bytes

        #expect(throws: CryptoError.invalidSalt("Salt must be 16 bytes, got 3")) {
            _ = try service.derivePrimaryKey(from: passwordBytes, salt: shortSalt)
        }
    }

    /// Test empty password succeeds (valid edge case)
    @Test
    func derivePrimaryKey_emptyPassword() throws {
        let passwordBytes: [UInt8] = []
        let salt = try service.generateSalt()

        // Empty password should still derive a key
        let key = try service.derivePrimaryKey(from: passwordBytes, salt: salt)

        // Verify key is 32 bytes (256 bits)
        let keyData = key.withUnsafeBytes { Data($0) }
        #expect(keyData.count == 32)
    }

    /// Test salt generation produces 16 bytes (Argon2id requirement)
    @Test
    func generateSalt_correctSize() throws {
        let salt = try service.generateSalt()
        #expect(salt.count == 16)
    }

    /// Test salt generation produces unique values
    @Test
    func generateSalt_uniqueness() throws {
        let salt1 = try service.generateSalt()
        let salt2 = try service.generateSalt()
        let salt3 = try service.generateSalt()

        // All salts should be different
        #expect(salt1 != salt2)
        #expect(salt2 != salt3)
        #expect(salt1 != salt3)
    }

    /// Test secure zeroing of Data
    @Test
    func secureZero_data() {
        var data = Data([0x01, 0x02, 0x03, 0x04])
        service.secureZero(&data)

        // Data should be zeroed
        #expect(data == Data([0x00, 0x00, 0x00, 0x00]))
    }

    /// Test secure zeroing of byte array
    @Test
    func secureZero_bytes() {
        var bytes: [UInt8] = [0x01, 0x02, 0x03, 0x04]
        service.secureZero(&bytes)

        // Bytes should be zeroed
        #expect(bytes == [0x00, 0x00, 0x00, 0x00])
    }

    /// Test derived key is 256 bits (32 bytes)
    @Test
    func derivePrimaryKey_keySize() throws {
        let passwordBytes: [UInt8] = Array("test-password".utf8)
        let salt = try service.generateSalt()

        let key = try service.derivePrimaryKey(from: passwordBytes, salt: salt)

        let keyData = key.withUnsafeBytes { Data($0) }
        #expect(keyData.count == 32) // 256 bits
    }

    // MARK: - Bytes-Based Methods (RFC 9807)

    /// Test key derivation from password bytes
    @Test
    func derivePrimaryKeyFromBytes() throws {
        let passwordBytes: [UInt8] = Array("test-password-123".utf8)
        let salt = try service.generateSalt()

        let key = try service.derivePrimaryKey(from: passwordBytes, salt: salt)

        // Key should be 256 bits (32 bytes)
        let keyData = key.withUnsafeBytes { Data($0) }
        #expect(keyData.count == 32)
    }

    /// Test bytes-based derivation is deterministic
    @Test
    func derivePrimaryKeyFromBytes_deterministic() throws {
        let passwordBytes: [UInt8] = Array("test-password-123".utf8)
        let salt = try service.generateSalt()

        let key1 = try service.derivePrimaryKey(from: passwordBytes, salt: salt)
        let key2 = try service.derivePrimaryKey(from: passwordBytes, salt: salt)

        let keyData1 = key1.withUnsafeBytes { Data($0) }
        let keyData2 = key2.withUnsafeBytes { Data($0) }
        #expect(keyData1 == keyData2)
    }
}
