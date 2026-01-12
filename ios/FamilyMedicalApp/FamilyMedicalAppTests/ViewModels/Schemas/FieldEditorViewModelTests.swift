import Dependencies
import Foundation
import Testing
@testable import FamilyMedicalApp

@MainActor
struct FieldEditorViewModelTests {
    // MARK: - Test Data

    let testDeviceId = UUID()

    func createTestField(
        id: UUID = UUID(),
        displayName: String = "Test Field",
        fieldType: FieldType = .string,
        isRequired: Bool = false,
        displayOrder: Int = 1,
        placeholder: String? = nil,
        helpText: String? = nil,
        validationRules: [ValidationRule] = [],
        isMultiline: Bool = false,
        capitalizationMode: TextCapitalizationMode = .sentences,
        visibility: FieldVisibility = .active
    ) -> FieldDefinition {
        let now = Date()
        return FieldDefinition(
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
            visibility: visibility,
            createdBy: .zero,
            createdAt: now,
            updatedBy: .zero,
            updatedAt: now
        )
    }

    // MARK: - Initialization Tests

    @Test
    func initWithExistingFieldPopulatesState() {
        let field = createTestField(
            displayName: "My Field",
            isRequired: true,
            placeholder: "Enter value",
            helpText: "Help text here",
            isMultiline: true,
            capitalizationMode: .words
        )

        let viewModel = FieldEditorViewModel(field: field)

        #expect(viewModel.displayName == "My Field")
        #expect(viewModel.isRequired == true)
        #expect(viewModel.placeholder == "Enter value")
        #expect(viewModel.helpText == "Help text here")
        #expect(viewModel.isMultiline == true)
        #expect(viewModel.capitalizationMode == .words)
        #expect(viewModel.isNewField == false)
        #expect(viewModel.originalField != nil)
    }

    @Test
    func initForNewFieldCreatesEmptyState() {
        let viewModel = FieldEditorViewModel(fieldType: .string)

        #expect(viewModel.displayName.isEmpty)
        #expect(viewModel.isRequired == false)
        #expect(viewModel.placeholder.isEmpty)
        #expect(viewModel.helpText.isEmpty)
        #expect(viewModel.isMultiline == false)
        #expect(viewModel.capitalizationMode == .sentences)
        #expect(viewModel.isNewField == true)
        #expect(viewModel.originalField == nil)
        #expect(viewModel.fieldType == .string)
    }

    @Test
    func initPreservesFieldType() {
        let intField = createTestField(fieldType: .int)
        let viewModel = FieldEditorViewModel(field: intField)

        #expect(viewModel.fieldType == .int)
    }

    // MARK: - Computed Properties Tests

    @Test
    func canSetMultilineOnlyForStringFields() {
        let stringVM = FieldEditorViewModel(fieldType: .string)
        let intVM = FieldEditorViewModel(fieldType: .int)
        let dateVM = FieldEditorViewModel(fieldType: .date)
        let boolVM = FieldEditorViewModel(fieldType: .bool)

        #expect(stringVM.canSetMultiline == true)
        #expect(intVM.canSetMultiline == false)
        #expect(dateVM.canSetMultiline == false)
        #expect(boolVM.canSetMultiline == false)
    }

    @Test
    func canSetCapitalizationOnlyForStringFields() {
        let stringVM = FieldEditorViewModel(fieldType: .string)
        let intVM = FieldEditorViewModel(fieldType: .int)

        #expect(stringVM.canSetCapitalization == true)
        #expect(intVM.canSetCapitalization == false)
    }

    @Test
    func canAddLengthValidationOnlyForStringFields() {
        let stringVM = FieldEditorViewModel(fieldType: .string)
        let intVM = FieldEditorViewModel(fieldType: .int)

        #expect(stringVM.canAddLengthValidation == true)
        #expect(intVM.canAddLengthValidation == false)
    }

