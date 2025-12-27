import CryptoKit
import Foundation
import Testing
@testable import FamilyMedicalApp

struct EncryptionServiceTests {
    let service = EncryptionService()

    /// Test encryption and decryption round-trip with small data
    @Test
    func encryptDecryptRoundTrip_smallData() throws {
        let key = SymmetricKey(size: .bits256)
        let plaintext = Data("Hello, World!".utf8)

        let encrypted = try service.encrypt(plaintext, using: key)
        let decrypted = try service.decrypt(encrypted, using: key)

        #expect(decrypted == plaintext)
    }

    /// Test encryption and decryption round-trip with large data
    @Test
    func encryptDecryptRoundTrip_largeData() throws {
        let key = SymmetricKey(size: .bits256)
        let plaintext = Data(repeating: 0x42, count: 1_024 * 1_024) // 1 MB

        let encrypted = try service.encrypt(plaintext, using: key)
        let decrypted = try service.decrypt(encrypted, using: key)

        #expect(decrypted == plaintext)
    }

    /// Test encryption and decryption round-trip with empty data
    @Test
    func encryptDecryptRoundTrip_emptyData() throws {
        let key = SymmetricKey(size: .bits256)
        let plaintext = Data()

        let encrypted = try service.encrypt(plaintext, using: key)
        let decrypted = try service.decrypt(encrypted, using: key)

        #expect(decrypted == plaintext)
    }

    /// Test decryption with wrong key fails
    @Test
    func decrypt_wrongKey() throws {
        let correctKey = SymmetricKey(size: .bits256)
        let wrongKey = SymmetricKey(size: .bits256)
        let plaintext = Data("Secret message".utf8)

        let encrypted = try service.encrypt(plaintext, using: correctKey)

        #expect(throws: CryptoError.self) {
            _ = try service.decrypt(encrypted, using: wrongKey)
        }
    }

    /// Test decryption with corrupted ciphertext fails
    @Test
    func decrypt_corruptedCiphertext() throws {
        let key = SymmetricKey(size: .bits256)
        let plaintext = Data("Original message".utf8)

        var encrypted = try service.encrypt(plaintext, using: key)

        // Corrupt the ciphertext
        var corruptedBytes = [UInt8](encrypted.ciphertext)
        if !corruptedBytes.isEmpty {
            corruptedBytes[0] ^= 0xFF
        }
        let corruptedCiphertext = Data(corruptedBytes)
        encrypted = try EncryptedPayload(
            nonce: encrypted.nonce,
            ciphertext: corruptedCiphertext,
            tag: encrypted.tag
        )

        #expect(throws: CryptoError.self) {
            _ = try service.decrypt(encrypted, using: key)
        }
    }

    /// Test decryption with tampered tag fails
    @Test
    func decrypt_tamperedTag() throws {
        let key = SymmetricKey(size: .bits256)
        let plaintext = Data("Protected data".utf8)

        var encrypted = try service.encrypt(plaintext, using: key)

        // Tamper with the tag
        var tamperedBytes = [UInt8](encrypted.tag)
        tamperedBytes[0] ^= 0xFF
        let tamperedTag = Data(tamperedBytes)
        encrypted = try EncryptedPayload(
            nonce: encrypted.nonce,
            ciphertext: encrypted.ciphertext,
            tag: tamperedTag
        )

        #expect(throws: CryptoError.self) {
            _ = try service.decrypt(encrypted, using: key)
        }
    }

    /// Test decryption with invalid nonce fails
    @Test
    func decrypt_invalidNonce() throws {
        let key = SymmetricKey(size: .bits256)
        let plaintext = Data("Test data".utf8)

        let encrypted = try service.encrypt(plaintext, using: key)

        // Use invalid nonce (wrong size) - should fail at payload construction
        #expect(throws: CryptoError.self) {
            _ = try EncryptedPayload(
                nonce: Data([0x01, 0x02]), // Only 2 bytes instead of 12
                ciphertext: encrypted.ciphertext,
                tag: encrypted.tag
            )
        }
    }

    /// Test payload construction with invalid tag fails
    @Test
    func encryptedPayload_invalidTag() throws {
        let validNonce = Data(count: 12) // 12 bytes
        let ciphertext = Data("ciphertext".utf8)
        let invalidTag = Data([0x01, 0x02, 0x03]) // Only 3 bytes instead of 16

        // Should fail at payload construction due to invalid tag length
        #expect(throws: CryptoError.self) {
            _ = try EncryptedPayload(
                nonce: validNonce,
                ciphertext: ciphertext,
                tag: invalidTag
            )
        }
    }

    /// Test nonce generation produces unique values
    @Test
    func generateNonce_uniqueness() {
        let nonce1 = service.generateNonce()
        let nonce2 = service.generateNonce()
        let nonce3 = service.generateNonce()

        #expect(Data(nonce1) != Data(nonce2))
        #expect(Data(nonce2) != Data(nonce3))
        #expect(Data(nonce1) != Data(nonce3))
    }

    /// Test same data with same key produces different ciphertext (due to nonce)
    @Test
    func encrypt_nonDeterministic() throws {
        let key = SymmetricKey(size: .bits256)
        let plaintext = Data("Same message".utf8)

        let encrypted1 = try service.encrypt(plaintext, using: key)
        let encrypted2 = try service.encrypt(plaintext, using: key)

        // Nonces should be different
        #expect(encrypted1.nonce != encrypted2.nonce)

        // Ciphertexts should be different
        #expect(encrypted1.ciphertext != encrypted2.ciphertext)

        // But both should decrypt to same plaintext
        let decrypted1 = try service.decrypt(encrypted1, using: key)
        let decrypted2 = try service.decrypt(encrypted2, using: key)
        #expect(decrypted1 == plaintext)
        #expect(decrypted2 == plaintext)
    }

    /// Test encrypted payload structure
    @Test
    func encryptedPayload_structure() throws {
        let key = SymmetricKey(size: .bits256)
        let plaintext = Data("Test".utf8)

        let encrypted = try service.encrypt(plaintext, using: key)

        // Nonce should be 12 bytes
        #expect(encrypted.nonce.count == 12)

        // Tag should be 16 bytes
        #expect(encrypted.tag.count == 16)

        // Ciphertext should match plaintext length
        #expect(encrypted.ciphertext.count == plaintext.count)
    }

    /// Test decrypt with corrupted nonce data throws
    @Test
    func decrypt_corruptedNonce() throws {
        let key = SymmetricKey(size: .bits256)
        let plaintext = Data("Test data".utf8)
        let encrypted = try service.encrypt(plaintext, using: key)

        // Create payload with zero nonce (valid length but invalid data)
        let zeroNonce = Data(count: 12)
        let corruptedPayload = try EncryptedPayload(
            nonce: zeroNonce,
            ciphertext: encrypted.ciphertext,
            tag: encrypted.tag
        )

        #expect(throws: CryptoError.self) {
            _ = try service.decrypt(corruptedPayload, using: key)
        }
    }

    /// Test payload combined format round-trip
    @Test
    func encryptedPayload_combinedFormat() throws {
        let key = SymmetricKey(size: .bits256)
        let plaintext = Data("Combined format test".utf8)

        let encrypted = try service.encrypt(plaintext, using: key)
        let combined = encrypted.combined

        // Recreate from combined
        let recreated = try EncryptedPayload(combined: combined)

        // Should decrypt successfully
        let decrypted = try service.decrypt(recreated, using: key)
        #expect(decrypted == plaintext)
    }
}
