import Foundation
import Testing
@testable import FamilyMedicalApp

@Suite("PersonBackup Tests")
struct PersonBackupTests {
    @Test("PersonBackup converts from Person model")
    func personBackupConversion() throws {
        let person = try Person(
            id: UUID(),
            name: "Test Person",
            dateOfBirth: Date(),
            labels: ["child", "dependent"],
            notes: "Test notes"
        )

        let backup = PersonBackup(from: person)

        #expect(backup.id == person.id)
        #expect(backup.name == person.name)
        #expect(backup.labels == person.labels)
    }

    @Test("PersonBackup converts back to Person model")
    func personBackupToPerson() throws {
        let backup = PersonBackup(
            id: UUID(),
            name: "Test",
            dateOfBirth: Date(),
            labels: ["spouse"],
            notes: "Notes",
            createdAt: Date(),
            updatedAt: Date()
        )

        let person = try backup.toPerson()

        #expect(person.id == backup.id)
        #expect(person.name == backup.name)
    }

    @Test("PersonBackup round-trips through JSON")
    func personBackupRoundTrip() throws {
        let original = PersonBackup(
            id: UUID(),
            name: "John Doe",
            dateOfBirth: Date(timeIntervalSince1970: 1_000_000),
            labels: ["child", "dependent"],
            notes: "Some notes",
            createdAt: Date(),
            updatedAt: Date()
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(PersonBackup.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.name == original.name)
        #expect(decoded.labels == original.labels)
    }
}

@Suite("MedicalRecordBackup Tests")
struct MedicalRecordBackupTests {
    @Test("MedicalRecordBackup direct initialization works")
    func medicalRecordBackupInit() {
        let backup = MedicalRecordBackup(
            id: UUID(),
            personId: UUID(),
            schemaId: "vaccine",
            fields: [
                "field-1": FieldValueBackup(type: "string", value: .string("Test"))
            ],
            createdAt: Date(),
            updatedAt: Date(),
            version: 1,
            previousVersionId: nil
        )

        #expect(backup.schemaId == "vaccine")
        #expect(backup.fields.count == 1)
    }

    @Test("MedicalRecordBackup toRecordContent works")
    func medicalRecordBackupToContent() throws {
        let backup = MedicalRecordBackup(
            id: UUID(),
            personId: UUID(),
            schemaId: "vaccine",
            fields: [
                "field-1": FieldValueBackup(type: "string", value: .string("COVID-19"))
            ],
            createdAt: Date(),
            updatedAt: Date(),
            version: 1,
            previousVersionId: nil
        )

        let content = try backup.toRecordContent()

        #expect(content.schemaId == "vaccine")
    }
}

@Suite("FieldValueBackup Tests")
struct FieldValueBackupTests {
    @Test("FieldValueBackup encodes string type correctly")
    func fieldValueBackupString() throws {
        let value = FieldValueBackup(type: "string", value: .string("text"))

        let encoder = JSONEncoder()
        let data = try encoder.encode(value)
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw BackupError.corruptedFile
        }

        #expect(jsonString.contains("\"type\":\"string\"") || jsonString.contains("\"type\" : \"string\""))
        #expect(jsonString.contains("text"))
    }

    @Test("FieldValueBackup encodes int type correctly")
    func fieldValueBackupInt() throws {
        let value = FieldValueBackup(type: "int", value: .int(42))

        let encoder = JSONEncoder()
        let data = try encoder.encode(value)
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw BackupError.corruptedFile
        }

