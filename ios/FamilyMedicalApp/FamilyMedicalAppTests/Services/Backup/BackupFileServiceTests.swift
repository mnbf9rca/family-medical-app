import CryptoKit
import Foundation
import Testing
@testable import FamilyMedicalApp

@Suite("BackupFileService Tests")
struct BackupFileServiceTests {
    let testPassword = "TestPassword123!"

    // MARK: - Encryption Tests

    @Test("Encrypts payload and produces valid BackupFile")
    func encryptsPayload() throws {
        let service = BackupFileService(
            keyDerivationService: KeyDerivationService(),
            encryptionService: EncryptionService()
        )

        let payload = makeTestPayload()
        let file = try service.createEncryptedBackup(payload: payload, password: testPassword)

        #expect(file.encrypted == true)
        #expect(file.ciphertext != nil)
        #expect(file.data == nil)
        #expect(file.encryption != nil)
        #expect(file.encryption?.kdf.algorithm == "Argon2id")
        #expect(file.checksum.algorithm == "SHA-256")
    }

    @Test("Decrypts payload with correct password")
    func decryptsWithCorrectPassword() throws {
        let service = BackupFileService(
            keyDerivationService: KeyDerivationService(),
            encryptionService: EncryptionService()
        )

        let original = makeTestPayload()
        let file = try service.createEncryptedBackup(payload: original, password: testPassword)
        let decrypted = try service.decryptBackup(file: file, password: testPassword)

        #expect(decrypted.persons.count == original.persons.count)
        #expect(decrypted.persons[0].name == original.persons[0].name)
    }

