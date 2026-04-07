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
            metadata: BackupMetadata(personCount: 1, recordCount: 5),
            persons: [],
            records: []
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
    func payloadIsEmpty() {
        let empty = BackupPayload(
            exportedAt: Date(),
            appVersion: "1.0",
            metadata: BackupMetadata(personCount: 0, recordCount: 0),
            persons: [],
            records: []
        )
        #expect(empty.isEmpty)

        let withPerson = BackupPayload(
            exportedAt: Date(),
            appVersion: "1.0",
            metadata: BackupMetadata(personCount: 1, recordCount: 0),
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
            records: []
        )
        #expect(!withPerson.isEmpty)
    }

    @Test("BackupPayload isEmpty considers providers")
    func payloadIsEmptyConsidersProviders() {
        let personId = UUID()
        let withProvider = BackupPayload(
            exportedAt: Date(),
            appVersion: "1.0",
            metadata: BackupMetadata(personCount: 0, recordCount: 0, providerCount: 1),
            persons: [],
            records: [],
            providers: [
                ProviderBackup(
                    id: UUID(),
                    personId: personId,
                    name: "Dr. Test",
                    organization: nil,
                    createdAt: Date(),
                    updatedAt: Date()
                )
            ]
        )
        #expect(!withProvider.isEmpty)
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

@Suite("MedicalRecordBackup Content Conversion Tests")
struct MedicalRecordBackupContentTests {
    @Test("toEnvelope converts valid record backup correctly")
    func toEnvelopeValid() throws {
        let immunization = ImmunizationRecord(vaccineCode: "COVID-19", occurrenceDate: Date())
        let contentJSON = try JSONEncoder().encode(immunization)
        let backup = MedicalRecordBackup(
            id: UUID(),
            personId: UUID(),
            recordType: "immunization",
            schemaVersion: 1,
            contentJSON: contentJSON,
            createdAt: Date(),
            updatedAt: Date(),
            version: 1,
            previousVersionId: nil
        )

        let envelope = try backup.toEnvelope()

        #expect(envelope.recordType == .immunization)
        #expect(envelope.schemaVersion == 1)

        let decoded = try envelope.decode(ImmunizationRecord.self)
        #expect(decoded.vaccineCode == "COVID-19")
    }

    @Test("toEnvelope throws on invalid record type")
    func toEnvelopeThrowsOnInvalidType() throws {
        let backup = MedicalRecordBackup(
            id: UUID(),
            personId: UUID(),
            recordType: "unknownType",
            schemaVersion: 1,
            contentJSON: Data("{}".utf8),
            createdAt: Date(),
            updatedAt: Date(),
            version: 1,
            previousVersionId: nil
        )

        #expect(throws: BackupError.self) {
            _ = try backup.toEnvelope()
        }
    }
}

@Suite("ProviderBackup Tests")
struct ProviderBackupTests {
    @Test("ProviderBackup converts from Provider model")
    func initFromProvider() {
        let provider = Provider(
            id: UUID(),
            name: "Dr. Smith",
            organization: "City Hospital",
            specialty: "Pediatrics"
        )
        let personId = UUID()

        let backup = ProviderBackup(from: provider, personId: personId)

        #expect(backup.id == provider.id)
        #expect(backup.personId == personId)
        #expect(backup.name == "Dr. Smith")
        #expect(backup.organization == "City Hospital")
        #expect(backup.specialty == "Pediatrics")
        #expect(backup.version == provider.version)
    }

    @Test("ProviderBackup converts back to Provider model")
    func toProvider() throws {
        let backup = ProviderBackup(
            id: UUID(),
            personId: UUID(),
            name: "Dr. Smith",
            organization: "City Hospital",
            specialty: "Cardiology",
            phone: "555-0100",
            address: "123 Main St",
            notes: "Great doctor",
            createdAt: Date(),
            updatedAt: Date(),
            version: 2,
            previousVersionId: UUID()
        )

        let provider = try backup.toProvider()

        #expect(provider.id == backup.id)
        #expect(provider.name == "Dr. Smith")
        #expect(provider.organization == "City Hospital")
        #expect(provider.specialty == "Cardiology")
        #expect(provider.phone == "555-0100")
        #expect(provider.address == "123 Main St")
        #expect(provider.notes == "Great doctor")
        #expect(provider.version == 2)
        #expect(provider.previousVersionId == backup.previousVersionId)
    }

    @Test("ProviderBackup toProvider throws when both name and organization are nil")
    func toProviderThrowsForInvalid() {
        let backup = ProviderBackup(
            id: UUID(),
            personId: UUID(),
            name: nil,
            organization: nil,
            createdAt: Date(),
            updatedAt: Date()
        )

        #expect(throws: BackupError.self) {
            _ = try backup.toProvider()
        }
    }

    @Test("ProviderBackup round-trips through JSON")
    func roundTrip() throws {
        let original = ProviderBackup(
            id: UUID(),
            personId: UUID(),
            name: "Dr. Test",
            organization: nil,
            specialty: "General",
            createdAt: Date(),
            updatedAt: Date(),
            version: 1,
            previousVersionId: nil
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ProviderBackup.self, from: data)

        #expect(decoded == original)
    }
}
