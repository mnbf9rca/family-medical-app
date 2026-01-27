import CryptoKit
import Dependencies
import Foundation
import Observation
import SwiftUI

/// ViewModel for editing a schema (adding fields, reordering, etc.)
@MainActor
@Observable
final class SchemaEditorViewModel {
    // MARK: - State

    let person: Person
    let originalSchema: RecordSchema?

    /// Editable schema properties
    var schemaId: String
    var displayName: String
    var iconSystemName: String
    var schemaDescription: String

    /// Working copy of fields (mutable)
    var fields: [FieldDefinition]

    var isLoading = false
    var errorMessage: String?
    var didSaveSuccessfully = false

    // MARK: - Dependencies

    @ObservationIgnored @Dependency(\.uuid) private var uuid
    @ObservationIgnored @Dependency(\.date) private var date

    private let customSchemaRepository: CustomSchemaRepositoryProtocol
    private let primaryKeyProvider: PrimaryKeyProviderProtocol
    private let fmkService: FamilyMemberKeyServiceProtocol
    private let logger = LoggingService.shared.logger(category: .storage)

    // MARK: - Computed Properties

    /// Whether this is a new schema (not yet saved)
    var isNewSchema: Bool {
        originalSchema == nil
    }

    /// Whether the schema is a built-in type
    var isBuiltInSchema: Bool {
        originalSchema?.isBuiltIn ?? false
    }

    /// Whether the display name can be edited (not for built-in schemas)
    var canEditName: Bool {
        !isBuiltInSchema
    }

    /// The next version number for saving
    var nextVersion: Int {
        (originalSchema?.version ?? 0) + 1
    }

    /// Active (visible) fields sorted by display order
    var activeFields: [FieldDefinition] {
        fields
            .filter { $0.visibility == .active }
            .sorted { $0.displayOrder < $1.displayOrder }
    }

    /// Hidden fields
    var hiddenFields: [FieldDefinition] {
        fields
            .filter { $0.visibility == .hidden }
            .sorted { $0.displayOrder < $1.displayOrder }
    }

    /// Whether there are unsaved changes
    var hasUnsavedChanges: Bool {
        guard let original = originalSchema else {
            // New schema always has "changes" if any data entered
            return !displayName.isEmpty || !fields.isEmpty
        }

        // Compare current state to original
        if displayName != original.displayName { return true }
        if iconSystemName != original.iconSystemName { return true }
        if schemaDescription != (original.description ?? "") { return true }
        if fields.count != original.fields.count { return true }

        // Compare fields by ID and key properties
        let originalFieldsById = Dictionary(uniqueKeysWithValues: original.fields.map { ($0.id, $0) })
        for field in fields {
            guard let originalField = originalFieldsById[field.id] else {
                return true // New field added
            }
            if field.displayName != originalField.displayName { return true }
            if field.isRequired != originalField.isRequired { return true }
            if field.displayOrder != originalField.displayOrder { return true }
            if field.visibility != originalField.visibility { return true }
            if field.placeholder != originalField.placeholder { return true }
            if field.helpText != originalField.helpText { return true }
            if field.isMultiline != originalField.isMultiline { return true }
            if field.capitalizationMode != originalField.capitalizationMode { return true }
        }

        return false
    }

    // MARK: - Initialization

    /// Initialize for editing an existing schema
    init(
        person: Person,
        schema: RecordSchema,
        customSchemaRepository: CustomSchemaRepositoryProtocol? = nil,
        primaryKeyProvider: PrimaryKeyProviderProtocol? = nil,
        fmkService: FamilyMemberKeyServiceProtocol? = nil
    ) {
        self.person = person
        self.originalSchema = schema
        self.schemaId = schema.id
        self.displayName = schema.displayName
        self.iconSystemName = schema.iconSystemName
        self.schemaDescription = schema.description ?? ""
        self.fields = schema.fields

        // Use optional parameter pattern per ADR-0008
        self.customSchemaRepository = customSchemaRepository ?? CustomSchemaRepository(
            coreDataStack: CoreDataStack.shared,
            encryptionService: EncryptionService()
        )
        self.primaryKeyProvider = primaryKeyProvider ?? PrimaryKeyProvider()
        self.fmkService = fmkService ?? FamilyMemberKeyService()
    }

    /// Initialize for creating a new schema
    init(
        person: Person,
        newSchemaTemplate: RecordSchema,
        customSchemaRepository: CustomSchemaRepositoryProtocol? = nil,
        primaryKeyProvider: PrimaryKeyProviderProtocol? = nil,
        fmkService: FamilyMemberKeyServiceProtocol? = nil
    ) {
        self.person = person
        self.originalSchema = nil
        self.schemaId = newSchemaTemplate.id
        self.displayName = newSchemaTemplate.displayName
        self.iconSystemName = newSchemaTemplate.iconSystemName
        self.schemaDescription = newSchemaTemplate.description ?? ""
        self.fields = newSchemaTemplate.fields

        self.customSchemaRepository = customSchemaRepository ?? CustomSchemaRepository(
            coreDataStack: CoreDataStack.shared,
            encryptionService: EncryptionService()
        )
        self.primaryKeyProvider = primaryKeyProvider ?? PrimaryKeyProvider()
        self.fmkService = fmkService ?? FamilyMemberKeyService()
    }

