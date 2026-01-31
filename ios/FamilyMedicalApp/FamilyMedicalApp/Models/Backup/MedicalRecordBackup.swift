import Foundation

/// Errors that can occur when converting backup field values to app field values
enum FieldValueConversionError: Error, LocalizedError, Equatable {
    /// The field type is not recognized
    case unknownType(String)

    /// The value type doesn't match the declared type
    case typeMismatch(expected: String, got: String)

    /// The date string could not be parsed
    case invalidDateString(String)

    /// A UUID string in the attachmentIds array is invalid
    case invalidUUID(String)

    var errorDescription: String? {
        switch self {
        case let .unknownType(type):
            "Unknown field type: \(type)"
        case let .typeMismatch(expected, got):
            "Type mismatch: expected \(expected), got \(got)"
        case let .invalidDateString(dateString):
            "Invalid date string: \(dateString)"
        case let .invalidUUID(uuid):
            "Invalid UUID: \(uuid)"
        }
    }
}

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
    ///
    /// - Throws: FieldValueConversionError if any field value cannot be converted
    func toRecordContent() throws -> RecordContent {
        var originalFields: [String: FieldValue] = [:]
        for (key, backupValue) in fields {
            originalFields[key] = try backupValue.toFieldValue()
        }
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

    func toFieldValue() throws -> FieldValue {
        switch type {
        case "string":
            return try convertString()
        case "int":
            return try convertInt()
        case "double":
            return try convertDouble()
        case "bool":
            return try convertBool()
        case "date":
            return try convertDate()
        case "attachmentIds":
            return try convertAttachmentIds()
        case "stringArray":
            return try convertStringArray()
        default:
            throw FieldValueConversionError.unknownType(type)
        }
    }

    private func convertString() throws -> FieldValue {
        guard case let .string(stringVal) = value else {
            throw FieldValueConversionError.typeMismatch(expected: "string", got: value.typeName)
        }
        return .string(stringVal)
    }

    private func convertInt() throws -> FieldValue {
        guard case let .int(intVal) = value else {
            throw FieldValueConversionError.typeMismatch(expected: "int", got: value.typeName)
        }
        return .int(intVal)
    }

    private func convertDouble() throws -> FieldValue {
        guard case let .double(doubleVal) = value else {
            throw FieldValueConversionError.typeMismatch(expected: "double", got: value.typeName)
        }
        return .double(doubleVal)
    }

    private func convertBool() throws -> FieldValue {
        guard case let .bool(boolVal) = value else {
            throw FieldValueConversionError.typeMismatch(expected: "bool", got: value.typeName)
        }
        return .bool(boolVal)
    }

    private func convertDate() throws -> FieldValue {
        guard case let .string(stringVal) = value else {
            throw FieldValueConversionError.typeMismatch(expected: "date (string)", got: value.typeName)
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        guard let date = formatter.date(from: stringVal) else {
            throw FieldValueConversionError.invalidDateString(stringVal)
        }
        return .date(date)
    }

    private func convertAttachmentIds() throws -> FieldValue {
        guard case let .stringArray(arr) = value else {
            throw FieldValueConversionError.typeMismatch(expected: "attachmentIds (stringArray)", got: value.typeName)
        }
        let uuids = try arr.map { uuidString -> UUID in
            guard let uuid = UUID(uuidString: uuidString) else {
                throw FieldValueConversionError.invalidUUID(uuidString)
            }
            return uuid
        }
        return .attachmentIds(uuids)
    }

    private func convertStringArray() throws -> FieldValue {
        guard case let .stringArray(arr) = value else {
            throw FieldValueConversionError.typeMismatch(expected: "stringArray", got: value.typeName)
        }
        return .stringArray(arr)
    }
}

/// Enum for JSON value encoding
enum FieldValueBackupValue: Codable, Equatable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case stringArray([String])

    /// Human-readable type name for error messages
    var typeName: String {
        switch self {
        case .string: "string"
        case .int: "int"
        case .double: "double"
        case .bool: "bool"
        case .stringArray: "stringArray"
        }
    }

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
