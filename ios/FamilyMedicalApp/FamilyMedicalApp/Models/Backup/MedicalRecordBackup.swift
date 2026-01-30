import Foundation

/// Decrypted medical record data for backup
struct MedicalRecordBackup: Codable, Equatable {
    let id: UUID
    let personId: UUID
    let schemaId: String?
    let fields: [String: FieldValueBackup]
    let createdAt: Date
    let updatedAt: Date
    let version: Int
    let previousVersionId: UUID?

    /// Create from MedicalRecord and decrypted RecordContent
    init(from record: MedicalRecord, content: RecordContent) {
        self.id = record.id
        self.personId = record.personId
        self.schemaId = content.schemaId
        self.fields = content.allFields.mapValues { FieldValueBackup(from: $0) }
        self.createdAt = record.createdAt
        self.updatedAt = record.updatedAt
        self.version = record.version
        self.previousVersionId = record.previousVersionId
    }

    /// Direct initialization
    init(
        id: UUID,
        personId: UUID,
        schemaId: String?,
        fields: [String: FieldValueBackup],
        createdAt: Date,
        updatedAt: Date,
        version: Int,
        previousVersionId: UUID?
    ) {
        self.id = id
        self.personId = personId
        self.schemaId = schemaId
        self.fields = fields
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.version = version
        self.previousVersionId = previousVersionId
    }

    /// Convert to RecordContent for import
    func toRecordContent() -> RecordContent {
        let originalFields = fields.mapValues { $0.toFieldValue() }
        return RecordContent(schemaId: schemaId, fields: originalFields)
    }
}

/// Field value with explicit type for unambiguous JSON encoding
struct FieldValueBackup: Codable, Equatable {
    let type: String
    let value: FieldValueBackupValue

    init(type: String, value: FieldValueBackupValue) {
        self.type = type
        self.value = value
    }

    init(from fieldValue: FieldValue) {
        switch fieldValue {
        case let .string(stringVal):
            self.type = "string"
            self.value = .string(stringVal)
        case let .int(intVal):
            self.type = "int"
            self.value = .int(intVal)
        case let .double(doubleVal):
            self.type = "double"
            self.value = .double(doubleVal)
        case let .bool(boolVal):
            self.type = "bool"
            self.value = .bool(boolVal)
        case let .date(date):
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate]
            self.type = "date"
            self.value = .string(formatter.string(from: date))
        case let .attachmentIds(ids):
            self.type = "attachmentIds"
            self.value = .stringArray(ids.map(\.uuidString))
        case let .stringArray(arr):
            self.type = "stringArray"
            self.value = .stringArray(arr)
        }
    }

    func toFieldValue() -> FieldValue {
        switch type {
        case "string":
            if case let .string(stringVal) = value { return .string(stringVal) }
        case "int":
            if case let .int(intVal) = value { return .int(intVal) }
        case "double":
            if case let .double(doubleVal) = value { return .double(doubleVal) }
        case "bool":
            if case let .bool(boolVal) = value { return .bool(boolVal) }
        case "date":
            if case let .string(stringVal) = value {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withFullDate]
                if let date = formatter.date(from: stringVal) {
                    return .date(date)
                }
            }
        case "attachmentIds":
            if case let .stringArray(arr) = value {
                return .attachmentIds(arr.compactMap { UUID(uuidString: $0) })
            }
        case "stringArray":
            if case let .stringArray(arr) = value { return .stringArray(arr) }
        default:
            break
        }
        return .string("") // Fallback
    }
}

/// Enum for JSON value encoding
enum FieldValueBackupValue: Codable, Equatable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case stringArray([String])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let boolVal = try? container.decode(Bool.self) {
            self = .bool(boolVal)
        } else if let intVal = try? container.decode(Int.self) {
            self = .int(intVal)
        } else if let doubleVal = try? container.decode(Double.self) {
            self = .double(doubleVal)
        } else if let stringVal = try? container.decode(String.self) {
            self = .string(stringVal)
        } else if let arr = try? container.decode([String].self) {
            self = .stringArray(arr)
        } else {
            throw DecodingError.typeMismatch(
                FieldValueBackupValue.self,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unknown value type")
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .string(stringVal): try container.encode(stringVal)
        case let .int(intVal): try container.encode(intVal)
        case let .double(doubleVal): try container.encode(doubleVal)
        case let .bool(boolVal): try container.encode(boolVal)
        case let .stringArray(arr): try container.encode(arr)
        }
    }
}
