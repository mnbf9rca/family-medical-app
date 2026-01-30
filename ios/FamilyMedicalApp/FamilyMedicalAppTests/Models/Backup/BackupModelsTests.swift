import CryptoKit
import Foundation
import Testing
@testable import FamilyMedicalApp

@Suite("BackupFile Tests")
struct BackupFileTests {
    @Test("BackupFile encodes encrypted format correctly")
    func backupFileEncryptedFormat() throws {
        let file = BackupFile(
            schema: "https://recordwell.app/schemas/backup-v1.json",
            formatName: BackupFile.formatNameValue,
            formatVersion: BackupFile.currentVersion,
            generator: "FamilyMedicalApp/1.0.0 (iOS)",
            encrypted: true,
            checksum: BackupChecksum(algorithm: "SHA-256", value: "abc123"),
            encryption: BackupEncryption(
                algorithm: "AES-256-GCM",
                kdf: BackupKDF.defaultArgon2id,
                nonce: "base64nonce",
                tag: "base64tag"
            ),
            ciphertext: "base64ciphertext",
            data: nil
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let json = try encoder.encode(file)
        guard let jsonString = String(data: json, encoding: .utf8) else {
            throw BackupError.corruptedFile
        }

        #expect(jsonString.contains("\"encrypted\" : true"))
        #expect(jsonString.contains("\"formatVersion\" : \"1.0\""))
        #expect(jsonString.contains("\"Argon2id\""))
        #expect(!jsonString.contains("\"data\""))
    }

    @Test("BackupFile encodes unencrypted format correctly")
    func backupFileUnencryptedFormat() throws {
        let payload = BackupPayload(
            exportedAt: Date(),
            appVersion: "1.0.0",
            metadata: BackupMetadata(personCount: 1, recordCount: 5, attachmentCount: 2, schemaCount: 3),
            persons: [],
            records: [],
            attachments: [],
            schemas: []
        )

        let file = BackupFile(
            schema: nil,
            formatName: BackupFile.formatNameValue,
            formatVersion: BackupFile.currentVersion,
            generator: "FamilyMedicalApp/1.0.0 (iOS)",
            encrypted: false,
            checksum: BackupChecksum(algorithm: "SHA-256", value: "abc123"),
            encryption: nil,
            ciphertext: nil,
            data: payload
        )

        let encoder = JSONEncoder()
        let json = try encoder.encode(file)
        guard let jsonString = String(data: json, encoding: .utf8) else {
            throw BackupError.corruptedFile
        }

        #expect(jsonString.contains("\"encrypted\":false") || jsonString.contains("\"encrypted\" : false"))
        #expect(!jsonString.contains("\"ciphertext\""))
        #expect(jsonString.contains("\"data\""))
    }

    @Test("BackupFile round-trips through JSON")
    func backupFileRoundTrip() throws {
        let original = BackupFile(
            schema: "https://recordwell.app/schemas/backup-v1.json",
            formatName: BackupFile.formatNameValue,
            formatVersion: BackupFile.currentVersion,
            generator: "Test/1.0",
            encrypted: true,
            checksum: BackupChecksum(algorithm: "SHA-256", value: "testhash"),
            encryption: BackupEncryption(
                algorithm: "AES-256-GCM",
                kdf: BackupKDF(
                    algorithm: "Argon2id",
                    version: 19,
                    salt: "testsalt",
                    memory: 67_108_864,
                    iterations: 3,
                    parallelism: 1,
                    keyLength: 32
                ),
                nonce: "testnonce",
                tag: "testtag"
            ),
            ciphertext: "testciphertext",
            data: nil
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(BackupFile.self, from: data)

        #expect(decoded.formatVersion == original.formatVersion)
        #expect(decoded.encrypted == original.encrypted)
        #expect(decoded.checksum == original.checksum)
        #expect(decoded.encryption?.kdf.memory == original.encryption?.kdf.memory)
    }
}

@Suite("BackupChecksum Tests")
struct BackupChecksumTests {
    @Test("BackupChecksum computes SHA-256 correctly")
    func checksumComputation() {
        let testData = Data("Hello, World!".utf8)
        let checksum = BackupChecksum.sha256(of: testData)

        #expect(checksum.algorithm == "SHA-256")
        #expect(!checksum.value.isEmpty)

        // Verify deterministic
        let checksum2 = BackupChecksum.sha256(of: testData)
        #expect(checksum.value == checksum2.value)
    }

    @Test("BackupChecksum verifies correctly")
    func checksumVerification() {
        let testData = Data("Hello, World!".utf8)
        let checksum = BackupChecksum.sha256(of: testData)

        #expect(checksum.verify(against: testData))
        #expect(!checksum.verify(against: Data("Different data".utf8)))
    }
}

@Suite("BackupPayload Tests")
struct BackupPayloadTests {
    @Test("BackupPayload isEmpty works correctly")
    func payloadIsEmpty() throws {
        let empty = BackupPayload(
            exportedAt: Date(),
            appVersion: "1.0",
            metadata: BackupMetadata(personCount: 0, recordCount: 0, attachmentCount: 0, schemaCount: 0),
            persons: [],
            records: [],
            attachments: [],
            schemas: []
        )
        #expect(empty.isEmpty)

        let withPerson = BackupPayload(
            exportedAt: Date(),
            appVersion: "1.0",
            metadata: BackupMetadata(personCount: 1, recordCount: 0, attachmentCount: 0, schemaCount: 0),
            persons: [
                PersonBackup(
                    id: UUID(),
                    name: "Test",
                    dateOfBirth: nil,
                    labels: [],
                    notes: nil,
                    createdAt: Date(),
                    updatedAt: Date()
                )
            ],
            records: [],
            attachments: [],
            schemas: []
        )
        #expect(!withPerson.isEmpty)
    }
}

@Suite("BackupKDF Tests")
struct BackupKDFTests {
    @Test("BackupKDF defaultArgon2id has correct parameters")
    func backupKDFDefaults() {
        let kdf = BackupKDF.defaultArgon2id

        #expect(kdf.algorithm == "Argon2id")
        #expect(kdf.version == 19)
        #expect(kdf.memory == 67_108_864) // 64 MB
        #expect(kdf.iterations == 3)
        #expect(kdf.parallelism == 1)
        #expect(kdf.keyLength == 32)
    }
}

@Suite("BackupError Tests")
struct BackupErrorTests {
    @Test("BackupError provides descriptive messages")
    func backupErrorDescriptions() {
        let errors: [BackupError] = [
            .invalidPassword,
            .corruptedFile,
            .checksumMismatch,
            .unsupportedVersion("2.0"),
            .exportFailed("reason"),
            .importFailed("reason"),
            .noDataToExport,
            .passwordTooWeak,
            .fileOperationFailed("reason")
        ]

        for error in errors {
            let description = error.errorDescription
            #expect(description != nil)
            #expect(description?.isEmpty == false)
        }
    }

    @Test("BackupError is LocalizedError")
    func backupErrorIsLocalized() {
        let error: Error = BackupError.invalidPassword
        #expect(!error.localizedDescription.isEmpty)
    }
}