    // MARK: - Field Management

    /// Create a new field template for adding to the schema
    ///
    /// - Parameter fieldType: The type of field to create
    /// - Returns: A new FieldDefinition ready for editing
    func createNewField(type fieldType: FieldType) -> FieldDefinition {
        let maxOrder = fields.map(\.displayOrder).max() ?? 0
        let now = date.now
        return FieldDefinition(
            id: uuid(),
            displayName: "New Field",
            fieldType: fieldType,
            isRequired: false,
            displayOrder: maxOrder + 1,
            placeholder: nil,
            helpText: nil,
            validationRules: [],
            isMultiline: false,
            capitalizationMode: .sentences,
            visibility: .active,
            createdBy: .zero, // Will be set properly when device identity is implemented
            createdAt: now,
            updatedBy: .zero, // Will be set properly when device identity is implemented
            updatedAt: now
        )
    }

    /// Add a field to the schema
    func addField(_ field: FieldDefinition) {
        fields.append(field)
    }

    /// Update a field in the schema
    ///
    /// - Parameter field: The updated field (matched by ID)
    func updateField(_ field: FieldDefinition) {
        if let index = fields.firstIndex(where: { $0.id == field.id }) {
            fields[index] = field
        }
    }

    /// Hide a field (built-in fields can only be hidden, not deleted)
    ///
    /// - Parameter fieldId: The field ID to hide
    func hideField(withId fieldId: UUID) {
        if let index = fields.firstIndex(where: { $0.id == fieldId }) {
            fields[index].visibility = .hidden
        }
    }

    /// Unhide a previously hidden field
    ///
    /// - Parameter fieldId: The field ID to unhide
    func unhideField(withId fieldId: UUID) {
        if let index = fields.firstIndex(where: { $0.id == fieldId }) {
            fields[index].visibility = .active
        }
    }

    /// Delete a custom field (built-in fields cannot be deleted)
    ///
    /// - Parameter fieldId: The field ID to delete
    /// - Returns: true if deleted, false if field is built-in
    func deleteField(withId fieldId: UUID) -> Bool {
        guard let index = fields.firstIndex(where: { $0.id == fieldId }) else {
            return false
        }

        let field = fields[index]

        // Cannot delete built-in fields
        if BuiltInFieldIds.isBuiltIn(field.id) {
            errorMessage = "Built-in fields cannot be deleted. You can hide them instead."
            return false
        }

        fields.remove(at: index)
        return true
    }

    /// Reorder fields using drag and drop offsets
    ///
    /// - Parameters:
    ///   - source: The source indices being moved
    ///   - destination: The destination index
    func moveFields(from source: IndexSet, to destination: Int) {
        // Get active fields in current order
        var orderedFields = activeFields

        // Perform the move
        orderedFields.move(fromOffsets: source, toOffset: destination)

        // Update display orders
        for (index, field) in orderedFields.enumerated() {
            if let fieldIndex = fields.firstIndex(where: { $0.id == field.id }) {
                fields[fieldIndex].displayOrder = index + 1
            }
        }
    }

    // MARK: - Validation

    /// Validate the schema configuration
    ///
    /// - Returns: true if valid, false otherwise (sets errorMessage)
    func validate() -> Bool {
        if displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errorMessage = "Schema name is required."
            return false
        }

        if activeFields.isEmpty {
            errorMessage = "Schema must have at least one visible field."
            return false
        }

        errorMessage = nil
        return true
    }

    // MARK: - Save

    /// Save the schema to the repository
    func save() async {
        guard validate() else {
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let primaryKey = try primaryKeyProvider.getPrimaryKey()
            let fmk = try fmkService.retrieveFMK(
                familyMemberID: person.id.uuidString,
                primaryKey: primaryKey
            )

            // Build the schema with updated version
            let schema = RecordSchema(
                unsafeId: schemaId,
                displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
                iconSystemName: iconSystemName,
                fields: fields,
                isBuiltIn: originalSchema?.isBuiltIn ?? false,
                description: schemaDescription.isEmpty ? nil : schemaDescription,
                version: nextVersion
            )

            try await customSchemaRepository.save(schema, forPerson: person.id, familyMemberKey: fmk)
            didSaveSuccessfully = true
        } catch {
            errorMessage = "Unable to save schema. Please try again."
            logger.logError(error, context: "SchemaEditorViewModel.save")
        }

        isLoading = false
    }

    // MARK: - Preview Support

    /// Create a preview schema with current state (for form preview)
    func createPreviewSchema() -> RecordSchema {
        RecordSchema(
            unsafeId: schemaId,
            displayName: displayName,
            iconSystemName: iconSystemName,
            fields: activeFields,
            isBuiltIn: false,
            description: schemaDescription.isEmpty ? nil : schemaDescription
        )
    }
}
