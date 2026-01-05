import Foundation

/// Container for medical record field values
///
/// Wraps a dictionary of field values and provides validation against schemas.
/// This is the "document" in the schema-overlay architecture - it can hold any fields.
///
/// **Field Keys**: Field IDs are UUIDs, stored as UUID strings in the dictionary.
/// This enables collision-free multi-device field identification per ADR-0009.
///
/// **Encryption**: This entire struct is encrypted with the Family Member Key (FMK).
/// The schemaId is kept inside the encrypted blob to maintain zero-knowledge privacy.
struct RecordContent: Codable, Equatable, Sendable {
    // MARK: - Properties

    /// Optional schema identifier (encrypted with content)
    ///
    /// Examples: "vaccine", "medication", "my-custom-schema", or nil for freeform records
    var schemaId: String?

    /// The actual field values stored as a dictionary
    ///
    /// Keys are UUID strings (field.id.uuidString) for JSON serialization compatibility.
    private var fields: [String: FieldValue]

    // MARK: - Initialization

    /// Initialize with an empty field dictionary
    init(schemaId: String? = nil) {
        self.schemaId = schemaId
        fields = [:]
    }

    /// Initialize with a pre-populated field dictionary (string keys)
    ///
    /// - Parameters:
    ///   - schemaId: Optional schema identifier
    ///   - fields: Initial field values (keys should be UUID strings)
    init(schemaId: String? = nil, fields: [String: FieldValue]) {
        self.schemaId = schemaId
        self.fields = fields
    }

    // MARK: - Field Access (UUID-based)

    /// Access field values by UUID
    subscript(key: UUID) -> FieldValue? {
        get {
            fields[key.uuidString]
        }
        set {
            fields[key.uuidString] = newValue
        }
    }

    /// Access field values by string key (for backward compatibility)
    subscript(key: String) -> FieldValue? {
        get {
            fields[key]
        }
        set {
            fields[key] = newValue
        }
    }

    /// Get all fields as a dictionary (keys are UUID strings)
    var allFields: [String: FieldValue] {
        fields
    }

    /// Get all field keys (UUID strings)
    var fieldKeys: [String] {
        Array(fields.keys)
    }

    /// Check if a field exists by UUID
    ///
    /// - Parameter key: The field UUID to check
    /// - Returns: true if the field exists, false otherwise
    func hasField(_ key: UUID) -> Bool {
        fields[key.uuidString] != nil
    }

    /// Check if a field exists by string key
    ///
    /// - Parameter key: The field key to check
    /// - Returns: true if the field exists, false otherwise
    func hasField(_ key: String) -> Bool {
        fields[key] != nil
    }

    /// Remove a field by UUID
    ///
    /// - Parameter key: The field UUID to remove
    mutating func removeField(_ key: UUID) {
        fields.removeValue(forKey: key.uuidString)
    }

    /// Remove a field by string key
    ///
    /// - Parameter key: The field key to remove
    mutating func removeField(_ key: String) {
        fields.removeValue(forKey: key)
    }

    /// Remove all fields
    mutating func removeAllFields() {
        fields.removeAll()
    }

    // MARK: - UUID-based Convenience Accessors

    /// Get a string value for a field by UUID
    func getString(_ key: UUID) -> String? {
        fields[key.uuidString]?.stringValue
    }

    /// Get an int value for a field by UUID
    func getInt(_ key: UUID) -> Int? {
        fields[key.uuidString]?.intValue
    }

    /// Get a double value for a field by UUID
    func getDouble(_ key: UUID) -> Double? {
        fields[key.uuidString]?.doubleValue
    }

    /// Get a bool value for a field by UUID
    func getBool(_ key: UUID) -> Bool? {
        fields[key.uuidString]?.boolValue
    }

    /// Get a date value for a field by UUID
    func getDate(_ key: UUID) -> Date? {
        fields[key.uuidString]?.dateValue
    }

    /// Get attachment IDs for a field by UUID
    func getAttachmentIds(_ key: UUID) -> [UUID]? {
        fields[key.uuidString]?.attachmentIdsValue
    }

