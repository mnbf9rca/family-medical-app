import CryptoKit
import Foundation
import Testing
@testable import FamilyMedicalApp

struct RecordContentServiceTests {
    // MARK: - Test Fixtures

    struct TestFixtures {
        let service: RecordContentService
        let encryption: MockEncryptionService
    }

    // MARK: - Test Dependencies

    func makeService() -> RecordContentService {
        RecordContentService(encryptionService: MockEncryptionService())
    }

    func makeServiceWithMocks() -> TestFixtures {
        let encryption = MockEncryptionService()
        let service = RecordContentService(encryptionService: encryption)
        return TestFixtures(service: service, encryption: encryption)
    }

    let testFMK = SymmetricKey(size: .bits256)

    // MARK: - Round-Trip Tests

    @Test
    func encrypt_decrypt_emptyContent_roundTrips() throws {
        let service = makeService()
        let content = RecordContent()

        let encrypted = try service.encrypt(content, using: testFMK)
        let decrypted = try service.decrypt(encrypted, using: testFMK)

        #expect(decrypted == content)
        #expect(decrypted.schemaId == nil)
        #expect(decrypted.allFields.isEmpty)
    }

    @Test
    func encrypt_decrypt_contentWithSchemaIdOnly_roundTrips() throws {
        let service = makeService()
        let content = RecordContent(schemaId: "vaccine")

        let encrypted = try service.encrypt(content, using: testFMK)
        let decrypted = try service.decrypt(encrypted, using: testFMK)

        #expect(decrypted == content)
        #expect(decrypted.schemaId == "vaccine")
        #expect(decrypted.allFields.isEmpty)
    }

    @Test
    func encrypt_decrypt_contentWithStringField_roundTrips() throws {
        let service = makeService()
        var content = RecordContent(schemaId: "medication")
        content.setString("name", "Aspirin")
        content.setString("dosage", "100mg")

        let encrypted = try service.encrypt(content, using: testFMK)
        let decrypted = try service.decrypt(encrypted, using: testFMK)

        #expect(decrypted == content)
        #expect(decrypted.getString("name") == "Aspirin")
        #expect(decrypted.getString("dosage") == "100mg")
    }

    @Test
    func encrypt_decrypt_contentWithIntField_roundTrips() throws {
        let service = makeService()
        var content = RecordContent()
        content.setInt("age", 42)
        content.setInt("count", 7)

        let encrypted = try service.encrypt(content, using: testFMK)
        let decrypted = try service.decrypt(encrypted, using: testFMK)

        #expect(decrypted == content)
        #expect(decrypted.getInt("age") == 42)
        #expect(decrypted.getInt("count") == 7)
    }

    @Test
    func encrypt_decrypt_contentWithDoubleField_roundTrips() throws {
        let service = makeService()
        var content = RecordContent()
        content.setDouble("temperature", 98.6)
        content.setDouble("weight", 150.5)

        let encrypted = try service.encrypt(content, using: testFMK)
        let decrypted = try service.decrypt(encrypted, using: testFMK)

        #expect(decrypted == content)
        #expect(decrypted.getDouble("temperature") == 98.6)
        #expect(decrypted.getDouble("weight") == 150.5)
    }

    @Test
    func encrypt_decrypt_contentWithBoolField_roundTrips() throws {
        let service = makeService()
        var content = RecordContent()
        content.setBool("vaccinated", true)
        content.setBool("allergies", false)

        let encrypted = try service.encrypt(content, using: testFMK)
        let decrypted = try service.decrypt(encrypted, using: testFMK)

        #expect(decrypted == content)
        #expect(decrypted.getBool("vaccinated") == true)
        #expect(decrypted.getBool("allergies") == false)
    }

    @Test
    func encrypt_decrypt_contentWithDateField_roundTrips() throws {
        let service = makeService()
        var content = RecordContent()
        let testDate = Date(timeIntervalSince1970: 1_234_567_890)
        content.setDate("visitDate", testDate)

        let encrypted = try service.encrypt(content, using: testFMK)
        let decrypted = try service.decrypt(encrypted, using: testFMK)

        #expect(decrypted == content)
        #expect(decrypted.getDate("visitDate") == testDate)
    }

    @Test
    func encrypt_decrypt_contentWithAttachmentIds_roundTrips() throws {
        let service = makeService()
        var content = RecordContent()
        let ids = [UUID(), UUID(), UUID()]
        content.setAttachmentIds("images", ids)

        let encrypted = try service.encrypt(content, using: testFMK)
        let decrypted = try service.decrypt(encrypted, using: testFMK)

        #expect(decrypted == content)
        #expect(decrypted.getAttachmentIds("images") == ids)
    }