    @Test
    func canAddNumericValidationOnlyForNumericFields() {
        let intVM = FieldEditorViewModel(fieldType: .int)
        let doubleVM = FieldEditorViewModel(fieldType: .double)
        let stringVM = FieldEditorViewModel(fieldType: .string)

        #expect(intVM.canAddNumericValidation == true)
        #expect(doubleVM.canAddNumericValidation == true)
        #expect(stringVM.canAddNumericValidation == false)
    }

    @Test
    func canAddDateValidationOnlyForDateFields() {
        let dateVM = FieldEditorViewModel(fieldType: .date)
        let stringVM = FieldEditorViewModel(fieldType: .string)

        #expect(dateVM.canAddDateValidation == true)
        #expect(stringVM.canAddDateValidation == false)
    }

    // MARK: - Has Unsaved Changes Tests

    @Test
    func hasUnsavedChangesDetectsNameChange() {
        let field = createTestField(displayName: "Original")
        let viewModel = FieldEditorViewModel(field: field)

        #expect(viewModel.hasUnsavedChanges == false)

        viewModel.displayName = "Modified"

        #expect(viewModel.hasUnsavedChanges == true)
    }

    @Test
    func hasUnsavedChangesDetectsRequiredChange() {
        let field = createTestField(isRequired: false)
        let viewModel = FieldEditorViewModel(field: field)

        #expect(viewModel.hasUnsavedChanges == false)

        viewModel.isRequired = true

        #expect(viewModel.hasUnsavedChanges == true)
    }

    @Test
    func hasUnsavedChangesDetectsValidationRulesChange() {
        let field = createTestField(validationRules: [])
        let viewModel = FieldEditorViewModel(field: field)

        #expect(viewModel.hasUnsavedChanges == false)

        viewModel.addMinLengthRule(5)

        #expect(viewModel.hasUnsavedChanges == true)
    }

    @Test
    func hasUnsavedChangesForNewFieldWithName() {
        let viewModel = FieldEditorViewModel(fieldType: .string)

        #expect(viewModel.hasUnsavedChanges == false) // Empty name

        viewModel.displayName = "New Field"

        #expect(viewModel.hasUnsavedChanges == true)
    }

    // MARK: - Validation Tests

    @Test
    func validateFailsWithEmptyName() {
        let viewModel = FieldEditorViewModel(fieldType: .string)
        viewModel.displayName = "   " // Whitespace only

        let valid = viewModel.validate()

        #expect(valid == false)
        #expect(viewModel.errorMessage?.contains("name") == true)
    }

    @Test
    func validateSucceedsWithValidName() {
        let viewModel = FieldEditorViewModel(fieldType: .string)
        viewModel.displayName = "Valid Name"

        let valid = viewModel.validate()

        #expect(valid == true)
        #expect(viewModel.errorMessage == nil)
    }
}

// MARK: - Validation Rules Tests

extension FieldEditorViewModelTests {
    @Test
    func addMinLengthRuleAddsRule() {
        let viewModel = FieldEditorViewModel(fieldType: .string)

        viewModel.addMinLengthRule(5)

        #expect(viewModel.validationRules.count == 1)
        if case let .minLength(value) = viewModel.validationRules[0] {
            #expect(value == 5)
        } else {
            Issue.record("Expected minLength rule")
        }
    }

    @Test
    func addMinLengthRuleReplacesExisting() {
        let viewModel = FieldEditorViewModel(fieldType: .string)
        viewModel.addMinLengthRule(5)
        viewModel.addMinLengthRule(10)

        #expect(viewModel.validationRules.count == 1)
        if case let .minLength(value) = viewModel.validationRules[0] {
            #expect(value == 10)
        } else {
            Issue.record("Expected minLength rule")
        }
    }

    @Test
    func addMinLengthRuleIgnoredForNonStringFields() {
        let viewModel = FieldEditorViewModel(fieldType: .int)

        viewModel.addMinLengthRule(5)

        #expect(viewModel.validationRules.isEmpty)
    }