    /// Get a string array for a field by UUID
    func getStringArray(_ key: UUID) -> [String]? {
        fields[key.uuidString]?.stringArrayValue
    }

    // MARK: - UUID-based Convenience Setters

    /// Set a string value by UUID
    mutating func setString(_ key: UUID, _ value: String) {
        fields[key.uuidString] = .string(value)
    }

    /// Set an int value by UUID
    mutating func setInt(_ key: UUID, _ value: Int) {
        fields[key.uuidString] = .int(value)
    }

    /// Set a double value by UUID
    mutating func setDouble(_ key: UUID, _ value: Double) {
        fields[key.uuidString] = .double(value)
    }

    /// Set a bool value by UUID
    mutating func setBool(_ key: UUID, _ value: Bool) {
        fields[key.uuidString] = .bool(value)
    }

    /// Set a date value by UUID
    mutating func setDate(_ key: UUID, _ value: Date) {
        fields[key.uuidString] = .date(value)
    }

    /// Set attachment IDs by UUID
    mutating func setAttachmentIds(_ key: UUID, _ value: [UUID]) {
        fields[key.uuidString] = .attachmentIds(value)
    }

    /// Set a string array by UUID
    mutating func setStringArray(_ key: UUID, _ value: [String]) {
        fields[key.uuidString] = .stringArray(value)
    }

    // MARK: - String-based Convenience Accessors (backward compatibility)

    /// Get a string value for a field
    ///
    /// - Parameter key: The field key (UUID string)
    /// - Returns: The string value, or nil if field doesn't exist or isn't a string
    func getString(_ key: String) -> String? {
        fields[key]?.stringValue
    }

    /// Get an int value for a field
    ///
    /// - Parameter key: The field key (UUID string)
    /// - Returns: The int value, or nil if field doesn't exist or isn't an int
    func getInt(_ key: String) -> Int? {
        fields[key]?.intValue
    }

    /// Get a double value for a field
    ///
    /// - Parameter key: The field key (UUID string)
    /// - Returns: The double value, or nil if field doesn't exist or isn't a double
    func getDouble(_ key: String) -> Double? {
        fields[key]?.doubleValue
    }

    /// Get a bool value for a field
    ///
    /// - Parameter key: The field key (UUID string)
    /// - Returns: The bool value, or nil if field doesn't exist or isn't a bool
    func getBool(_ key: String) -> Bool? {
        fields[key]?.boolValue
    }

    /// Get a date value for a field
    ///
    /// - Parameter key: The field key (UUID string)
    /// - Returns: The date value, or nil if field doesn't exist or isn't a date
    func getDate(_ key: String) -> Date? {
        fields[key]?.dateValue
    }

    /// Get attachment IDs for a field
    ///
    /// - Parameter key: The field key (UUID string)
    /// - Returns: The attachment IDs, or nil if field doesn't exist or isn't attachmentIds
    func getAttachmentIds(_ key: String) -> [UUID]? {
        fields[key]?.attachmentIdsValue
    }

    /// Get a string array for a field
    ///
    /// - Parameter key: The field key (UUID string)
    /// - Returns: The string array, or nil if field doesn't exist or isn't a stringArray
    func getStringArray(_ key: String) -> [String]? {
        fields[key]?.stringArrayValue
    }

    // MARK: - String-based Convenience Setters (backward compatibility)

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
    /// Convenience wrapper that delegates to `schema.validate(content:)`.
    ///
    /// - Parameter schema: The schema to validate against
    /// - Throws: ModelError if validation fails
    func validate(against schema: RecordSchema) throws {
        try schema.validate(content: self)
    }
}

// MARK: - Codable

extension RecordContent {
    enum CodingKeys: String, CodingKey {
        case schemaId
        case fields
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaId = try container.decodeIfPresent(String.self, forKey: .schemaId)
        fields = try container.decode([String: FieldValue].self, forKey: .fields)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(schemaId, forKey: .schemaId)
        try container.encode(fields, forKey: .fields)
    }
}