        #expect(jsonString.contains("\"type\":\"int\"") || jsonString.contains("\"type\" : \"int\""))
        #expect(jsonString.contains("42"))
    }

    @Test("FieldValueBackup encodes all types correctly")
    func fieldValueBackupAllTypes() throws {
        let values: [String: FieldValueBackup] = [
            "string": .init(type: "string", value: .string("text")),
            "int": .init(type: "int", value: .int(42)),
            "double": .init(type: "double", value: .double(3.14)),
            "bool": .init(type: "bool", value: .bool(true)),
            "date": .init(type: "date", value: .string("2025-01-30")),
            "attachmentIds": .init(type: "attachmentIds", value: .stringArray(["id1", "id2"])),
            "stringArray": .init(type: "stringArray", value: .stringArray(["a", "b"]))
        ]

        let encoder = JSONEncoder()
        let data = try encoder.encode(values)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode([String: FieldValueBackup].self, from: data)

        #expect(decoded["string"]?.type == "string")
        #expect(decoded["int"]?.type == "int")
        #expect(decoded["double"]?.type == "double")
        #expect(decoded["bool"]?.type == "bool")
        #expect(decoded["date"]?.type == "date")
        #expect(decoded["attachmentIds"]?.type == "attachmentIds")
        #expect(decoded["stringArray"]?.type == "stringArray")
    }

    @Test("FieldValueBackup converts from FieldValue")
    func fieldValueBackupFromFieldValue() {
        let stringBackup = FieldValueBackup(from: .string("test"))
        #expect(stringBackup.type == "string")

        let intBackup = FieldValueBackup(from: .int(42))
        #expect(intBackup.type == "int")

        let boolBackup = FieldValueBackup(from: .bool(true))
        #expect(boolBackup.type == "bool")

        let dateBackup = FieldValueBackup(from: .date(Date()))
        #expect(dateBackup.type == "date")

        let attachmentBackup = FieldValueBackup(from: .attachmentIds([UUID()]))
        #expect(attachmentBackup.type == "attachmentIds")
    }

    @Test("FieldValueBackup converts back to FieldValue")
    func fieldValueBackupToFieldValue() throws {
        let stringValue = try FieldValueBackup(type: "string", value: .string("test")).toFieldValue()
        #expect(stringValue == .string("test"))

        let intValue = try FieldValueBackup(type: "int", value: .int(42)).toFieldValue()
        #expect(intValue == .int(42))

        let boolValue = try FieldValueBackup(type: "bool", value: .bool(true)).toFieldValue()
        #expect(boolValue == .bool(true))
    }

    @Test("FieldValueBackup converts double back to FieldValue")
    func fieldValueBackupDoubleToFieldValue() throws {
        let doubleBackup = FieldValueBackup(from: .double(3.14))
        #expect(doubleBackup.type == "double")

        let doubleValue = try FieldValueBackup(type: "double", value: .double(3.14)).toFieldValue()
        #expect(doubleValue == .double(3.14))
    }

    @Test("FieldValueBackup converts date back to FieldValue")
    func fieldValueBackupDateToFieldValue() throws {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        let dateString = "2025-01-30"

        let dateValue = try FieldValueBackup(type: "date", value: .string(dateString)).toFieldValue()

        if case let .date(date) = dateValue {
            #expect(formatter.string(from: date) == dateString)
        } else {
            Issue.record("Expected date value")
        }
    }

    @Test("FieldValueBackup converts stringArray back to FieldValue")
    func fieldValueBackupStringArrayToFieldValue() throws {
        let stringArrayBackup = FieldValueBackup(from: .stringArray(["a", "b", "c"]))
        #expect(stringArrayBackup.type == "stringArray")

        let stringArrayValue = try FieldValueBackup(type: "stringArray", value: .stringArray(["x", "y"])).toFieldValue()
        #expect(stringArrayValue == .stringArray(["x", "y"]))
    }

    @Test("FieldValueBackup converts attachmentIds back to FieldValue")
    func fieldValueBackupAttachmentIdsToFieldValue() throws {
        let id1 = UUID()
        let id2 = UUID()

        let attachmentValue = try FieldValueBackup(
            type: "attachmentIds",
            value: .stringArray([id1.uuidString, id2.uuidString])
        ).toFieldValue()

        if case let .attachmentIds(ids) = attachmentValue {
            #expect(ids.count == 2)
            #expect(ids.contains(id1))
            #expect(ids.contains(id2))
        } else {
            Issue.record("Expected attachmentIds value")
        }
    }

    @Test("FieldValueBackup throws for unknown type")
    func fieldValueBackupUnknownTypeThrows() {
        let backup = FieldValueBackup(type: "unknownType", value: .string("test"))
        #expect(throws: FieldValueConversionError.self) {
            _ = try backup.toFieldValue()
        }
    }

    @Test("FieldValueBackup throws for invalid date string")
    func fieldValueBackupInvalidDateThrows() {
        let backup = FieldValueBackup(type: "date", value: .string("not-a-date"))
        #expect(throws: FieldValueConversionError.self) {
            _ = try backup.toFieldValue()
        }
    }

    @Test("FieldValueBackupValue decodes from JSON correctly")
    func fieldValueBackupValueDecoding() throws {
        // Test bool decoding
        let boolJSON = Data("true".utf8)
        let boolDecoded = try JSONDecoder().decode(FieldValueBackupValue.self, from: boolJSON)
        #expect(boolDecoded == .bool(true))

        // Test int decoding
        let intJSON = Data("42".utf8)
        let intDecoded = try JSONDecoder().decode(FieldValueBackupValue.self, from: intJSON)
        #expect(intDecoded == .int(42))

        // Test double decoding
        let doubleJSON = Data("3.14".utf8)
        let doubleDecoded = try JSONDecoder().decode(FieldValueBackupValue.self, from: doubleJSON)
        #expect(doubleDecoded == .double(3.14))

        // Test string decoding
        let stringJSON = Data("\"hello\"".utf8)
        let stringDecoded = try JSONDecoder().decode(FieldValueBackupValue.self, from: stringJSON)
        #expect(stringDecoded == .string("hello"))

        // Test array decoding
        let arrayJSON = Data("[\"a\",\"b\"]".utf8)
        let arrayDecoded = try JSONDecoder().decode(FieldValueBackupValue.self, from: arrayJSON)
        #expect(arrayDecoded == .stringArray(["a", "b"]))
    }
}

@Suite("AttachmentBackup Tests")
struct AttachmentBackupTests {
    @Test("AttachmentBackup encodes content as base64")
    func attachmentBackupBase64() {
        let content = Data("Test file content".utf8)
        let thumbnail = Data("Thumbnail".utf8)

        let backup = AttachmentBackup(
            id: UUID(),
            personId: UUID(),
            linkedRecordIds: [],
            fileName: "test.txt",
            mimeType: "text/plain",
            content: content,
            thumbnail: thumbnail,
            uploadedAt: Date()
        )

        #expect(backup.contentData == content)
        #expect(backup.thumbnailData == thumbnail)
    }

    @Test("AttachmentBackup handles nil thumbnail")
    func attachmentBackupNilThumbnail() {
        let backup = AttachmentBackup(
            id: UUID(),
            personId: UUID(),
            linkedRecordIds: [],
            fileName: "test.txt",
            mimeType: "text/plain",
            content: Data("content".utf8),
            thumbnail: nil,
            uploadedAt: Date()
        )

        #expect(backup.thumbnailData == nil)
    }
}

@Suite("SchemaBackup Tests")
struct SchemaBackupTests {
    @Test("SchemaBackup stores schema correctly")
    func schemaBackupInit() throws {
        let schema = try RecordSchema(
            id: "custom-test",
            displayName: "Test Schema",
            iconSystemName: "star",
            fields: []
        )

        let backup = SchemaBackup(personId: UUID(), schema: schema)

        #expect(backup.schema.id == "custom-test")
        #expect(backup.schema.displayName == "Test Schema")
    }
}
