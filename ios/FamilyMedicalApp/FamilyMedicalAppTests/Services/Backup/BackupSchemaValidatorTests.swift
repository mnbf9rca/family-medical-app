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
        let validator = BackupSchemaValidator()
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
            metadata: BackupMetadata(personCount: 1, recordCount: 2, attachmentCount: 0, schemaCount: 0),
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
            records: [
                MedicalRecordBackup(
                    id: UUID(),
                    personId: UUID(),
                    schemaId: "vaccine",
                    fields: [
                        "name": FieldValueBackup(type: "string", value: .string("COVID-19")),
                        "dose": FieldValueBackup(type: "int", value: .int(1))
                    ],
                    createdAt: Date(),
                    updatedAt: Date(),
                    version: 1,
                    previousVersionId: nil
                )
            ],
            attachments: [],
            schemas: []
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
        let validator = BackupSchemaValidator()
        let result = validator.validate(jsonData: jsonData)

        // The serialized Swift model MUST validate against the schema
        #expect(result.isValid, "Serialized unencrypted BackupFile must validate against schema: \(result.errors)")
    }

    // MARK: - Valid Files

    @Test("Valid encrypted backup passes validation")
    func validEncryptedBackupPassesValidation() {
        let validator = BackupSchemaValidator()
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
        let validator = BackupSchemaValidator()
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
                "metadata": {"personCount": 0, "recordCount": 0, "attachmentCount": 0, "schemaCount": 0},
                "persons": [],
                "records": [],
                "attachments": [],
                "schemas": []
            }
        }
        """.utf8)

        let result = validator.validate(jsonData: validJSON)
        #expect(result.isValid)
    }

    // MARK: - Invalid Files

    @Test("Missing required field fails validation")
    func missingRequiredFieldFailsValidation() {
        let validator = BackupSchemaValidator()
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
        let validator = BackupSchemaValidator()
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
                "metadata": {"personCount": 0, "recordCount": 0, "attachmentCount": 0, "schemaCount": 0},
                "persons": [],
                "records": [],
                "attachments": [],
                "schemas": []
            }
        }
        """.utf8)

        let result = validator.validate(jsonData: invalidJSON)
        #expect(!result.isValid)
    }

    @Test("Invalid version format fails validation")
    func invalidVersionFormatFailsValidation() {
        let validator = BackupSchemaValidator()
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
                "metadata": {"personCount": 0, "recordCount": 0, "attachmentCount": 0, "schemaCount": 0},
                "persons": [],
                "records": [],
                "attachments": [],
                "schemas": []
            }
        }
        """.utf8)

        let result = validator.validate(jsonData: invalidJSON)
        #expect(!result.isValid)
    }

    // MARK: - DoS Protection

    @Test("Exceeding max nesting depth fails validation")
    func exceedingMaxNestingDepthFailsValidation() {
        let validator = BackupSchemaValidator(maxNestingDepth: 5)

        // Create deeply nested JSON (deeper than 5 levels)
        let deeplyNested = Data("""
        {"a":{"b":{"c":{"d":{"e":{"f":{"g":"too deep"}}}}}}}
        """.utf8)

        let result = validator.validate(jsonData: deeplyNested)
        #expect(!result.isValid)
        #expect(result.errors.contains { $0.contains("depth") || $0.contains("nesting") })
    }

    @Test("Exceeding max array size fails validation")
    func exceedingMaxArraySizeFailsValidation() throws {
        let validator = BackupSchemaValidator(maxArraySize: 10)

        // Create JSON with array larger than 10 items
        let largeArray = Array(repeating: "item", count: 20)
        let json = try JSONSerialization.data(withJSONObject: ["items": largeArray])

        let result = validator.validate(jsonData: json)
        #expect(!result.isValid)
        #expect(result.errors.contains { $0.contains("array") || $0.contains("size") })
    }

    // MARK: - Invalid JSON

    @Test("Malformed JSON fails validation")
    func malformedJSONFailsValidation() {
        let validator = BackupSchemaValidator()
        let malformedJSON = Data("{ not valid json }".utf8)

        let result = validator.validate(jsonData: malformedJSON)
        #expect(!result.isValid)
        #expect(result.errors.contains { $0.lowercased().contains("json") || $0.lowercased().contains("parse") })
    }

    // MARK: - Schema Version

    @Test("Returns correct schema version")
    func returnsCorrectSchemaVersion() {
        let validator = BackupSchemaValidator()
        #expect(validator.schemaVersion == "1.0")
    }

    // MARK: - Edge Cases for DoS Limits

    @Test("Empty arrays pass DoS validation")
    func emptyArraysPassDoSValidation() {
        let validator = BackupSchemaValidator(maxArraySize: 10)
        let json = Data("""
        {"items": [], "nested": {"more": []}}
        """.utf8)

        let result = validator.validate(jsonData: json)
        // Will fail schema validation but should pass DoS checks
        #expect(!result.errors.contains { $0.contains("array") && $0.contains("size") })
    }

    @Test("Empty dictionaries pass DoS validation")
    func emptyDictionariesPassDoSValidation() {
        let validator = BackupSchemaValidator(maxNestingDepth: 3)
        let json = Data("""
        {"a": {}, "b": {"c": {}}}
        """.utf8)

        let result = validator.validate(jsonData: json)
        // Will fail schema validation but should pass DoS checks
        #expect(!result.errors.contains { $0.contains("depth") || $0.contains("nesting") })
    }

    @Test("Primitive root value passes depth check")
    func primitiveRootValuePassesDepthCheck() {
        let validator = BackupSchemaValidator(maxNestingDepth: 1)
        let json = Data("\"just a string\"".utf8)

        let result = validator.validate(jsonData: json)
        // Will fail schema validation but should pass DoS checks
        #expect(!result.errors.contains { $0.contains("depth") || $0.contains("nesting") })
    }

    @Test("Deeply nested arrays trigger depth limit")
    func deeplyNestedArraysTriggerDepthLimit() {
        let validator = BackupSchemaValidator(maxNestingDepth: 3)
        let json = Data("""
        [[[[["too deep"]]]]]
        """.utf8)

        let result = validator.validate(jsonData: json)
        #expect(!result.isValid)
        #expect(result.errors.contains { $0.contains("depth") || $0.contains("nesting") })
    }

    @Test("Nested array sizes are checked")
    func nestedArraySizesAreChecked() {
        let validator = BackupSchemaValidator(maxArraySize: 5)
        let json = Data("""
        {"outer": [{"inner": [1, 2, 3, 4, 5, 6, 7]}]}
        """.utf8)

        let result = validator.validate(jsonData: json)
        #expect(!result.isValid)
        #expect(result.errors.contains { $0.contains("array") || $0.contains("size") })
    }

    @Test("Within limits passes DoS checks")
    func withinLimitsPassesDoSChecks() {
        let validator = BackupSchemaValidator(maxNestingDepth: 10, maxArraySize: 100)
        let json = Data("""
        {"a": {"b": {"c": [1, 2, 3]}}}
        """.utf8)

        let result = validator.validate(jsonData: json)
        // Will fail schema validation but should pass DoS checks
        #expect(!result.errors.contains { $0.contains("depth") || $0.contains("array") })
    }
}
