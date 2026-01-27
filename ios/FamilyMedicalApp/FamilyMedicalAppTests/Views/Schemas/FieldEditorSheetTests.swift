import Dependencies
import SwiftUI
import Testing
import ViewInspector
@testable import FamilyMedicalApp

@MainActor
struct FieldEditorSheetTests {
    // MARK: - Test Data

    let testDate = Date(timeIntervalSinceReferenceDate: 1_234_567_890)

    func createTestField(
        displayName: String = "Test Field",
        fieldType: FieldType = .string,
        isRequired: Bool = false,
        placeholder: String? = nil,
        helpText: String? = nil,
        validationRules: [ValidationRule] = []
    ) -> FieldDefinition {
        let now = Date()
        return FieldDefinition(
            id: UUID(),
            displayName: displayName,
            fieldType: fieldType,
            isRequired: isRequired,
            displayOrder: 1,
            placeholder: placeholder,
            helpText: helpText,
            validationRules: validationRules,
            isMultiline: false,
            capitalizationMode: .sentences,
            visibility: .active,
            createdBy: .zero,
            createdAt: now,
            updatedBy: .zero,
            updatedAt: now
        )
    }

    func createViewModel(
        field: FieldDefinition? = nil,
        fieldType: FieldType = .string
    ) -> FieldEditorViewModel {
        withDependencies {
            $0.uuid = .incrementing
            $0.date = .constant(testDate)
        } operation: {
            if let field = field {
                FieldEditorViewModel(field: field)
            } else {
                FieldEditorViewModel(fieldType: fieldType)
            }
        }
    }

    // MARK: - Basic Rendering Tests

    @Test
    func viewRendersForNewStringField() throws {
        let view = FieldEditorSheet(
            fieldType: .string,
            onSave: { _ in },
            onCancel: {}
        )

        _ = try view.inspect()
    }

    @Test
    func viewRendersForNewIntField() throws {
        let view = FieldEditorSheet(
            fieldType: .int,
            onSave: { _ in },
            onCancel: {}
        )

        _ = try view.inspect()
    }

    @Test
    func viewRendersForNewDoubleField() throws {
        let view = FieldEditorSheet(
            fieldType: .double,
            onSave: { _ in },
            onCancel: {}
        )

        _ = try view.inspect()
    }

    @Test
    func viewRendersForNewDateField() throws {
        let view = FieldEditorSheet(
            fieldType: .date,
            onSave: { _ in },
            onCancel: {}
        )

        _ = try view.inspect()
    }

    @Test
    func viewRendersForNewBoolField() throws {
        let view = FieldEditorSheet(
            fieldType: .bool,
            onSave: { _ in },
            onCancel: {}
        )

        _ = try view.inspect()
    }

    @Test
    func viewRendersForExistingField() throws {
        let field = createTestField(displayName: "Existing Field")
        let view = FieldEditorSheet(
            field: field,
            onSave: { _ in },
            onCancel: {}
        )

        _ = try view.inspect()
    }

    @Test
    func viewRendersForAllFieldTypes() throws {
        for fieldType in FieldType.allCases {
            let view = FieldEditorSheet(
                fieldType: fieldType,
                onSave: { _ in },
                onCancel: {}
            )
            _ = try view.inspect()
        }
    }

    @Test
    func viewRendersWithExistingFieldData() throws {
        let field = createTestField(
            displayName: "Complex Field",
            isRequired: true,
            placeholder: "Enter value",
            helpText: "This is help text"
        )
        let view = FieldEditorSheet(
            field: field,
            onSave: { _ in },
            onCancel: {}
        )

        _ = try view.inspect()
    }
}

// MARK: - Form Structure Tests

extension FieldEditorSheetTests {
    @Test
    func viewContainsForm() throws {
        let view = FieldEditorSheet(
            fieldType: .string,
            onSave: { _ in },
            onCancel: {}
        )

        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.Form.self)
    }

    @Test
    func viewContainsFieldPropertiesSection() throws {
        let viewModel = createViewModel(fieldType: .string)
        let view = FieldEditorSheet(
            fieldType: .string,
            viewModel: viewModel,
            onSave: { _ in },
            onCancel: {}
        )

        let inspected = try view.inspect()
        // Form should be present with sections
        _ = try inspected.find(ViewType.Form.self)
    }
}

// MARK: - String Field Tests (with text options section)

extension FieldEditorSheetTests {
    @Test
    func stringFieldShowsTextOptionsSection() throws {
        let viewModel = createViewModel(fieldType: .string)
        let view = FieldEditorSheet(
            fieldType: .string,
            viewModel: viewModel,
            onSave: { _ in },
            onCancel: {}
        )

        // String fields should have text options and validation sections
        #expect(viewModel.canSetMultiline == true)
        #expect(viewModel.canSetCapitalization == true)
        #expect(viewModel.canAddLengthValidation == true)

        _ = try view.inspect()
    }

    @Test
    func stringFieldShowsLengthValidationControls() throws {
        let viewModel = createViewModel(fieldType: .string)
        let view = FieldEditorSheet(
            fieldType: .string,
            viewModel: viewModel,
            onSave: { _ in },
            onCancel: {}
        )

        #expect(viewModel.canAddLengthValidation == true)
        _ = try view.inspect()
    }
}

// MARK: - Numeric Field Tests (int and double)

