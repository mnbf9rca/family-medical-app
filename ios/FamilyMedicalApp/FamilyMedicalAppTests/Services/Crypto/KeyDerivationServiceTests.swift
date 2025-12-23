import CryptoKit
import Foundation
import Testing
@testable import FamilyMedicalApp

struct KeyDerivationServiceTests {
    let service = KeyDerivationService()

    /// Test key derivation consistency (same password + same salt = same key)
    @Test
    func derivePrimaryKey_consistency() throws {
        // swiftlint:disable:next password_in_code
        let password = "correct-horse-battery-staple"
        let salt = service.generateSalt()

        let key1 = try service.derivePrimaryKey(from: password, salt: salt)
        let key2 = try service.derivePrimaryKey(from: password, salt: salt)

        // Keys should be identical
        let data1 = key1.withUnsafeBytes { Data($0) }
        let data2 = key2.withUnsafeBytes { Data($0) }
        #expect(data1 == data2)
    }

    /// Test different passwords produce different keys
    @Test
    func derivePrimaryKey_differentPassword() throws {
        let password1 = "password1"
        let password2 = "password2"
        let salt = service.generateSalt()

        let key1 = try service.derivePrimaryKey(from: password1, salt: salt)
        let key2 = try service.derivePrimaryKey(from: password2, salt: salt)

        // Keys should be different
        let data1 = key1.withUnsafeBytes { Data($0) }
        let data2 = key2.withUnsafeBytes { Data($0) }
        #expect(data1 != data2)
    }

    /// Test different salts produce different keys
    @Test
    func derivePrimaryKey_differentSalt() throws {
        // swiftlint:disable:next password_in_code
        let password = "same-password"
        let salt1 = service.generateSalt()
        let salt2 = service.generateSalt()

        let key1 = try service.derivePrimaryKey(from: password, salt: salt1)
        let key2 = try service.derivePrimaryKey(from: password, salt: salt2)

        // Keys should be different
        let data1 = key1.withUnsafeBytes { Data($0) }
        let data2 = key2.withUnsafeBytes { Data($0) }
        #expect(data1 != data2)
    }

    /// Test invalid salt length throws error
    @Test
    func derivePrimaryKey_invalidSaltLength() throws {
        // swiftlint:disable:next password_in_code
        let password = "password"
        let shortSalt = Data([0x01, 0x02, 0x03]) // Only 3 bytes

        #expect(throws: CryptoError.invalidSalt("Salt must be 32 bytes, got 3")) {
            _ = try service.derivePrimaryKey(from: password, salt: shortSalt)
        }
    }

    /// Test empty password succeeds (valid edge case)
    @Test
    func derivePrimaryKey_emptyPassword() throws {
        let password = ""
        let salt = service.generateSalt()

        // Empty password should still derive a key
        let key = try service.derivePrimaryKey(from: password, salt: salt)

        // Verify key is 32 bytes (256 bits)
        let keyData = key.withUnsafeBytes { Data($0) }
        #expect(keyData.count == 32)
    }

    /// Test salt generation produces 32 bytes
    @Test
    func generateSalt_correctSize() {
        let salt = service.generateSalt()
        #expect(salt.count == 32)
    }

    /// Test salt generation produces unique values
    @Test
    func generateSalt_uniqueness() {
        let salt1 = service.generateSalt()
        let salt2 = service.generateSalt()
        let salt3 = service.generateSalt()

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
        // swiftlint:disable:next password_in_code
        let password = "test-password"
        let salt = service.generateSalt()

        let key = try service.derivePrimaryKey(from: password, salt: salt)

        let keyData = key.withUnsafeBytes { Data($0) }
        #expect(keyData.count == 32) // 256 bits
    }
}
