import CryptoKit
import Foundation
import Testing
@testable import FamilyMedicalApp

struct RecordContentServiceTests {
    // MARK: - Test Field IDs

    /// Test UUIDs for field identification in encryption/decryption tests
    private enum TestFieldIds {
        static let name = UUID()
        static let dosage = UUID()
        static let age = UUID()
        static let count = UUID()
        static let temperature = UUID()
        static let weight = UUID()
        static let vaccinated = UUID()
        static let allergies = UUID()
        static let visitDate = UUID()
        static let images = UUID()
        static let tags = UUID()
        static let diagnosis = UUID()
        static let severity = UUID()
        static let contagious = UUID()
        static let onsetDate = UUID()
        static let xrays = UUID()
        static let symptoms = UUID()
        static let field = UUID()
    }

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
        content.setString(TestFieldIds.name, "Aspirin")
        content.setString(TestFieldIds.dosage, "100mg")

        let encrypted = try service.encrypt(content, using: testFMK)
        let decrypted = try service.decrypt(encrypted, using: testFMK)

        #expect(decrypted == content)
        #expect(decrypted.getString(TestFieldIds.name) == "Aspirin")
        #expect(decrypted.getString(TestFieldIds.dosage) == "100mg")
    }

    @Test
    func encrypt_decrypt_contentWithIntField_roundTrips() throws {
        let service = makeService()
        var content = RecordContent()
        content.setInt(TestFieldIds.age, 42)
        content.setInt(TestFieldIds.count, 7)

        let encrypted = try service.encrypt(content, using: testFMK)
        let decrypted = try service.decrypt(encrypted, using: testFMK)

        #expect(decrypted == content)
        #expect(decrypted.getInt(TestFieldIds.age) == 42)
        #expect(decrypted.getInt(TestFieldIds.count) == 7)
    }

    @Test
    func encrypt_decrypt_contentWithDoubleField_roundTrips() throws {
        let service = makeService()
        var content = RecordContent()
        content.setDouble(TestFieldIds.temperature, 98.6)
        content.setDouble(TestFieldIds.weight, 150.5)

        let encrypted = try service.encrypt(content, using: testFMK)
        let decrypted = try service.decrypt(encrypted, using: testFMK)

        #expect(decrypted == content)
        #expect(decrypted.getDouble(TestFieldIds.temperature) == 98.6)
        #expect(decrypted.getDouble(TestFieldIds.weight) == 150.5)
    }

    @Test
    func encrypt_decrypt_contentWithBoolField_roundTrips() throws {
        let service = makeService()
        var content = RecordContent()
        content.setBool(TestFieldIds.vaccinated, true)
        content.setBool(TestFieldIds.allergies, false)

        let encrypted = try service.encrypt(content, using: testFMK)
        let decrypted = try service.decrypt(encrypted, using: testFMK)

        #expect(decrypted == content)
        #expect(decrypted.getBool(TestFieldIds.vaccinated) == true)
        #expect(decrypted.getBool(TestFieldIds.allergies) == false)
    }

    @Test
    func encrypt_decrypt_contentWithDateField_roundTrips() throws {
        let service = makeService()
        var content = RecordContent()
        let testDate = Date(timeIntervalSince1970: 1_234_567_890)
        content.setDate(TestFieldIds.visitDate, testDate)

        let encrypted = try service.encrypt(content, using: testFMK)
        let decrypted = try service.decrypt(encrypted, using: testFMK)

        #expect(decrypted == content)
        #expect(decrypted.getDate(TestFieldIds.visitDate) == testDate)
    }

    @Test
    func encrypt_decrypt_contentWithAttachmentIds_roundTrips() throws {
        let service = makeService()
        var content = RecordContent()
        let ids = [UUID(), UUID(), UUID()]
        content.setAttachmentIds(TestFieldIds.images, ids)

        let encrypted = try service.encrypt(content, using: testFMK)
        let decrypted = try service.decrypt(encrypted, using: testFMK)

        #expect(decrypted == content)
        #expect(decrypted.getAttachmentIds(TestFieldIds.images) == ids)
    }

    @Test
    func encrypt_decrypt_contentWithStringArray_roundTrips() throws {
        let service = makeService()
        var content = RecordContent()
        let tags = ["urgent", "follow-up", "pediatric"]
        content.setStringArray(TestFieldIds.tags, tags)

        let encrypted = try service.encrypt(content, using: testFMK)
        let decrypted = try service.decrypt(encrypted, using: testFMK)

        #expect(decrypted == content)
        #expect(decrypted.getStringArray(TestFieldIds.tags) == tags)
    }

    @Test
    func encrypt_decrypt_contentWithAllFieldTypes_roundTrips() throws {
        let service = makeService()
        var content = RecordContent(schemaId: "comprehensive-test")

        content.setString(TestFieldIds.diagnosis, "Common Cold")
        content.setInt(TestFieldIds.severity, 3)
        content.setDouble(TestFieldIds.temperature, 100.4)
        content.setBool(TestFieldIds.contagious, true)
        content.setDate(TestFieldIds.onsetDate, Date(timeIntervalSince1970: 1_700_000_000))
        content.setAttachmentIds(TestFieldIds.xrays, [UUID(), UUID()])
        content.setStringArray(TestFieldIds.symptoms, ["cough", "fever", "fatigue"])

        let encrypted = try service.encrypt(content, using: testFMK)
        let decrypted = try service.decrypt(encrypted, using: testFMK)

        #expect(decrypted == content)
        #expect(decrypted.schemaId == "comprehensive-test")
        #expect(decrypted.getString(TestFieldIds.diagnosis) == "Common Cold")
        #expect(decrypted.getInt(TestFieldIds.severity) == 3)
        #expect(decrypted.getDouble(TestFieldIds.temperature) == 100.4)
        #expect(decrypted.getBool(TestFieldIds.contagious) == true)
        #expect(decrypted.getDate(TestFieldIds.onsetDate) == Date(timeIntervalSince1970: 1_700_000_000))
        #expect(decrypted.getAttachmentIds(TestFieldIds.xrays)?.count == 2)
        #expect(decrypted.getStringArray(TestFieldIds.symptoms) == ["cough", "fever", "fatigue"])
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
        content.setString(TestFieldIds.field, "value") // Add some data to make ciphertext larger

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
