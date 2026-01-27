import Foundation

/// Type of built-in medical record schema
enum BuiltInSchemaType: String, Codable, CaseIterable, Sendable {
    case vaccine
    case condition
    case medication
    case allergy
    case note

    /// Display name for this schema type
    var displayName: String {
        switch self {
        case .vaccine:
            "Vaccine"
        case .condition:
            "Medical Condition"
        case .medication:
            "Medication"
        case .allergy:
            "Allergy"
        case .note:
            "Note"
        }
    }

    /// SF Symbol icon name for this schema type
    var iconSystemName: String {
        switch self {
        case .vaccine:
            "syringe"
        case .condition:
            "heart.text.square"
        case .medication:
            "pills"
        case .allergy:
            "exclamationmark.triangle"
        case .note:
            "note.text"
        }
    }

    /// Get the built-in schema definition for this type
    ///
    /// This is a convenience accessor that returns the schema from `BuiltInSchemas`.
    var schema: RecordSchema {
        BuiltInSchemas.schema(for: self)
    }
}

/// Schema template for medical records
///
/// Defines the structure, fields, and validation rules for a type of medical record.
/// Schemas can be built-in (predefined by the app) or custom (user-defined).
///
/// Per ADR-0009 (Schema Evolution in Multi-Master Replication):
/// - Field IDs are UUIDs for collision-free multi-device support
/// - Each Person has their own copy of schemas
/// - Schemas are encrypted with Person's FMK
struct RecordSchema: Codable, Equatable, Hashable, Identifiable, Sendable {
    // MARK: - Properties

    /// Unique identifier for this schema (e.g., "vaccine", "medication", "my-custom-type")
    let id: String

    /// Human-readable display name (e.g., "Vaccine Record")
    let displayName: String

    /// SF Symbol icon name for UI display
    let iconSystemName: String

    /// Field definitions for this schema
    let fields: [FieldDefinition]

    /// Whether this is a built-in schema (predefined by app)
    let isBuiltIn: Bool

    /// Optional description of what this schema is for
    var description: String?

    /// Schema version number (incremented on each change)
    ///
    /// Used for tracking schema evolution. When a schema is updated:
    /// - Version must be incremented
    /// - Certain changes (field type, field id, making optional fields required) are prohibited
    /// - Safe changes (displayName, new fields, relaxing required) are allowed
    var version: Int

    // MARK: - Initialization

    init(
        id: String,
        displayName: String,
        iconSystemName: String,
        fields: [FieldDefinition],
        isBuiltIn: Bool = false,
        description: String? = nil,
        version: Int = 1
    ) throws {
        // Validate schema ID
        let trimmedId = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedId.isEmpty else {
            throw ModelError.invalidSchemaId(id)
        }

        // Check for duplicate field IDs (UUID-based)
        var seen = Set<UUID>()
        for field in fields {
            if seen.contains(field.id) {
                throw ModelError.duplicateFieldId(fieldId: field.id.uuidString)
            }
            seen.insert(field.id)
        }

        self.id = trimmedId
        self.displayName = displayName
        self.iconSystemName = iconSystemName
        self.fields = fields
        self.isBuiltIn = isBuiltIn
        self.description = description
        self.version = version
    }

    /// Internal initializer for built-in schemas (skips validation)
    init(
        unsafeId id: String,
        displayName: String,
        iconSystemName: String,
        fields: [FieldDefinition],
        isBuiltIn: Bool = true,
        description: String? = nil,
        version: Int = 1
    ) {
        self.id = id
        self.displayName = displayName
        self.iconSystemName = iconSystemName
        self.fields = fields
        self.isBuiltIn = isBuiltIn
        self.description = description
        self.version = version
    }

    // MARK: - Built-in Schema Factory

    /// Get a built-in schema by type
    ///
    /// - Parameter type: The built-in schema type
    /// - Returns: The corresponding schema
    static func builtIn(_ type: BuiltInSchemaType) -> RecordSchema {
        // Implementation provided by BuiltInSchemas.swift
        // This is a forward declaration to avoid circular dependency
        BuiltInSchemas.schema(for: type)
    }

    // MARK: - Field Access

    /// Get a field definition by UUID
    ///
    /// - Parameter fieldId: The field UUID to look up
    /// - Returns: The field definition, or nil if not found
    func field(withId fieldId: UUID) -> FieldDefinition? {
        fields.first { $0.id == fieldId }
    }

    /// Get a field definition by UUID string
    ///
    /// - Parameter fieldIdString: The field UUID string to look up
    /// - Returns: The field definition, or nil if not found or invalid UUID
    func field(withIdString fieldIdString: String) -> FieldDefinition? {
        guard let uuid = UUID(uuidString: fieldIdString) else {
            return nil
        }
        return field(withId: uuid)
    }

    /// Get all required field IDs
    var requiredFieldIds: [UUID] {
        fields.filter(\.isRequired).map(\.id)
    }

    /// Get all active (visible) fields sorted by display order
    var activeFieldsByDisplayOrder: [FieldDefinition] {
        fields
            .filter { $0.visibility == .active }
            .sorted { $0.displayOrder < $1.displayOrder }
    }

    /// Get fields sorted by display order (includes all visibilities)
    var fieldsByDisplayOrder: [FieldDefinition] {
        fields.sorted { $0.displayOrder < $1.displayOrder }
    }

    // MARK: - Validation

    /// Validate record content against this schema
    ///
    /// - Parameter content: The record content to validate
    /// - Throws: ModelError if validation fails
    func validate(content: RecordContent) throws {
        // Check all required fields are present (only active fields)
        for fieldDef in fields where fieldDef.isRequired && fieldDef.visibility == .active {
            let value = content[fieldDef.id]
            try fieldDef.validate(value)
        }

        // Validate all present fields (required and optional)
        for (key, value) in content.allFields {
            guard let fieldDef = field(withIdString: key) else {
                // Field not in schema - this is allowed (schema is a template, not a constraint)
                // Users can add extra fields beyond the schema
                continue
            }
            try fieldDef.validate(value)
        }
    }

    /// Check if content is valid according to this schema
    ///
    /// - Parameter content: The record content to check
    /// - Returns: true if valid, false otherwise
    func isValid(content: RecordContent) -> Bool {
        do {
            try validate(content: content)
            return true
        } catch {
            return false
        }
    }
}