    @Test
    func addMaxLengthRuleAddsRule() {
        let viewModel = FieldEditorViewModel(fieldType: .string)

        viewModel.addMaxLengthRule(100)

        #expect(viewModel.validationRules.count == 1)
        if case let .maxLength(value) = viewModel.validationRules[0] {
            #expect(value == 100)
        } else {
            Issue.record("Expected maxLength rule")
        }
    }

    @Test
    func addMinValueRuleAddsRule() {
        let viewModel = FieldEditorViewModel(fieldType: .int)

        viewModel.addMinValueRule(0)

        #expect(viewModel.validationRules.count == 1)
        if case let .minValue(value) = viewModel.validationRules[0] {
            #expect(value == 0)
        } else {
            Issue.record("Expected minValue rule")
        }
    }

    @Test
    func addMaxValueRuleAddsRule() {
        let viewModel = FieldEditorViewModel(fieldType: .double)

        viewModel.addMaxValueRule(100.5)

        #expect(viewModel.validationRules.count == 1)
        if case let .maxValue(value) = viewModel.validationRules[0] {
            #expect(value == 100.5)
        } else {
            Issue.record("Expected maxValue rule")
        }
    }

    @Test
    func addMinValueRuleIgnoredForNonNumericFields() {
        let viewModel = FieldEditorViewModel(fieldType: .string)

        viewModel.addMinValueRule(0)

        #expect(viewModel.validationRules.isEmpty)
    }

    @Test
    func addMinDateRuleAddsRule() {
        let viewModel = FieldEditorViewModel(fieldType: .date)
        let minDate = Date()

        viewModel.addMinDateRule(minDate)

        #expect(viewModel.validationRules.count == 1)
        if case let .minDate(value) = viewModel.validationRules[0] {
            #expect(value == minDate)
        } else {
            Issue.record("Expected minDate rule")
        }
    }

    @Test
    func addMaxDateRuleAddsRule() {
        let viewModel = FieldEditorViewModel(fieldType: .date)
        let maxDate = Date()

        viewModel.addMaxDateRule(maxDate)

        #expect(viewModel.validationRules.count == 1)
        if case let .maxDate(value) = viewModel.validationRules[0] {
            #expect(value == maxDate)
        } else {
            Issue.record("Expected maxDate rule")
        }
    }

    @Test
    func addPatternRuleAddsRule() {
        let viewModel = FieldEditorViewModel(fieldType: .string)

        viewModel.addPatternRule("^[A-Z]+$")

        #expect(viewModel.validationRules.count == 1)
        if case let .pattern(value) = viewModel.validationRules[0] {
            #expect(value == "^[A-Z]+$")
        } else {
            Issue.record("Expected pattern rule")
        }
    }

    @Test
    func removeValidationRuleRemovesSpecificRule() {
        let viewModel = FieldEditorViewModel(fieldType: .string)
        viewModel.addMinLengthRule(5)
        viewModel.addMaxLengthRule(100)

        viewModel.removeValidationRule(.minLength(5))

        #expect(viewModel.validationRules.count == 1)
        if case .maxLength = viewModel.validationRules[0] {
            // Expected
        } else {
            Issue.record("Expected maxLength rule to remain")
        }
    }

    @Test
    func clearValidationRulesRemovesAll() {
        let viewModel = FieldEditorViewModel(fieldType: .string)
        viewModel.addMinLengthRule(5)
        viewModel.addMaxLengthRule(100)
        viewModel.addPatternRule(".*")

        viewModel.clearValidationRules()

        #expect(viewModel.validationRules.isEmpty)
    }
}

// MARK: - Build Field Tests