    @Test("Fails decryption with wrong password")
    func failsWithWrongPassword() throws {
        let service = BackupFileService(
            keyDerivationService: KeyDerivationService(),
            encryptionService: EncryptionService()
        )

        let payload = makeTestPayload()
        let file = try service.createEncryptedBackup(payload: payload, password: testPassword)

        #expect(throws: BackupError.invalidPassword) {
            _ = try service.decryptBackup(file: file, password: "WrongPassword!")
        }
    }

    @Test("Fails with password too short")
    func failsWithShortPassword() throws {
        let service = BackupFileService(
            keyDerivationService: KeyDerivationService(),
            encryptionService: EncryptionService()
        )

        let payload = makeTestPayload()

        #expect(throws: BackupError.passwordTooWeak) {
            _ = try service.createEncryptedBackup(payload: payload, password: "short")
        }
    }

    // MARK: - Unencrypted Tests

    @Test("Creates unencrypted backup correctly")
    func createsUnencryptedBackup() throws {
        let service = BackupFileService(
            keyDerivationService: KeyDerivationService(),
            encryptionService: EncryptionService()
        )

        let payload = makeTestPayload()
        let file = try service.createUnencryptedBackup(payload: payload)

        #expect(file.encrypted == false)
        #expect(file.ciphertext == nil)
        #expect(file.encryption == nil)
        #expect(file.data != nil)
        #expect(file.data?.persons.count == 1)
    }

    @Test("Reads unencrypted backup correctly")
    func readsUnencryptedBackup() throws {
        let service = BackupFileService(
            keyDerivationService: KeyDerivationService(),
            encryptionService: EncryptionService()
        )

        let original = makeTestPayload()
        let file = try service.createUnencryptedBackup(payload: original)
        let read = try service.readUnencryptedBackup(file: file)

        #expect(read.persons[0].name == original.persons[0].name)
    }

    // MARK: - Checksum Tests

    @Test("Verifies checksum correctly for encrypted backup")
    func verifiesChecksumEncrypted() throws {
        let service = BackupFileService(
            keyDerivationService: KeyDerivationService(),
            encryptionService: EncryptionService()
        )

        let payload = makeTestPayload()
        let file = try service.createEncryptedBackup(payload: payload, password: testPassword)

        #expect(try service.verifyChecksum(file: file) == true)
    }

    @Test("Verifies checksum correctly for unencrypted backup")
    func verifiesChecksumUnencrypted() throws {
        let service = BackupFileService(
            keyDerivationService: KeyDerivationService(),
            encryptionService: EncryptionService()
        )

        let payload = makeTestPayload()
        let file = try service.createUnencryptedBackup(payload: payload)

        #expect(try service.verifyChecksum(file: file) == true)
    }

    @Test("Detects corrupted checksum")
    func detectsCorruptedChecksum() throws {
        let service = BackupFileService(
            keyDerivationService: KeyDerivationService(),
            encryptionService: EncryptionService()
        )

        let payload = makeTestPayload()
        let originalFile = try service.createEncryptedBackup(payload: payload, password: testPassword)

        // Corrupt the checksum
        let corruptedFile = BackupFile(
            schema: originalFile.schema,
            formatName: originalFile.formatName,
            formatVersion: originalFile.formatVersion,
            generator: originalFile.generator,
            encrypted: originalFile.encrypted,
            checksum: BackupChecksum(algorithm: "SHA-256", value: "corrupted"),
            encryption: originalFile.encryption,
            ciphertext: originalFile.ciphertext,
            data: originalFile.data
        )

        #expect(try service.verifyChecksum(file: corruptedFile) == false)
    }

    // MARK: - Serialization Tests

    @Test("Serializes to valid JSON")
    func serializesToJSON() throws {
        let service = BackupFileService(
            keyDerivationService: KeyDerivationService(),
            encryptionService: EncryptionService()
        )

        let payload = makeTestPayload()
        let file = try service.createEncryptedBackup(payload: payload, password: testPassword)
        let json = try service.serializeToJSON(file: file)

        // Verify it's valid JSON
        let parsed = try JSONSerialization.jsonObject(with: json)
        #expect(parsed is [String: Any])

        // Verify key fields are present
        guard let jsonString = String(data: json, encoding: .utf8) else {
            throw BackupError.corruptedFile
        }
        #expect(jsonString.contains("formatVersion"))
        #expect(jsonString.contains("Argon2id"))
    }

    @Test("Deserializes from JSON")
    func deserializesFromJSON() throws {
        let service = BackupFileService(
            keyDerivationService: KeyDerivationService(),
            encryptionService: EncryptionService()
        )

        let payload = makeTestPayload()
        let original = try service.createEncryptedBackup(payload: payload, password: testPassword)
        let json = try service.serializeToJSON(file: original)
        let restored = try service.deserializeFromJSON(json)

        #expect(restored.formatVersion == original.formatVersion)
        #expect(restored.encrypted == original.encrypted)
    }

    @Test("Full round-trip with encryption")
    func fullRoundTripEncrypted() throws {
        let service = BackupFileService(
            keyDerivationService: KeyDerivationService(),
            encryptionService: EncryptionService()
        )

        let original = makeTestPayload()

        // Create encrypted backup
        let file = try service.createEncryptedBackup(payload: original, password: testPassword)

        // Serialize to JSON (simulating file write)
        let json = try service.serializeToJSON(file: file)

        // Deserialize from JSON (simulating file read)
        let restoredFile = try service.deserializeFromJSON(json)

        // Verify checksum
        #expect(try service.verifyChecksum(file: restoredFile) == true)

        // Decrypt
        let restoredPayload = try service.decryptBackup(file: restoredFile, password: testPassword)

        // Verify content
        #expect(restoredPayload.persons.count == original.persons.count)
        #expect(restoredPayload.persons[0].name == original.persons[0].name)
        #expect(restoredPayload.metadata.personCount == original.metadata.personCount)
    }

    @Test("Full round-trip without encryption")
    func fullRoundTripUnencrypted() throws {
        let service = BackupFileService(
            keyDerivationService: KeyDerivationService(),
            encryptionService: EncryptionService()
        )

        let original = makeTestPayload()

        // Create unencrypted backup
        let file = try service.createUnencryptedBackup(payload: original)

        // Serialize to JSON (simulating file write)
        let json = try service.serializeToJSON(file: file)

        // Deserialize from JSON (simulating file read)
        let restoredFile = try service.deserializeFromJSON(json)

        // Verify checksum
        #expect(try service.verifyChecksum(file: restoredFile) == true)

        // Read payload
        let restoredPayload = try service.readUnencryptedBackup(file: restoredFile)

        // Verify content
        #expect(restoredPayload.persons.count == original.persons.count)
        #expect(restoredPayload.persons[0].name == original.persons[0].name)
    }

    // MARK: - Error Handling Tests

    @Test("Throws corruptedFile for encrypted file without encryption params")
    func throwsForMissingEncryptionParams() throws {
        let service = BackupFileService(
            keyDerivationService: KeyDerivationService(),
            encryptionService: EncryptionService()
        )

        let file = BackupFile(
            generator: "Test/1.0",
            encrypted: true,
            checksum: BackupChecksum(algorithm: "SHA-256", value: "test"),
            encryption: nil, // Missing!
            ciphertext: "somedata",
            data: nil
        )

        #expect(throws: BackupError.corruptedFile) {
            _ = try service.decryptBackup(file: file, password: testPassword)
        }
    }

    @Test("Throws corruptedFile for unencrypted file without data")
    func throwsForMissingData() throws {
        let service = BackupFileService(
            keyDerivationService: KeyDerivationService(),
            encryptionService: EncryptionService()
        )

        let file = BackupFile(
            generator: "Test/1.0",
            encrypted: false,
            checksum: BackupChecksum(algorithm: "SHA-256", value: "test"),
            encryption: nil,
            ciphertext: nil,
            data: nil // Missing!
        )

        #expect(throws: BackupError.corruptedFile) {
            _ = try service.readUnencryptedBackup(file: file)
        }
    }

    // MARK: - Format Validation Tests

    @Test("Throws unsupportedVersion for wrong formatVersion")
    func throwsForUnsupportedVersion() throws {
        let service = BackupFileService(
            keyDerivationService: KeyDerivationService(),
            encryptionService: EncryptionService()
        )

        // Create a valid backup and modify the version
        let payload = makeTestPayload()
        let original = try service.createUnencryptedBackup(payload: payload)

        // Create a file with unsupported version
        let unsupportedFile = BackupFile(
            schema: original.schema,
            formatName: original.formatName,
            formatVersion: "2.0", // Unsupported version
            generator: original.generator,
            encrypted: original.encrypted,
            checksum: original.checksum,
            encryption: original.encryption,
            ciphertext: original.ciphertext,
            data: original.data
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let json = try encoder.encode(unsupportedFile)

        #expect(throws: BackupError.unsupportedVersion("2.0")) {
            _ = try service.deserializeFromJSON(json)
        }
    }

    @Test("Throws corruptedFile for wrong formatName")
    func throwsForInvalidFormatName() throws {
        let service = BackupFileService(
            keyDerivationService: KeyDerivationService(),
            encryptionService: EncryptionService()
        )

        // Create a valid backup and modify the format name
        let payload = makeTestPayload()
        let original = try service.createUnencryptedBackup(payload: payload)

        // Create a file with invalid format name
        let invalidFile = BackupFile(
            schema: original.schema,
            formatName: "Invalid Format Name",
            formatVersion: original.formatVersion,
            generator: original.generator,
            encrypted: original.encrypted,
            checksum: original.checksum,
            encryption: original.encryption,
            ciphertext: original.ciphertext,
            data: original.data
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let json = try encoder.encode(invalidFile)

        #expect(throws: BackupError.corruptedFile) {
            _ = try service.deserializeFromJSON(json)
        }
    }

    @Test("Accepts valid formatName and formatVersion")
    func acceptsValidFormatNameAndVersion() throws {
        let service = BackupFileService(
            keyDerivationService: KeyDerivationService(),
            encryptionService: EncryptionService()
        )

        let payload = makeTestPayload()
        let file = try service.createUnencryptedBackup(payload: payload)
        let json = try service.serializeToJSON(file: file)

        // Should not throw
        let restored = try service.deserializeFromJSON(json)
        #expect(restored.formatName == BackupFile.formatNameValue)
        #expect(restored.formatVersion == BackupFile.currentVersion)
    }

    // MARK: - Helpers

    func makeTestPayload() -> BackupPayload {
        BackupPayload(
            exportedAt: Date(),
            appVersion: "1.0.0",
            metadata: BackupMetadata(personCount: 1, recordCount: 0, attachmentCount: 0, schemaCount: 0),
            persons: [
                PersonBackup(
                    id: UUID(),
                    name: "Test Person",
                    dateOfBirth: Date(),
                    labels: ["child"],
                    notes: "Test notes",
                    createdAt: Date(),
                    updatedAt: Date()
                )
            ],
            records: [],
            attachments: [],
            schemas: []
        )
    }
}
