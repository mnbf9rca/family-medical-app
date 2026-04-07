import Foundation
import Testing
@testable import FamilyMedicalApp

@Suite("BackupSchemaValidator Tests")
struct BackupSchemaValidatorTests {
    // MARK: - Model-Schema Consistency

    @Test("Serialized BackupFile validates against schema")
    func serializedBackupFileValidatesAgainstSchema() throws {
        // Create a realistic encrypted backup using the Swift models
        let file = BackupFile(
            schema: "https://recordwell.app/schemas/backup-v1.json",
            formatName: BackupFile.formatNameValue,
            formatVersion: BackupFile.currentVersion,
            generator: "FamilyMedicalApp/1.0.0 (iOS)",
            encrypted: true,
            checksum: BackupChecksum(algorithm: "SHA-256", value: "dGVzdA=="),
            encryption: BackupEncryption(
                algorithm: "AES-256-GCM",
                kdf: BackupKDF(
                    algorithm: "Argon2id",
                    version: 19,
                    salt: "dGVzdHNhbHQ=",
                    memory: 67_108_864,
                    iterations: 3,
                    parallelism: 1,
                    keyLength: 32
                ),
                nonce: "dGVzdG5vbmNl",
                tag: "dGVzdHRhZw=="
            ),
            ciphertext: "ZW5jcnlwdGVkZGF0YQ==",
            data: nil
        )

        // Serialize with Swift's JSONEncoder
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(file)

        // Validate against the JSON Schema
        let validator = BackupSchemaValidator.forTesting()
        let result = validator.validate(jsonData: jsonData)

        // The serialized Swift model MUST validate against the schema
        // If this fails, either the schema or the Swift models are wrong
        #expect(result.isValid, "Serialized BackupFile must validate against schema: \(result.errors)")
    }

    @Test("Serialized unencrypted BackupFile validates against schema")
    func serializedUnencryptedBackupFileValidatesAgainstSchema() throws {
        // Create an unencrypted backup with payload
        let payload = try BackupPayload(
            exportedAt: #require(ISO8601DateFormatter().date(from: "2026-02-01T12:00:00Z")),
            appVersion: "1.0.0",
            metadata: BackupMetadata(personCount: 1, recordCount: 0),
            persons: [
                PersonBackup(
                    id: UUID(),
                    name: "Test Person",
                    dateOfBirth: nil,
                    labels: ["family"],
                    notes: nil,
                    createdAt: Date(),
                    updatedAt: Date()
                )
            ],
            records: []
        )

        let file = BackupFile(
            schema: "https://recordwell.app/schemas/backup-v1.json",
            formatName: BackupFile.formatNameValue,
            formatVersion: BackupFile.currentVersion,
            generator: "FamilyMedicalApp/1.0.0 (iOS)",
            encrypted: false,
            checksum: BackupChecksum(algorithm: "SHA-256", value: "dGVzdA=="),
            encryption: nil,
            ciphertext: nil,
            data: payload
        )

        // Serialize with ISO8601 date formatting to match schema expectations
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(file)

        // Validate against the JSON Schema
        let validator = BackupSchemaValidator.forTesting()
        let result = validator.validate(jsonData: jsonData)

        #expect(result.isValid, "Serialized unencrypted BackupFile must validate against schema: \(result.errors)")
    }

    @Test("Serialized BackupFile with MedicalRecordBackup validates against schema")
    func serializedBackupFileWithRecordValidatesAgainstSchema() throws {
        // Build an envelope so we have realistic contentJSON bytes
        let immunization = try ImmunizationRecord(
            vaccineCode: "MMR",
            occurrenceDate: #require(ISO8601DateFormatter().date(from: "2026-01-15T10:00:00Z"))
        )
        let envelope = try RecordContentEnvelope(immunization)
        let personId = UUID()

        let payload = try BackupPayload(
            exportedAt: #require(ISO8601DateFormatter().date(from: "2026-02-01T12:00:00Z")),
            appVersion: "1.0.0",
            metadata: BackupMetadata(personCount: 1, recordCount: 1),
            persons: [
                PersonBackup(
                    id: personId,
                    name: "Test Person",
                    dateOfBirth: nil,
                    labels: ["family"],
                    notes: nil,
                    createdAt: Date(),
                    updatedAt: Date()
                )
            ],
            records: [
                MedicalRecordBackup(
                    from: MedicalRecord(id: UUID(), personId: personId, encryptedContent: Data()),
                    envelope: envelope
                )
            ]
        )

        let file = BackupFile(
            schema: "https://recordwell.app/schemas/backup-v1.json",
            formatName: BackupFile.formatNameValue,
            formatVersion: BackupFile.currentVersion,
            generator: "FamilyMedicalApp/1.0.0 (iOS)",
            encrypted: false,
            checksum: BackupChecksum(algorithm: "SHA-256", value: "dGVzdA=="),
            encryption: nil,
            ciphertext: nil,
            data: payload
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(file)

        let validator = BackupSchemaValidator.forTesting()
        let result = validator.validate(jsonData: jsonData)

        #expect(
            result.isValid,
            "Serialized BackupFile with record must validate against schema: \(result.errors)"
        )
    }

