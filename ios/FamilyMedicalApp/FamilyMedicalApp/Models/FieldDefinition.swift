import Foundation

/// Type of a field value in a medical record
enum FieldType: String, Codable, CaseIterable, Hashable, Sendable {
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
enum ValidationRule: Codable, Equatable, Hashable, Sendable {
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

/// Text capitalization mode for string input fields
///
/// Controls how text is automatically capitalized during input.
/// This is a UI hint that affects the keyboard behavior, not validation.
enum TextCapitalizationMode: String, Codable, CaseIterable, Hashable, Sendable {
    /// No automatic capitalization
    case none

    /// Capitalize the first letter of each word (for names, titles)
    case words

    /// Capitalize the first letter of each sentence (default for prose)
    case sentences

    /// Capitalize all characters
    case allCharacters
}

/// Definition of a field in a medical record schema
///
/// Describes the structure, type, and validation rules for a single field.
/// Field IDs are UUIDs to support collision-free multi-device schema evolution
/// per ADR-0009.
struct FieldDefinition: Codable, Equatable, Hashable, Identifiable, Sendable {
    // MARK: - Identity (immutable after creation)

    /// Unique identifier for this field (UUID for collision-free multi-device support)
    ///
    /// Per ADR-0009: Field IDs are auto-generated UUIDs, not user-provided strings.
    /// Built-in fields use hardcoded UUIDs; user-created fields use `UUID()`.
    /// The `uuidString` is used as the dictionary key in RecordContent.
    let id: UUID

    /// Type of value this field holds (immutable - changing type is a breaking change)
    let fieldType: FieldType

    // MARK: - Display (mutable)

    /// Human-readable display name for UI (e.g., "Vaccine Name")
    var displayName: String

    /// Whether this field is required (must be present)
    ///
    /// Note: Changing from optional to required is soft-enforced at edit time only.
    /// Existing records remain valid.
    var isRequired: Bool

    /// Order in which this field should be displayed in UI (lower numbers first)
    var displayOrder: Int

    /// Optional placeholder text for UI input fields
    var placeholder: String?

    /// Optional help text explaining what this field is for
    var helpText: String?

    /// Optional validation rules for this field
    var validationRules: [ValidationRule]

    // MARK: - UI Hints

    /// Whether this field should use a multiline text input (default: false)
    ///
    /// Only applies to string fields. When true, the UI will render a multi-line
    /// text editor instead of a single-line text field. Useful for notes, descriptions,
    /// and other long-form content.
    var isMultiline: Bool

    /// Text capitalization mode for string fields (default: .sentences)
    ///
    /// Controls automatic capitalization behavior during text input.
    /// - `.words`: For names, titles (e.g., "Vaccine Name", "Provider")
    /// - `.sentences`: For prose, notes (e.g., "Notes", "Description")
    /// - `.none`: For codes, identifiers (e.g., "Batch Number")
    /// - `.allCharacters`: For abbreviations, codes requiring uppercase
    var capitalizationMode: TextCapitalizationMode

    // MARK: - Visibility

    /// Visibility state of this field (active, hidden, deprecated)
    ///
    /// Per ADR-0009: Hidden fields keep their data in records.
    /// Users can "remove" fields without losing existing data.
    var visibility: FieldVisibility

    // MARK: - Provenance (immutable after creation)

    /// Device ID that created this field, or UUID.zero for built-in fields
    ///
    /// Per ADR-0009: Users need to know "who added this field?" for trust decisions.
    /// Built-in fields use `.zero` to indicate system origin.
    let createdBy: UUID

    /// When this field was created
    ///
    /// Built-in fields use `.distantPast` to indicate they predate user data.
    let createdAt: Date

    // MARK: - Update Tracking (mutable)

    /// Device ID that last updated this field, or UUID.zero for built-in fields
    var updatedBy: UUID

    /// When this field was last updated
    var updatedAt: Date

    // MARK: - Initialization

    /// Full initializer with all properties
    init(
        id: UUID,
        displayName: String,
        fieldType: FieldType,
        isRequired: Bool = false,
        displayOrder: Int = 0,
        placeholder: String? = nil,
        helpText: String? = nil,
        validationRules: [ValidationRule] = [],
        isMultiline: Bool = false,
        capitalizationMode: TextCapitalizationMode = .sentences,
        visibility: FieldVisibility = .active,
        createdBy: UUID,
        createdAt: Date,
        updatedBy: UUID,
        updatedAt: Date
    ) {
        self.id = id
        self.displayName = displayName
        self.fieldType = fieldType
        self.isRequired = isRequired
        self.displayOrder = displayOrder
        self.placeholder = placeholder
        self.helpText = helpText
        self.validationRules = validationRules
        self.isMultiline = isMultiline
        self.capitalizationMode = capitalizationMode
        self.visibility = visibility
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.updatedBy = updatedBy
        self.updatedAt = updatedAt
    }

    /// Convenience initializer for built-in fields
    ///
    /// Sets provenance to system values:
    /// - `createdBy`/`updatedBy`: `.zero` (system origin)
    /// - `createdAt`/`updatedAt`: `.distantPast` (predates user data)
    /// - `visibility`: `.active`
    static func builtIn(
        id: UUID,
        displayName: String,
        fieldType: FieldType,
        isRequired: Bool = false,
        displayOrder: Int = 0,
        placeholder: String? = nil,
        helpText: String? = nil,
        validationRules: [ValidationRule] = [],
        isMultiline: Bool = false,
        capitalizationMode: TextCapitalizationMode = .sentences
    ) -> FieldDefinition {
        FieldDefinition(
            id: id,
            displayName: displayName,
            fieldType: fieldType,
            isRequired: isRequired,
            displayOrder: displayOrder,
            placeholder: placeholder,
            helpText: helpText,
            validationRules: validationRules,
            isMultiline: isMultiline,
            capitalizationMode: capitalizationMode,
            visibility: .active,
            createdBy: .zero,
            createdAt: .distantPast,
            updatedBy: .zero,
            updatedAt: .distantPast
        )
    }

    /// Convenience initializer for user-created fields
    ///
    /// Generates a new UUID and sets provenance to current device/time.
    ///
    /// - Parameter deviceId: The device ID creating this field
    static func userCreated(
        displayName: String,
        fieldType: FieldType,
        isRequired: Bool = false,
        displayOrder: Int = 0,
        placeholder: String? = nil,
        helpText: String? = nil,
        validationRules: [ValidationRule] = [],
        isMultiline: Bool = false,
        capitalizationMode: TextCapitalizationMode = .sentences,
        deviceId: UUID
    ) -> FieldDefinition {
        let now = Date()
        return FieldDefinition(
            id: UUID(),
            displayName: displayName,
            fieldType: fieldType,
            isRequired: isRequired,
            displayOrder: displayOrder,
            placeholder: placeholder,
            helpText: helpText,
            validationRules: validationRules,
            isMultiline: isMultiline,
            capitalizationMode: capitalizationMode,
            visibility: .active,
            createdBy: deviceId,
            createdAt: now,
            updatedBy: deviceId,
            updatedAt: now
        )
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
