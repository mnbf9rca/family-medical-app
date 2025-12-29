import Foundation

/// Type of a field value in a medical record
enum FieldType: String, Codable, CaseIterable, Hashable {
    case string
    case int
    case double
    case bool
    case date
    case attachmentIds
    case stringArray

    /// Human-readable display name for this field type
    var displayName: String {
        switch self {
        case .string:
            "Text"
        case .int:
            "Number (Integer)"
        case .double:
            "Number (Decimal)"
        case .bool:
            "Yes/No"
        case .date:
            "Date"
        case .attachmentIds:
            "Attachments"
        case .stringArray:
            "List of Text"
        }
    }

    /// Check if a FieldValue matches this type
    func matches(_ value: FieldValue) -> Bool {
        switch (self, value) {
        case (.string, .string):
            true
        case (.int, .int):
            true
        case (.double, .double):
            true
        case (.bool, .bool):
            true
        case (.date, .date):
            true
        case (.attachmentIds, .attachmentIds):
            true
        case (.stringArray, .stringArray):
            true
        default:
            false
        }
    }
}

/// Validation rule for a field
enum ValidationRule: Codable, Equatable, Hashable {
    case minLength(Int)
    case maxLength(Int)
    case minValue(Double)
    case maxValue(Double)
    case minDate(Date)
    case maxDate(Date)
    case pattern(String) // Regex pattern for string validation

    // MARK: - Codable Implementation

    private enum CodingKeys: String, CodingKey {
        case type
        case value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "minLength":
            let value = try container.decode(Int.self, forKey: .value)
            self = .minLength(value)
        case "maxLength":
            let value = try container.decode(Int.self, forKey: .value)
            self = .maxLength(value)
        case "minValue":
            let value = try container.decode(Double.self, forKey: .value)
            self = .minValue(value)
        case "maxValue":
            let value = try container.decode(Double.self, forKey: .value)
            self = .maxValue(value)
        case "minDate":
            let value = try container.decode(Date.self, forKey: .value)
            self = .minDate(value)
        case "maxDate":
            let value = try container.decode(Date.self, forKey: .value)
            self = .maxDate(value)
        case "pattern":
            let value = try container.decode(String.self, forKey: .value)
            self = .pattern(value)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown ValidationRule type: \(type)"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case let .minLength(value):
            try container.encode("minLength", forKey: .type)
            try container.encode(value, forKey: .value)
        case let .maxLength(value):
            try container.encode("maxLength", forKey: .type)
            try container.encode(value, forKey: .value)
        case let .minValue(value):
            try container.encode("minValue", forKey: .type)
            try container.encode(value, forKey: .value)
        case let .maxValue(value):
            try container.encode("maxValue", forKey: .type)
            try container.encode(value, forKey: .value)
        case let .minDate(value):
            try container.encode("minDate", forKey: .type)
            try container.encode(value, forKey: .value)
        case let .maxDate(value):
            try container.encode("maxDate", forKey: .type)
            try container.encode(value, forKey: .value)
        case let .pattern(value):
            try container.encode("pattern", forKey: .type)
            try container.encode(value, forKey: .value)
        }
    }
}

/// Definition of a field in a medical record schema
///
/// Describes the structure, type, and validation rules for a single field
struct FieldDefinition: Codable, Equatable, Hashable, Identifiable {
    // MARK: - Properties

    /// Unique identifier for this field (also used as the dictionary key in RecordContent)
    let id: String

    /// Human-readable display name for UI (e.g., "Vaccine Name")
    let displayName: String

    /// Type of value this field holds
    let fieldType: FieldType

    /// Whether this field is required (must be present)
    let isRequired: Bool

    /// Order in which this field should be displayed in UI (lower numbers first)
    let displayOrder: Int

    /// Optional placeholder text for UI input fields
    var placeholder: String?

    /// Optional help text explaining what this field is for
    var helpText: String?

    /// Optional validation rules for this field
    var validationRules: [ValidationRule]

    // MARK: - Initialization

    init(
        id: String,
        displayName: String,
        fieldType: FieldType,
        isRequired: Bool = false,
        displayOrder: Int = 0,
        placeholder: String? = nil,
        helpText: String? = nil,
        validationRules: [ValidationRule] = []
    ) {
        self.id = id
        self.displayName = displayName
        self.fieldType = fieldType
        self.isRequired = isRequired
        self.displayOrder = displayOrder
        self.placeholder = placeholder
        self.helpText = helpText
        self.validationRules = validationRules
    }

    // MARK: - Validation

    /// Validate a field value against this definition
    ///
    /// - Parameter value: The field value to validate
    /// - Throws: ModelError if validation fails
    func validate(_ value: FieldValue?) throws {
        // Check if required field is present
        guard let value else {
            if isRequired {
                throw ModelError.fieldRequired(fieldName: displayName)
            }
            return
        }

        // Check type match
        guard fieldType.matches(value) else {
            throw ModelError.fieldTypeMismatch(
                fieldName: displayName,
                expected: fieldType.displayName,
                got: value.typeName
            )
        }

        // Apply validation rules
        for rule in validationRules {
            try applyRule(rule, to: value)
        }
    }

    private func applyRule(_ rule: ValidationRule, to value: FieldValue) throws {
        switch (rule, value) {
        case let (.minLength(min), .string(str)):
            if str.count < min {
                throw ModelError.stringTooShort(fieldName: displayName, minLength: min)
            }
        case let (.maxLength(max), .string(str)):
            if str.count > max {
                throw ModelError.stringTooLong(fieldName: displayName, maxLength: max)
            }
        case let (.minValue(min), .int(num)):
            if Double(num) < min {
                throw ModelError.numberOutOfRange(fieldName: displayName, min: min, max: nil)
            }
        case let (.maxValue(max), .int(num)):
            if Double(num) > max {
                throw ModelError.numberOutOfRange(fieldName: displayName, min: nil, max: max)
            }
        case let (.minValue(min), .double(num)):
            if num < min {
                throw ModelError.numberOutOfRange(fieldName: displayName, min: min, max: nil)
            }
        case let (.maxValue(max), .double(num)):
            if num > max {
                throw ModelError.numberOutOfRange(fieldName: displayName, min: nil, max: max)
            }
        case let (.minDate(min), .date(date)):
            if date < min {
                throw ModelError.dateOutOfRange(fieldName: displayName, min: min, max: nil)
            }
        case let (.maxDate(max), .date(date)):
            if date > max {
                throw ModelError.dateOutOfRange(fieldName: displayName, min: nil, max: max)
            }
        case let (.pattern(regex), .string(str)):
            try validatePattern(regex, against: str)
        default:
            break
        }
    }

    private func validatePattern(_ pattern: String, against str: String) throws {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            throw ModelError.validationFailed(fieldName: displayName, reason: "Invalid regex pattern")
        }
        let range = NSRange(str.startIndex ..< str.endIndex, in: str)
        if regex.firstMatch(in: str, range: range) == nil {
            throw ModelError.validationFailed(fieldName: displayName, reason: "Does not match required pattern")
        }
    }
}