    // MARK: - Valid Files

    @Test("Valid encrypted backup passes validation")
    func validEncryptedBackupPassesValidation() {
        let validator = BackupSchemaValidator.forTesting()
        let validJSON = Data("""
        {
            "$schema": "https://recordwell.app/schemas/backup-v1.json",
            "formatName": "RecordWell Backup",
            "formatVersion": "1.0",
            "generator": "FamilyMedicalApp/1.0.0 (iOS)",
            "encrypted": true,
            "checksum": {"algorithm": "SHA-256", "value": "dGVzdA=="},
            "encryption": {
                "algorithm": "AES-256-GCM",
                "kdf": {
                    "algorithm": "Argon2id",
                    "version": 19,
                    "salt": "dGVzdHNhbHQ=",
                    "memory": 67108864,
                    "iterations": 3,
                    "parallelism": 1,
                    "keyLength": 32
                },
                "nonce": "dGVzdG5vbmNl",
                "tag": "dGVzdHRhZw=="
            },
            "ciphertext": "ZW5jcnlwdGVkZGF0YQ=="
        }
        """.utf8)

        let result = validator.validate(jsonData: validJSON)
        #expect(result.isValid)
    }

    @Test("Valid unencrypted backup passes validation")
    func validUnencryptedBackupPassesValidation() {
        let validator = BackupSchemaValidator.forTesting()
        let validJSON = Data("""
        {
            "formatName": "RecordWell Backup",
            "formatVersion": "1.0",
            "generator": "FamilyMedicalApp/1.0.0 (iOS)",
            "encrypted": false,
            "checksum": {"algorithm": "SHA-256", "value": "dGVzdA=="},
            "data": {
                "exportedAt": "2026-02-01T12:00:00Z",
                "appVersion": "1.0.0",
                "metadata": {"personCount": 0, "recordCount": 0},
                "persons": [],
                "records": []
            }
        }
        """.utf8)

        let result = validator.validate(jsonData: validJSON)
        #expect(result.isValid)
    }

    // MARK: - Invalid Files

    @Test("Missing required field fails validation")
    func missingRequiredFieldFailsValidation() {
        let validator = BackupSchemaValidator.forTesting()
        let invalidJSON = Data("""
        {
            "formatName": "RecordWell Backup",
            "formatVersion": "1.0",
            "encrypted": false
        }
        """.utf8)

        let result = validator.validate(jsonData: invalidJSON)
        #expect(!result.isValid)
        #expect(result.errors
            .contains { $0.contains("generator") || $0.contains("checksum") || $0.contains("required") })
    }

    @Test("Wrong formatName fails validation")
    func wrongFormatNameFailsValidation() {
        let validator = BackupSchemaValidator.forTesting()
        let invalidJSON = Data("""
        {
            "formatName": "Wrong Format",
            "formatVersion": "1.0",
            "generator": "Test",
            "encrypted": false,
            "checksum": {"algorithm": "SHA-256", "value": "dGVzdA=="},
            "data": {
                "exportedAt": "2026-02-01T12:00:00Z",
                "appVersion": "1.0.0",
                "metadata": {"personCount": 0, "recordCount": 0},
                "persons": [],
                "records": []
            }
        }
        """.utf8)

        let result = validator.validate(jsonData: invalidJSON)
        #expect(!result.isValid)
    }

    @Test("Invalid version format fails validation")
    func invalidVersionFormatFailsValidation() {
        let validator = BackupSchemaValidator.forTesting()
        let invalidJSON = Data("""
        {
            "formatName": "RecordWell Backup",
            "formatVersion": "v1.0.0",
            "generator": "Test",
            "encrypted": false,
            "checksum": {"algorithm": "SHA-256", "value": "dGVzdA=="},
            "data": {
                "exportedAt": "2026-02-01T12:00:00Z",
                "appVersion": "1.0.0",
                "metadata": {"personCount": 0, "recordCount": 0},
                "persons": [],
                "records": []
            }
        }
        """.utf8)

        let result = validator.validate(jsonData: invalidJSON)
        #expect(!result.isValid)
    }

    // MARK: - Invalid JSON

    @Test("Malformed JSON fails validation")
    func malformedJSONFailsValidation() {
        let validator = BackupSchemaValidator.forTesting()
        let malformedJSON = Data("{ not valid json }".utf8)

        let result = validator.validate(jsonData: malformedJSON)
        #expect(!result.isValid)
        #expect(result.errors.contains { $0.lowercased().contains("json") || $0.lowercased().contains("parse") })
    }

    // MARK: - Schema Version

    @Test("Returns correct schema version")
    func returnsCorrectSchemaVersion() {
        let validator = BackupSchemaValidator.forTesting()
        #expect(validator.schemaVersion == "1.0")
    }
}
