import Foundation

/// Container for medical record field values
///
/// Wraps a dictionary of field values and provides validation against schemas.
/// This is the "document" in the schema-overlay architecture - it can hold any fields.
struct RecordContent: Codable, Equatable {
    // MARK: - Properties

    /// The actual field values stored as a dictionary
    private var fields: [String: FieldValue]

    // MARK: - Initialization

    /// Initialize with an empty field dictionary
    init() {
        fields = [:]
    }

    /// Initialize with a pre-populated field dictionary
    ///
    /// - Parameter fields: Initial field values
    init(fields: [String: FieldValue]) {
        self.fields = fields
    }

    // MARK: - Field Access

    /// Access field values by key
    subscript(key: String) -> FieldValue? {
        get {
            fields[key]
        }
        set {
            fields[key] = newValue
        }
    }

    /// Get all fields as a dictionary
    var allFields: [String: FieldValue] {
        fields
    }

    /// Get all field keys
    var fieldKeys: [String] {
        Array(fields.keys)
    }

    /// Check if a field exists
    ///
    /// - Parameter key: The field key to check
    /// - Returns: true if the field exists, false otherwise
    func hasField(_ key: String) -> Bool {
        fields[key] != nil
    }

    /// Remove a field
    ///
    /// - Parameter key: The field key to remove
    mutating func removeField(_ key: String) {
        fields.removeValue(forKey: key)
    }

    /// Remove all fields
    mutating func removeAllFields() {
        fields.removeAll()
    }

    // MARK: - Convenience Accessors

    /// Get a string value for a field
    ///
    /// - Parameter key: The field key
    /// - Returns: The string value, or nil if field doesn't exist or isn't a string
    func getString(_ key: String) -> String? {
        fields[key]?.stringValue
    }

    /// Get an int value for a field
    ///
    /// - Parameter key: The field key
    /// - Returns: The int value, or nil if field doesn't exist or isn't an int
    func getInt(_ key: String) -> Int? {
        fields[key]?.intValue
    }

    /// Get a double value for a field
    ///
    /// - Parameter key: The field key
    /// - Returns: The double value, or nil if field doesn't exist or isn't a double
    func getDouble(_ key: String) -> Double? {
        fields[key]?.doubleValue
    }

    /// Get a bool value for a field
    ///
    /// - Parameter key: The field key
    /// - Returns: The bool value, or nil if field doesn't exist or isn't a bool
    func getBool(_ key: String) -> Bool? {
        fields[key]?.boolValue
    }

    /// Get a date value for a field
    ///
    /// - Parameter key: The field key
    /// - Returns: The date value, or nil if field doesn't exist or isn't a date
    func getDate(_ key: String) -> Date? {
        fields[key]?.dateValue
    }

    /// Get attachment IDs for a field
    ///
    /// - Parameter key: The field key
    /// - Returns: The attachment IDs, or nil if field doesn't exist or isn't attachmentIds
    func getAttachmentIds(_ key: String) -> [UUID]? {
        fields[key]?.attachmentIdsValue
    }

    /// Get a string array for a field
    ///
    /// - Parameter key: The field key
    /// - Returns: The string array, or nil if field doesn't exist or isn't a stringArray
    func getStringArray(_ key: String) -> [String]? {
        fields[key]?.stringArrayValue
    }

    // MARK: - Convenience Setters

    /// Set a string value
    mutating func setString(_ key: String, _ value: String) {
        fields[key] = .string(value)
    }

    /// Set an int value
    mutating func setInt(_ key: String, _ value: Int) {
        fields[key] = .int(value)
    }

    /// Set a double value
    mutating func setDouble(_ key: String, _ value: Double) {
        fields[key] = .double(value)
    }

    /// Set a bool value
    mutating func setBool(_ key: String, _ value: Bool) {
        fields[key] = .bool(value)
    }

    /// Set a date value
    mutating func setDate(_ key: String, _ value: Date) {
        fields[key] = .date(value)
    }

    /// Set attachment IDs
    mutating func setAttachmentIds(_ key: String, _ value: [UUID]) {
        fields[key] = .attachmentIds(value)
    }

    /// Set a string array
    mutating func setStringArray(_ key: String, _ value: [String]) {
        fields[key] = .stringArray(value)
    }
}

// MARK: - Validation

extension RecordContent {
    /// Validate this record content against a schema
    ///
    /// This is a forward declaration - the actual implementation will be in RecordSchema
    /// to avoid circular dependencies. RecordSchema will provide this validation.
    ///
    /// - Parameter schema: The schema to validate against
    /// - Throws: ModelError if validation fails
    func validate(against schema: RecordSchema) throws {
        // Implemented in RecordSchema to avoid circular dependency
        try schema.validate(content: self)
    }
}

// MARK: - Codable

extension RecordContent {
    enum CodingKeys: String, CodingKey {
        case fields
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fields = try container.decode([String: FieldValue].self, forKey: .fields)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(fields, forKey: .fields)
    }
}
