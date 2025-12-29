import Foundation

/// Type of built-in medical record schema
enum BuiltInSchemaType: String, Codable, CaseIterable {
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
}

/// Schema template for medical records
///
/// Defines the structure, fields, and validation rules for a type of medical record.
/// Schemas can be built-in (predefined by the app) or custom (user-defined).
struct RecordSchema: Codable, Equatable, Identifiable {
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

    // MARK: - Initialization

    init(
        id: String,
        displayName: String,
        iconSystemName: String,
        fields: [FieldDefinition],
        isBuiltIn: Bool = false,
        description: String? = nil
    ) throws {
        // Validate schema ID
        let trimmedId = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedId.isEmpty else {
            throw ModelError.invalidSchemaId(id)
        }

        // Check for duplicate field IDs
        var seen = Set<String>()
        for fieldId in fields.map(\.id) {
            if seen.contains(fieldId) {
                throw ModelError.duplicateFieldId(fieldId: fieldId)
            }
            seen.insert(fieldId)
        }

        self.id = trimmedId
        self.displayName = displayName
        self.iconSystemName = iconSystemName
        self.fields = fields
        self.isBuiltIn = isBuiltIn
        self.description = description
    }

    /// Internal initializer for built-in schemas (skips validation)
    init(
        unsafeId id: String,
        displayName: String,
        iconSystemName: String,
        fields: [FieldDefinition],
        isBuiltIn: Bool = true,
        description: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.iconSystemName = iconSystemName
        self.fields = fields
        self.isBuiltIn = isBuiltIn
        self.description = description
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

    /// Get a field definition by ID
    ///
    /// - Parameter fieldId: The field ID to look up
    /// - Returns: The field definition, or nil if not found
    func field(withId fieldId: String) -> FieldDefinition? {
        fields.first { $0.id == fieldId }
    }

    /// Get all required field IDs
    var requiredFieldIds: [String] {
        fields.filter(\.isRequired).map(\.id)
    }

    /// Get fields sorted by display order
    var fieldsByDisplayOrder: [FieldDefinition] {
        fields.sorted { $0.displayOrder < $1.displayOrder }
    }

    // MARK: - Validation

    /// Validate record content against this schema
    ///
    /// - Parameter content: The record content to validate
    /// - Throws: ModelError if validation fails
    func validate(content: RecordContent) throws {
        // Check all required fields are present
        for fieldDef in fields where fieldDef.isRequired {
            let value = content[fieldDef.id]
            try fieldDef.validate(value)
        }

        // Validate all present fields (required and optional)
        for (key, value) in content.allFields {
            guard let fieldDef = field(withId: key) else {
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