extension FieldEditorViewModelTests {
    @Test
    func buildFieldCreatesNewFieldWithDependencies() throws {
        let fixedUUID = try #require(UUID(uuidString: "12345678-0000-0000-0000-000000000000"))
        let fixedDate = Date(timeIntervalSinceReferenceDate: 1_000_000)

        let viewModel = withDependencies {
            $0.uuid = .constant(fixedUUID)
            $0.date = .constant(fixedDate)
        } operation: {
            FieldEditorViewModel(fieldType: .string)
        }

        viewModel.displayName = "New Field"
        viewModel.isRequired = true
        viewModel.placeholder = "Enter text"
        viewModel.helpText = "Help here"
        viewModel.isMultiline = true
        viewModel.capitalizationMode = .words

        let field = viewModel.buildField(deviceId: testDeviceId, displayOrder: 5)

        #expect(field != nil)
        #expect(field?.id == fixedUUID)
        #expect(field?.displayName == "New Field")
        #expect(field?.fieldType == .string)
        #expect(field?.isRequired == true)
        #expect(field?.displayOrder == 5)
        #expect(field?.placeholder == "Enter text")
        #expect(field?.helpText == "Help here")
        #expect(field?.isMultiline == true)
        #expect(field?.capitalizationMode == .words)
        #expect(field?.visibility == .active)
        #expect(field?.createdBy == testDeviceId)
        #expect(field?.createdAt == fixedDate)
    }

    @Test
    func buildFieldUpdatesExistingFieldPreservingImmutables() {
        let originalId = UUID()
        let originalCreatedAt = Date(timeIntervalSinceReferenceDate: 500_000)
        let originalField = FieldDefinition(
            id: originalId,
            displayName: "Original",
            fieldType: .int,
            isRequired: false,
            displayOrder: 1,
            placeholder: nil,
            helpText: nil,
            validationRules: [],
            isMultiline: false,
            capitalizationMode: .sentences,
            visibility: .hidden,
            createdBy: .zero,
            createdAt: originalCreatedAt,
            updatedBy: .zero,
            updatedAt: originalCreatedAt
        )

        let fixedDate = Date(timeIntervalSinceReferenceDate: 1_000_000)

        let viewModel = withDependencies {
            $0.date = .constant(fixedDate)
        } operation: {
            FieldEditorViewModel(field: originalField)
        }

        viewModel.displayName = "Updated Name"
        viewModel.isRequired = true
        viewModel.addMinValueRule(0)

        let field = viewModel.buildField(deviceId: testDeviceId, displayOrder: 10)

        #expect(field != nil)
        // Immutable properties preserved
        #expect(field?.id == originalId)
        #expect(field?.fieldType == .int)
        #expect(field?.createdBy == .zero)
        #expect(field?.createdAt == originalCreatedAt)
        #expect(field?.visibility == .hidden)

        // Mutable properties updated
        #expect(field?.displayName == "Updated Name")
        #expect(field?.isRequired == true)
        #expect(field?.displayOrder == 10)
        #expect(field?.updatedBy == testDeviceId)
        #expect(field?.updatedAt == fixedDate)
        #expect(field?.validationRules.count == 1)
    }

    @Test
    func buildFieldReturnsNilWhenValidationFails() {
        let viewModel = FieldEditorViewModel(fieldType: .string)
        viewModel.displayName = "" // Empty name

        let field = viewModel.buildField(deviceId: testDeviceId, displayOrder: 1)

        #expect(field == nil)
        #expect(viewModel.errorMessage != nil)
    }

    @Test
    func buildFieldTrimsDisplayName() {
        let viewModel = withDependencies {
            $0.uuid = .incrementing
            $0.date = .constant(Date())
        } operation: {
            FieldEditorViewModel(fieldType: .string)
        }

        viewModel.displayName = "  Trimmed Name  "

        let field = viewModel.buildField(deviceId: testDeviceId, displayOrder: 1)

        #expect(field?.displayName == "Trimmed Name")
    }

    @Test
    func buildFieldConvertsEmptyStringsToNil() {
        let viewModel = withDependencies {
            $0.uuid = .incrementing
            $0.date = .constant(Date())
        } operation: {
            FieldEditorViewModel(fieldType: .string)
        }

        viewModel.displayName = "Field Name"
        viewModel.placeholder = ""
        viewModel.helpText = ""

        let field = viewModel.buildField(deviceId: testDeviceId, displayOrder: 1)

        #expect(field?.placeholder == nil)
        #expect(field?.helpText == nil)
    }
}