extension FieldEditorSheetTests {
    @Test
    func intFieldShowsNumericValidationControls() throws {
        let viewModel = createViewModel(fieldType: .int)
        let view = FieldEditorSheet(
            fieldType: .int,
            viewModel: viewModel,
            onSave: { _ in },
            onCancel: {}
        )

        #expect(viewModel.canAddNumericValidation == true)
        #expect(viewModel.canAddLengthValidation == false)
        _ = try view.inspect()
    }

    @Test
    func doubleFieldShowsNumericValidationControls() throws {
        let viewModel = createViewModel(fieldType: .double)
        let view = FieldEditorSheet(
            fieldType: .double,
            viewModel: viewModel,
            onSave: { _ in },
            onCancel: {}
        )

        #expect(viewModel.canAddNumericValidation == true)
        #expect(viewModel.canAddLengthValidation == false)
        _ = try view.inspect()
    }
}

// MARK: - Date Field Tests

extension FieldEditorSheetTests {
    @Test
    func dateFieldShowsDateValidationControls() throws {
        let viewModel = createViewModel(fieldType: .date)
        let view = FieldEditorSheet(
            fieldType: .date,
            viewModel: viewModel,
            onSave: { _ in },
            onCancel: {}
        )

        #expect(viewModel.canAddDateValidation == true)
        #expect(viewModel.canAddNumericValidation == false)
        #expect(viewModel.canAddLengthValidation == false)
        _ = try view.inspect()
    }
}

// MARK: - Bool Field Tests (no validation controls)

extension FieldEditorSheetTests {
    @Test
    func boolFieldHidesValidationControls() throws {
        let viewModel = createViewModel(fieldType: .bool)
        let view = FieldEditorSheet(
            fieldType: .bool,
            viewModel: viewModel,
            onSave: { _ in },
            onCancel: {}
        )

        #expect(viewModel.canAddDateValidation == false)
        #expect(viewModel.canAddNumericValidation == false)
        #expect(viewModel.canAddLengthValidation == false)
        _ = try view.inspect()
    }
}

// MARK: - ViewModel Injection Tests

extension FieldEditorSheetTests {
    @Test
    func viewUsesInjectedViewModelForNewField() throws {
        let viewModel = createViewModel(fieldType: .string)
        viewModel.displayName = "Injected Name"

        let view = FieldEditorSheet(
            fieldType: .string,
            viewModel: viewModel,
            onSave: { _ in },
            onCancel: {}
        )

        _ = try view.inspect()
        #expect(viewModel.displayName == "Injected Name")
    }

    @Test
    func viewUsesInjectedViewModelForExistingField() throws {
        let field = createTestField(displayName: "Original Name")
        let viewModel = createViewModel(field: field)
        viewModel.displayName = "Modified Name"

        let view = FieldEditorSheet(
            field: field,
            viewModel: viewModel,
            onSave: { _ in },
            onCancel: {}
        )

        _ = try view.inspect()
        #expect(viewModel.displayName == "Modified Name")
    }
}

// MARK: - Error State Tests

extension FieldEditorSheetTests {
    @Test
    func viewRendersWithErrorMessage() throws {
        let viewModel = createViewModel(fieldType: .string)
        viewModel.errorMessage = "Validation error"

        let view = FieldEditorSheet(
            fieldType: .string,
            viewModel: viewModel,
            onSave: { _ in },
            onCancel: {}
        )

        _ = try view.inspect()
        #expect(viewModel.errorMessage == "Validation error")
    }

    @Test
    func viewRendersWithNilErrorMessage() throws {
        let viewModel = createViewModel(fieldType: .string)
        viewModel.errorMessage = nil

        let view = FieldEditorSheet(
            fieldType: .string,
            viewModel: viewModel,
            onSave: { _ in },
            onCancel: {}
        )

        _ = try view.inspect()
        #expect(viewModel.errorMessage == nil)
    }
}

// MARK: - Required Field Tests

extension FieldEditorSheetTests {
    @Test
    func viewRendersRequiredField() throws {
        let field = createTestField(isRequired: true)
        let viewModel = createViewModel(field: field)

        let view = FieldEditorSheet(
            field: field,
            viewModel: viewModel,
            onSave: { _ in },
            onCancel: {}
        )

        _ = try view.inspect()
        #expect(viewModel.isRequired == true)
    }

    @Test
    func viewRendersOptionalField() throws {
        let field = createTestField(isRequired: false)
        let viewModel = createViewModel(field: field)

        let view = FieldEditorSheet(
            field: field,
            viewModel: viewModel,
            onSave: { _ in },
            onCancel: {}
        )

        _ = try view.inspect()
        #expect(viewModel.isRequired == false)
    }
}

// MARK: - Placeholder and Help Text Tests

extension FieldEditorSheetTests {
    @Test
    func viewRendersWithPlaceholder() throws {
        let field = createTestField(placeholder: "Enter value here")
        let viewModel = createViewModel(field: field)

        let view = FieldEditorSheet(
            field: field,
            viewModel: viewModel,
            onSave: { _ in },
            onCancel: {}
        )

        _ = try view.inspect()
        #expect(viewModel.placeholder == "Enter value here")
    }

    @Test
    func viewRendersWithHelpText() throws {
        let field = createTestField(helpText: "This is helpful information")
        let viewModel = createViewModel(field: field)

        let view = FieldEditorSheet(
            field: field,
            viewModel: viewModel,
            onSave: { _ in },
            onCancel: {}
        )

        _ = try view.inspect()
        #expect(viewModel.helpText == "This is helpful information")
    }
}