    @Test
    func encrypt_decrypt_contentWithStringArray_roundTrips() throws {
        let service = makeService()
        var content = RecordContent()
        let tags = ["urgent", "follow-up", "pediatric"]
        content.setStringArray("tags", tags)

        let encrypted = try service.encrypt(content, using: testFMK)
        let decrypted = try service.decrypt(encrypted, using: testFMK)

        #expect(decrypted == content)
        #expect(decrypted.getStringArray("tags") == tags)
    }

    @Test
    func encrypt_decrypt_contentWithAllFieldTypes_roundTrips() throws {
        let service = makeService()
        var content = RecordContent(schemaId: "comprehensive-test")

        content.setString("diagnosis", "Common Cold")
        content.setInt("severity", 3)
        content.setDouble("temperature", 100.4)
        content.setBool("contagious", true)
        content.setDate("onsetDate", Date(timeIntervalSince1970: 1_700_000_000))
        content.setAttachmentIds("xrays", [UUID(), UUID()])
        content.setStringArray("symptoms", ["cough", "fever", "fatigue"])

        let encrypted = try service.encrypt(content, using: testFMK)
        let decrypted = try service.decrypt(encrypted, using: testFMK)

        #expect(decrypted == content)
        #expect(decrypted.schemaId == "comprehensive-test")
        #expect(decrypted.getString("diagnosis") == "Common Cold")
        #expect(decrypted.getInt("severity") == 3)
        #expect(decrypted.getDouble("temperature") == 100.4)
        #expect(decrypted.getBool("contagious") == true)
        #expect(decrypted.getDate("onsetDate") == Date(timeIntervalSince1970: 1_700_000_000))
        #expect(decrypted.getAttachmentIds("xrays")?.count == 2)
        #expect(decrypted.getStringArray("symptoms") == ["cough", "fever", "fatigue"])
    }

    // MARK: - Encryption Error Tests

    @Test
    func encrypt_encryptionFails_throwsRepositoryError() throws {
        let fixtures = makeServiceWithMocks()
        let service = fixtures.service
        let encryption = fixtures.encryption

        encryption.shouldFailEncryption = true

        let content = RecordContent(schemaId: "test")

        #expect(throws: RepositoryError.self) {
            try service.encrypt(content, using: testFMK)
        }
    }

    // MARK: - Decryption Error Tests

    @Test
    func decrypt_decryptionFails_throwsRepositoryError() throws {
        let fixtures = makeServiceWithMocks()
        let service = fixtures.service
        let encryption = fixtures.encryption

        // First encrypt successfully
        let content = RecordContent(schemaId: "test")
        let encrypted = try service.encrypt(content, using: testFMK)

        // Now make decryption fail
        encryption.shouldFailDecryption = true

        #expect(throws: RepositoryError.self) {
            try service.decrypt(encrypted, using: testFMK)
        }
    }

    @Test
    func decrypt_invalidFormat_throwsRepositoryError() throws {
        let service = makeService()

        // Invalid encrypted data (too short to be valid combined format)
        let invalidData = Data([0x00, 0x01, 0x02])

        #expect(throws: RepositoryError.self) {
            try service.decrypt(invalidData, using: testFMK)
        }
    }

    @Test
    func decrypt_corruptedData_throwsRepositoryError() throws {
        let service = makeService()
        var content = RecordContent(schemaId: "test")
        content.setString("field", "value") // Add some data to make ciphertext larger

        // Encrypt normally
        var encrypted = try service.encrypt(content, using: testFMK)

        // Corrupt the ciphertext portion (after nonce, before tag)
        // Combined format: nonce(12) + ciphertext + tag(16)
        // Corrupt middle of ciphertext
        let midpoint = encrypted.count / 2
        encrypted[midpoint] ^= 0xFF
        encrypted[midpoint + 1] ^= 0xFF

        #expect(throws: RepositoryError.self) {
            try service.decrypt(encrypted, using: testFMK)
        }
    }

    // MARK: - Combined Format Tests

    @Test
    func encrypt_returnsCombinedFormat() throws {
        let service = makeService()
        let content = RecordContent(schemaId: "test")

        let encrypted = try service.encrypt(content, using: testFMK)

        // Combined format should be: nonce(12) + ciphertext + tag(16)
        // Minimum size is 12 + 0 + 16 = 28 bytes
        #expect(encrypted.count >= 28)

        // Should be able to parse back into EncryptedPayload
        let payload = try EncryptedPayload(combined: encrypted)
        #expect(payload.nonce.count == 12)
        #expect(payload.tag.count == 16)
    }
}
