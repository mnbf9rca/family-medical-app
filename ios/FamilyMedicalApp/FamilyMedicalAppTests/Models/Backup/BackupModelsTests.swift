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
    func payloadIsEmpty() {
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

@Suite("FieldValueBackup Conversion Tests")
struct FieldValueBackupConversionTests {
    // MARK: - Successful Conversions

    @Test("toFieldValue converts string correctly")
    func convertsString() throws {
        let backup = FieldValueBackup(type: "string", value: .string("hello"))
        let result = try backup.toFieldValue()
        #expect(result == .string("hello"))
    }

    @Test("toFieldValue converts int correctly")
    func convertsInt() throws {
        let backup = FieldValueBackup(type: "int", value: .int(42))
        let result = try backup.toFieldValue()
        #expect(result == .int(42))
    }

    @Test("toFieldValue converts double correctly")
    func convertsDouble() throws {
        let backup = FieldValueBackup(type: "double", value: .double(3.14))
        let result = try backup.toFieldValue()
        #expect(result == .double(3.14))
    }

    @Test("toFieldValue converts bool correctly")
    func convertsBool() throws {
        let backup = FieldValueBackup(type: "bool", value: .bool(true))
        let result = try backup.toFieldValue()
        #expect(result == .bool(true))
    }

    @Test("toFieldValue converts date correctly")
    func convertsDate() throws {
        let backup = FieldValueBackup(type: "date", value: .string("2024-01-15"))
        let result = try backup.toFieldValue()

        if case let .date(date) = result {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate]
            #expect(formatter.string(from: date) == "2024-01-15")
        } else {
            Issue.record("Expected date result")
        }
    }

    @Test("toFieldValue converts stringArray correctly")
    func convertsStringArray() throws {
        let backup = FieldValueBackup(type: "stringArray", value: .stringArray(["a", "b", "c"]))
        let result = try backup.toFieldValue()
        #expect(result == .stringArray(["a", "b", "c"]))
    }

    @Test("toFieldValue converts attachmentIds correctly")
    func convertsAttachmentIds() throws {
        let uuid1 = UUID()
        let uuid2 = UUID()
        let backup = FieldValueBackup(
            type: "attachmentIds",
            value: .stringArray([uuid1.uuidString, uuid2.uuidString])
        )
        let result = try backup.toFieldValue()
        #expect(result == .attachmentIds([uuid1, uuid2]))
    }

    // MARK: - Error Cases

    @Test("toFieldValue throws unknownType for unrecognized type")
    func throwsUnknownType() throws {
        let backup = FieldValueBackup(type: "unknownType", value: .string("value"))

        #expect(throws: FieldValueConversionError.self) {
            _ = try backup.toFieldValue()
        }

        do {
            _ = try backup.toFieldValue()
            Issue.record("Expected error to be thrown")
        } catch let error as FieldValueConversionError {
            if case let .unknownType(type) = error {
                #expect(type == "unknownType")
            } else {
                Issue.record("Expected unknownType error")
            }
        }
    }

    @Test("toFieldValue throws typeMismatch for string type with int value")
    func throwsTypeMismatchStringInt() throws {
        let backup = FieldValueBackup(type: "string", value: .int(42))

        #expect(throws: FieldValueConversionError.self) {
            _ = try backup.toFieldValue()
        }

        do {
            _ = try backup.toFieldValue()
        } catch let error as FieldValueConversionError {
            if case let .typeMismatch(expected, got) = error {
                #expect(expected == "string")
                #expect(got == "int")
            } else {
                Issue.record("Expected typeMismatch error")
            }
        }
    }

    @Test("toFieldValue throws typeMismatch for int type with string value")
    func throwsTypeMismatchIntString() throws {
        let backup = FieldValueBackup(type: "int", value: .string("not a number"))

        #expect(throws: FieldValueConversionError.self) {
            _ = try backup.toFieldValue()
        }
    }

    @Test("toFieldValue throws typeMismatch for double type with bool value")
    func throwsTypeMismatchDoubleBool() throws {
        let backup = FieldValueBackup(type: "double", value: .bool(true))

        #expect(throws: FieldValueConversionError.self) {
            _ = try backup.toFieldValue()
        }
    }

    @Test("toFieldValue throws typeMismatch for bool type with double value")
    func throwsTypeMismatchBoolDouble() throws {
        let backup = FieldValueBackup(type: "bool", value: .double(1.0))

        #expect(throws: FieldValueConversionError.self) {
            _ = try backup.toFieldValue()
        }
    }

    @Test("toFieldValue throws invalidDateString for unparseable date")
    func throwsInvalidDateString() throws {
        let backup = FieldValueBackup(type: "date", value: .string("not-a-date"))

        #expect(throws: FieldValueConversionError.self) {
            _ = try backup.toFieldValue()
        }

        do {
            _ = try backup.toFieldValue()
        } catch let error as FieldValueConversionError {
            if case let .invalidDateString(dateString) = error {
                #expect(dateString == "not-a-date")
            } else {
                Issue.record("Expected invalidDateString error")
            }
        }
    }

    @Test("toFieldValue throws typeMismatch for date type with non-string value")
    func throwsTypeMismatchDateInt() throws {
        let backup = FieldValueBackup(type: "date", value: .int(20_240_115))

        #expect(throws: FieldValueConversionError.self) {
            _ = try backup.toFieldValue()
        }
    }

    @Test("toFieldValue throws invalidUUID for malformed UUID in attachmentIds")
    func throwsInvalidUUID() throws {
        let validUUID = UUID()
        let backup = FieldValueBackup(
            type: "attachmentIds",
            value: .stringArray([validUUID.uuidString, "not-a-valid-uuid"])
        )

        #expect(throws: FieldValueConversionError.self) {
            _ = try backup.toFieldValue()
        }

        do {
            _ = try backup.toFieldValue()
        } catch let error as FieldValueConversionError {
            if case let .invalidUUID(uuidString) = error {
                #expect(uuidString == "not-a-valid-uuid")
            } else {
                Issue.record("Expected invalidUUID error")
            }
        }
    }

    @Test("toFieldValue throws typeMismatch for attachmentIds type with non-array value")
    func throwsTypeMismatchAttachmentIdsString() throws {
        let backup = FieldValueBackup(type: "attachmentIds", value: .string("not-an-array"))

        #expect(throws: FieldValueConversionError.self) {
            _ = try backup.toFieldValue()
        }
    }

    @Test("toFieldValue throws typeMismatch for stringArray type with non-array value")
    func throwsTypeMismatchStringArrayString() throws {
        let backup = FieldValueBackup(type: "stringArray", value: .string("not-an-array"))

        #expect(throws: FieldValueConversionError.self) {
            _ = try backup.toFieldValue()
        }
    }
}

