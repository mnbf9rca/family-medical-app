import Foundation

/// Type-safe dynamic value for medical record fields
///
/// Provides type safety while allowing arbitrary field structures in medical records.
/// Each case represents a supported field value type.
enum FieldValue: Codable, Equatable, Hashable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case date(Date)
    case attachmentIds([UUID])
    case stringArray([String])

    // MARK: - Type Checking Helpers

    /// Returns the string value if this is a string case, nil otherwise
    var stringValue: String? {
        if case let .string(value) = self {
            return value
        }
        return nil
    }

    /// Returns the int value if this is an int case, nil otherwise
    var intValue: Int? {
        if case let .int(value) = self {
            return value
        }
        return nil
    }

    /// Returns the double value if this is a double case, nil otherwise
    var doubleValue: Double? {
        if case let .double(value) = self {
            return value
        }
        return nil
    }

    /// Returns the bool value if this is a bool case, nil otherwise
    var boolValue: Bool? {
        if case let .bool(value) = self {
            return value
        }
        return nil
    }

    /// Returns the date value if this is a date case, nil otherwise
    var dateValue: Date? {
        if case let .date(value) = self {
            return value
        }
        return nil
    }

    /// Returns the attachment IDs if this is an attachmentIds case, nil otherwise
    var attachmentIdsValue: [UUID]? {
        if case let .attachmentIds(value) = self {
            return value
        }
        return nil
    }

    /// Returns the string array if this is a stringArray case, nil otherwise
    var stringArrayValue: [String]? {
        if case let .stringArray(value) = self {
            return value
        }
        return nil
    }

    // MARK: - Type Name

    /// Returns the type name for this value (e.g., "string", "int", "date")
    var typeName: String {
        switch self {
        case .string:
            "string"
        case .int:
            "int"
        case .double:
            "double"
        case .bool:
            "bool"
        case .date:
            "date"
        case .attachmentIds:
            "attachmentIds"
        case .stringArray:
            "stringArray"
        }
    }

    // MARK: - Codable Implementation

    private enum CodingKeys: String, CodingKey {
        case type
        case value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "string":
            let value = try container.decode(String.self, forKey: .value)
            self = .string(value)
        case "int":
            let value = try container.decode(Int.self, forKey: .value)
            self = .int(value)
        case "double":
            let value = try container.decode(Double.self, forKey: .value)
            self = .double(value)
        case "bool":
            let value = try container.decode(Bool.self, forKey: .value)
            self = .bool(value)
        case "date":
            let value = try container.decode(Date.self, forKey: .value)
            self = .date(value)
        case "attachmentIds":
            let value = try container.decode([UUID].self, forKey: .value)
            self = .attachmentIds(value)
        case "stringArray":
            let value = try container.decode([String].self, forKey: .value)
            self = .stringArray(value)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown FieldValue type: \(type)"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case let .string(value):
            try container.encode("string", forKey: .type)
            try container.encode(value, forKey: .value)
        case let .int(value):
            try container.encode("int", forKey: .type)
            try container.encode(value, forKey: .value)
        case let .double(value):
            try container.encode("double", forKey: .type)
            try container.encode(value, forKey: .value)
        case let .bool(value):
            try container.encode("bool", forKey: .type)
            try container.encode(value, forKey: .value)
        case let .date(value):
            try container.encode("date", forKey: .type)
            try container.encode(value, forKey: .value)
        case let .attachmentIds(value):
            try container.encode("attachmentIds", forKey: .type)
            try container.encode(value, forKey: .value)
        case let .stringArray(value):
            try container.encode("stringArray", forKey: .type)
            try container.encode(value, forKey: .value)
        }
    }
}
