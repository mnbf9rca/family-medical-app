import Dependencies
import Foundation
import Observation

/// ViewModel for editing a single field's properties
///
/// Manages editable properties of a FieldDefinition. Per ADR-0009:
/// - Field ID and type are immutable after creation
/// - Display properties (name, placeholder, helpText) are mutable
/// - UI hints (isMultiline, capitalizationMode) are mutable for string fields
/// - Validation rules are mutable
@MainActor
@Observable
final class FieldEditorViewModel {
    // MARK: - State

    /// The field being edited (nil for new field)
    let originalField: FieldDefinition?

    /// Whether this is a new field (not yet saved)
    let isNewField: Bool

    /// The field type (immutable after creation)
    let fieldType: FieldType

    /// Editable properties
    var displayName: String
    var isRequired: Bool
    var placeholder: String
    var helpText: String

    /// UI Hints (only applicable for string fields)
    var isMultiline: Bool
    var capitalizationMode: TextCapitalizationMode

    /// Validation rules
    var validationRules: [ValidationRule]

    var errorMessage: String?

    // MARK: - Dependencies

    @ObservationIgnored @Dependency(\.uuid) private var uuid
    @ObservationIgnored @Dependency(\.date) private var date

    // MARK: - Computed Properties

    /// Whether multiline option is available (only for string fields)
    var canSetMultiline: Bool {
        fieldType == .string
    }

    /// Whether capitalization option is available (only for string fields)
    var canSetCapitalization: Bool {
        fieldType == .string
    }

    /// Whether length validation rules are available (only for string fields)
    var canAddLengthValidation: Bool {
        fieldType == .string
    }

    /// Whether numeric validation rules are available (only for int/double fields)
    var canAddNumericValidation: Bool {
        fieldType == .int || fieldType == .double
    }

    /// Whether date validation rules are available (only for date fields)
    var canAddDateValidation: Bool {
        fieldType == .date
    }

    /// Whether there are unsaved changes
    var hasUnsavedChanges: Bool {
        guard let original = originalField else {
            // New field always has changes if name is not empty
            return !displayName.isEmpty
        }

        if displayName != original.displayName { return true }
        if isRequired != original.isRequired { return true }
        if placeholder != (original.placeholder ?? "") { return true }
        if helpText != (original.helpText ?? "") { return true }
        if isMultiline != original.isMultiline { return true }
        if capitalizationMode != original.capitalizationMode { return true }
        if validationRules != original.validationRules { return true }

        return false
    }

    // MARK: - Initialization

    /// Initialize for editing an existing field
    init(field: FieldDefinition) {
        self.originalField = field
        self.isNewField = false
        self.fieldType = field.fieldType
        self.displayName = field.displayName
        self.isRequired = field.isRequired
        self.placeholder = field.placeholder ?? ""
        self.helpText = field.helpText ?? ""
        self.isMultiline = field.isMultiline
        self.capitalizationMode = field.capitalizationMode
        self.validationRules = field.validationRules
    }

    /// Initialize for creating a new field
    init(fieldType: FieldType) {
        self.originalField = nil
        self.isNewField = true
        self.fieldType = fieldType
        self.displayName = ""
        self.isRequired = false
        self.placeholder = ""
        self.helpText = ""
        self.isMultiline = false
        self.capitalizationMode = .sentences
        self.validationRules = []
    }

    // MARK: - Validation

    /// Validate the field configuration
    ///
    /// - Returns: true if valid, false otherwise (sets errorMessage)
    func validate() -> Bool {
        if displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errorMessage = "Field name is required."
            return false
        }

        errorMessage = nil
        return true
    }

    // MARK: - Validation Rules Management

    /// Add a minimum length validation rule (string fields only)
    func addMinLengthRule(_ minLength: Int) {
        guard canAddLengthValidation else { return }
        // Remove existing minLength rule if any
        validationRules.removeAll { if case .minLength = $0 { return true }; return false }
        validationRules.append(.minLength(minLength))
    }

    /// Add a maximum length validation rule (string fields only)
    func addMaxLengthRule(_ maxLength: Int) {
        guard canAddLengthValidation else { return }
        // Remove existing maxLength rule if any
        validationRules.removeAll { if case .maxLength = $0 { return true }; return false }
        validationRules.append(.maxLength(maxLength))
    }

    /// Add a minimum value validation rule (numeric fields only)
    func addMinValueRule(_ minValue: Double) {
        guard canAddNumericValidation else { return }
        // Remove existing minValue rule if any
        validationRules.removeAll { if case .minValue = $0 { return true }; return false }
        validationRules.append(.minValue(minValue))
    }

    /// Add a maximum value validation rule (numeric fields only)
    func addMaxValueRule(_ maxValue: Double) {
        guard canAddNumericValidation else { return }
        // Remove existing maxValue rule if any
        validationRules.removeAll { if case .maxValue = $0 { return true }; return false }
        validationRules.append(.maxValue(maxValue))
    }

    /// Add a minimum date validation rule (date fields only)
    func addMinDateRule(_ minDate: Date) {
        guard canAddDateValidation else { return }
        // Remove existing minDate rule if any
        validationRules.removeAll { if case .minDate = $0 { return true }; return false }
        validationRules.append(.minDate(minDate))
    }

    /// Add a maximum date validation rule (date fields only)
    func addMaxDateRule(_ maxDate: Date) {
        guard canAddDateValidation else { return }
        // Remove existing maxDate rule if any
        validationRules.removeAll { if case .maxDate = $0 { return true }; return false }
        validationRules.append(.maxDate(maxDate))
    }

    /// Add a regex pattern validation rule (string fields only)
    func addPatternRule(_ pattern: String) {
        guard canAddLengthValidation else { return }
        // Remove existing pattern rule if any
        validationRules.removeAll { if case .pattern = $0 { return true }; return false }
        validationRules.append(.pattern(pattern))
    }

    /// Remove a validation rule by type
    func removeValidationRule(_ rule: ValidationRule) {
        validationRules.removeAll { $0 == rule }
    }

    /// Clear all validation rules
    func clearValidationRules() {
        validationRules.removeAll()
    }

    // MARK: - Build Field

    /// Build a FieldDefinition from the current state
    ///
    /// - Parameters:
    ///   - deviceId: The device ID creating/updating this field
    ///   - displayOrder: The display order for this field
    /// - Returns: A FieldDefinition with current state, or nil if validation fails
    func buildField(deviceId: UUID, displayOrder: Int) -> FieldDefinition? {
        guard validate() else { return nil }

        let now = date.now

        if let original = originalField {
            // Updating existing field - preserve immutable properties
            return FieldDefinition(
                id: original.id,
                displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
                fieldType: original.fieldType,
                isRequired: isRequired,
                displayOrder: displayOrder,
                placeholder: placeholder.isEmpty ? nil : placeholder,
                helpText: helpText.isEmpty ? nil : helpText,
                validationRules: validationRules,
                isMultiline: isMultiline,
                capitalizationMode: capitalizationMode,
                visibility: original.visibility,
                createdBy: original.createdBy,
                createdAt: original.createdAt,
                updatedBy: deviceId,
                updatedAt: now
            )
        } else {
            // Creating new field
            return FieldDefinition(
                id: uuid(),
                displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
                fieldType: fieldType,
                isRequired: isRequired,
                displayOrder: displayOrder,
                placeholder: placeholder.isEmpty ? nil : placeholder,
                helpText: helpText.isEmpty ? nil : helpText,
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
    }
}
