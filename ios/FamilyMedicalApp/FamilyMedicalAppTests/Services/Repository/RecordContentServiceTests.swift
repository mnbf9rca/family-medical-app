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
    func encrypt_decrypt_immunizationRecord_roundTrips() throws {
        let service = makeService()
        let immunization = ImmunizationRecord(vaccineCode: "COVID-19", occurrenceDate: Date())
        let envelope = try RecordContentEnvelope(immunization)

        let encrypted = try service.encrypt(envelope, using: testFMK)
        let decrypted = try service.decrypt(encrypted, using: testFMK)

        #expect(decrypted.recordType == .immunization)
        #expect(decrypted.schemaVersion == 1)

        let decoded = try decrypted.decode(ImmunizationRecord.self)
        #expect(decoded.vaccineCode == "COVID-19")
    }

    @Test
    func encrypt_decrypt_conditionRecord_roundTrips() throws {
        let service = makeService()
        let condition = ConditionRecord(conditionName: "Asthma", onsetDate: Date())
        let envelope = try RecordContentEnvelope(condition)

        let encrypted = try service.encrypt(envelope, using: testFMK)
        let decrypted = try service.decrypt(encrypted, using: testFMK)

        #expect(decrypted.recordType == .condition)

        let decoded = try decrypted.decode(ConditionRecord.self)
        #expect(decoded.conditionName == "Asthma")
    }

    @Test
    func encrypt_decrypt_medicationRecord_roundTrips() throws {
        let service = makeService()
        let medication = MedicationStatementRecord(medicationName: "Aspirin")
        let envelope = try RecordContentEnvelope(medication)

        let encrypted = try service.encrypt(envelope, using: testFMK)
        let decrypted = try service.decrypt(encrypted, using: testFMK)

        #expect(decrypted.recordType == .medicationStatement)

        let decoded = try decrypted.decode(MedicationStatementRecord.self)
        #expect(decoded.medicationName == "Aspirin")
    }

    @Test
    func encrypt_decrypt_preservesAllFieldTypes() throws {
        let service = makeService()
        let immunization = ImmunizationRecord(
            vaccineCode: "COVID-19",
            occurrenceDate: Date(timeIntervalSince1970: 1_700_000_000),
            lotNumber: "EL9262",
            site: "Left arm",
            doseNumber: 2,
            dosesInSeries: 3,
            notes: "Second dose",
            tags: ["urgent", "follow-up"]
        )
        let envelope = try RecordContentEnvelope(immunization)

        let encrypted = try service.encrypt(envelope, using: testFMK)
        let decrypted = try service.decrypt(encrypted, using: testFMK)

        let decoded = try decrypted.decode(ImmunizationRecord.self)
        #expect(decoded.vaccineCode == "COVID-19")
        #expect(decoded.lotNumber == "EL9262")
        #expect(decoded.site == "Left arm")
        #expect(decoded.doseNumber == 2)
        #expect(decoded.dosesInSeries == 3)
        #expect(decoded.notes == "Second dose")
        #expect(decoded.tags == ["urgent", "follow-up"])
    }

    @Test
    func encrypt_decrypt_directEnvelope_roundTrips() throws {
        let service = makeService()
        let envelope = RecordContentEnvelope(
            recordType: .clinicalNote,
            schemaVersion: 1,
            content: Data("{\"title\":\"Test Note\",\"body\":\"Note body\",\"tags\":[]}".utf8)
        )

        let encrypted = try service.encrypt(envelope, using: testFMK)
        let decrypted = try service.decrypt(encrypted, using: testFMK)

        #expect(decrypted.recordType == .clinicalNote)
        #expect(decrypted.schemaVersion == 1)
    }

    // MARK: - Encryption Error Tests

    @Test
    func encrypt_encryptionFails_throwsRepositoryError() throws {
        let fixtures = makeServiceWithMocks()
        let service = fixtures.service
        let encryption = fixtures.encryption

        encryption.shouldFailEncryption = true

        let immunization = ImmunizationRecord(vaccineCode: "Test", occurrenceDate: Date())
        let envelope = try RecordContentEnvelope(immunization)

        #expect(throws: RepositoryError.self) {
            try service.encrypt(envelope, using: testFMK)
        }
    }

    // MARK: - Decryption Error Tests

    @Test
    func decrypt_decryptionFails_throwsRepositoryError() throws {
        let fixtures = makeServiceWithMocks()
        let service = fixtures.service
        let encryption = fixtures.encryption

        // First encrypt successfully
        let immunization = ImmunizationRecord(vaccineCode: "Test", occurrenceDate: Date())
        let envelope = try RecordContentEnvelope(immunization)
        let encrypted = try service.encrypt(envelope, using: testFMK)

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
        let immunization = ImmunizationRecord(vaccineCode: "Test", occurrenceDate: Date())
        let envelope = try RecordContentEnvelope(immunization)

        // Encrypt normally
        var encrypted = try service.encrypt(envelope, using: testFMK)

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
        let immunization = ImmunizationRecord(vaccineCode: "Test", occurrenceDate: Date())
        let envelope = try RecordContentEnvelope(immunization)

        let encrypted = try service.encrypt(envelope, using: testFMK)

        // Combined format should be: nonce(12) + ciphertext + tag(16)
        // Minimum size is 12 + 0 + 16 = 28 bytes
        #expect(encrypted.count >= 28)

        // Should be able to parse back into EncryptedPayload
        let payload = try EncryptedPayload(combined: encrypted)
        #expect(payload.nonce.count == 12)
        #expect(payload.tag.count == 16)
    }
}