@Suite("FieldValueConversionError Tests")
struct FieldValueConversionErrorTests {
    @Test("FieldValueConversionError provides descriptive messages")
    func fieldValueConversionErrorDescriptions() {
        let errors: [FieldValueConversionError] = [
            .unknownType("customType"),
            .typeMismatch(expected: "string", got: "int"),
            .invalidDateString("bad-date"),
            .invalidUUID("bad-uuid")
        ]

        for error in errors {
            let description = error.errorDescription
            #expect(description != nil)
            #expect(description?.isEmpty == false)
        }
    }

    @Test("FieldValueConversionError is Equatable")
    func fieldValueConversionErrorEquatable() {
        #expect(FieldValueConversionError.unknownType("a") == FieldValueConversionError.unknownType("a"))
        #expect(FieldValueConversionError.unknownType("a") != FieldValueConversionError.unknownType("b"))
        #expect(
            FieldValueConversionError.typeMismatch(expected: "x", got: "y") ==
                FieldValueConversionError.typeMismatch(expected: "x", got: "y")
        )
    }
}

@Suite("MedicalRecordBackup Content Conversion Tests")
struct MedicalRecordBackupContentTests {
    @Test("toRecordContent converts valid fields correctly")
    func toRecordContentValid() throws {
        let backup = MedicalRecordBackup(
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

        let content = try backup.toRecordContent()

        #expect(content.schemaId == "vaccine")
        #expect(content.allFields["name"] == .string("COVID-19"))
        #expect(content.allFields["dose"] == .int(1))
    }

    @Test("toRecordContent throws on invalid field value")
    func toRecordContentThrowsOnInvalidField() throws {
        let backup = MedicalRecordBackup(
            id: UUID(),
            personId: UUID(),
            schemaId: "vaccine",
            fields: [
                "name": FieldValueBackup(type: "string", value: .string("COVID-19")),
                "badField": FieldValueBackup(type: "unknownType", value: .string("value"))
            ],
            createdAt: Date(),
            updatedAt: Date(),
            version: 1,
            previousVersionId: nil
        )

        #expect(throws: FieldValueConversionError.self) {
            _ = try backup.toRecordContent()
        }
    }

    @Test("toRecordContent throws on type mismatch")
    func toRecordContentThrowsOnTypeMismatch() throws {
        let backup = MedicalRecordBackup(
            id: UUID(),
            personId: UUID(),
            schemaId: "vaccine",
            fields: [
                "dose": FieldValueBackup(type: "int", value: .string("one")) // Should be int
            ],
            createdAt: Date(),
            updatedAt: Date(),
            version: 1,
            previousVersionId: nil
        )

        #expect(throws: FieldValueConversionError.self) {
            _ = try backup.toRecordContent()
        }
    }
}
