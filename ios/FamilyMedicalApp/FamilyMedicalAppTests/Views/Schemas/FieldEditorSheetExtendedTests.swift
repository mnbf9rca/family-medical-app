import Dependencies
import SwiftUI
import Testing
import ViewInspector
@testable import FamilyMedicalApp

/// Extended tests for FieldEditorSheet - Validation Rules, Multiline/Capitalization, and Title tests
@MainActor
struct FieldEditorSheetExtendedTests {
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

    // MARK: - Validation Rules Tests

    @Test
    func viewRendersWithMinLengthRule() throws {
        let field = createTestField(
            displayName: "String Field",
            fieldType: .string,
            validationRules: [.minLength(5)]
        )
        let viewModel = createViewModel(field: field)
        let view = FieldEditorSheet(
            field: field,
            viewModel: viewModel,
            onSave: { _ in },
            onCancel: {}
        )

        #expect(viewModel.validationRules.contains(.minLength(5)))
        _ = try view.inspect()
    }

    @Test
    func viewRendersWithMaxLengthRule() throws {
        let field = createTestField(
            displayName: "String Field",
            fieldType: .string,
            validationRules: [.maxLength(100)]
        )
        let viewModel = createViewModel(field: field)
        let view = FieldEditorSheet(
            field: field,
            viewModel: viewModel,
            onSave: { _ in },
            onCancel: {}
        )

        #expect(viewModel.validationRules.contains(.maxLength(100)))
        _ = try view.inspect()
    }

    @Test
    func viewRendersWithMinValueRule() throws {
        let field = createTestField(
            displayName: "Number Field",
            fieldType: .int,
            validationRules: [.minValue(0)]
        )
        let viewModel = createViewModel(field: field)
        let view = FieldEditorSheet(
            field: field,
            viewModel: viewModel,
            onSave: { _ in },
            onCancel: {}
        )

        #expect(viewModel.validationRules.contains(.minValue(0)))
        _ = try view.inspect()
    }

    @Test
    func viewRendersWithMaxValueRule() throws {
        let field = createTestField(
            displayName: "Number Field",
            fieldType: .double,
            validationRules: [.maxValue(100.5)]
        )
        let viewModel = createViewModel(field: field)
        let view = FieldEditorSheet(
            field: field,
            viewModel: viewModel,
            onSave: { _ in },
            onCancel: {}
        )

        #expect(viewModel.validationRules.contains(.maxValue(100.5)))
        _ = try view.inspect()
    }

    @Test
    func viewRendersWithMinDateRule() throws {
        let minDate = Date(timeIntervalSinceReferenceDate: 0)
        let field = createTestField(
            displayName: "Date Field",
            fieldType: .date,
            validationRules: [.minDate(minDate)]
        )
        let viewModel = createViewModel(field: field)
        let view = FieldEditorSheet(
            field: field,
            viewModel: viewModel,
            onSave: { _ in },
            onCancel: {}
        )

        #expect(viewModel.validationRules.contains(.minDate(minDate)))
        _ = try view.inspect()
    }

    @Test
    func viewRendersWithMaxDateRule() throws {
        let maxDate = Date(timeIntervalSinceReferenceDate: 1_000_000_000)
        let field = createTestField(
            displayName: "Date Field",
            fieldType: .date,
            validationRules: [.maxDate(maxDate)]
        )
        let viewModel = createViewModel(field: field)
        let view = FieldEditorSheet(
            field: field,
            viewModel: viewModel,
            onSave: { _ in },
            onCancel: {}
        )

        #expect(viewModel.validationRules.contains(.maxDate(maxDate)))
        _ = try view.inspect()
    }

    @Test
    func viewRendersWithMultipleValidationRules() throws {
        let field = createTestField(
            displayName: "String Field",
            fieldType: .string,
            validationRules: [.minLength(1), .maxLength(255)]
        )
        let viewModel = createViewModel(field: field)
        let view = FieldEditorSheet(
            field: field,
            viewModel: viewModel,
            onSave: { _ in },
            onCancel: {}
        )

        #expect(viewModel.validationRules.count == 2)
        _ = try view.inspect()
    }
}

// MARK: - Multiline and Capitalization Tests

extension FieldEditorSheetExtendedTests {
    @Test
    func viewRendersWithMultilineEnabled() throws {
        var field = createTestField(fieldType: .string)
        field = FieldDefinition(
            id: field.id,
            displayName: field.displayName,
            fieldType: .string,
            isRequired: false,
            displayOrder: 1,
            placeholder: nil,
            helpText: nil,
            validationRules: [],
            isMultiline: true,
            capitalizationMode: .sentences,
            visibility: .active,
            createdBy: .zero,
            createdAt: Date(),
            updatedBy: .zero,
            updatedAt: Date()
        )
        let viewModel = createViewModel(field: field)

        let view = FieldEditorSheet(
            field: field,
            viewModel: viewModel,
            onSave: { _ in },
            onCancel: {}
        )

        _ = try view.inspect()
        #expect(viewModel.isMultiline == true)
    }

    @Test
    func viewRendersWithDifferentCapitalizationModes() throws {
        let modes: [TextCapitalizationMode] = [.none, .words, .sentences, .allCharacters]
        for mode in modes {
            let field = FieldDefinition(
                id: UUID(),
                displayName: "Test Field",
                fieldType: .string,
                isRequired: false,
                displayOrder: 1,
                placeholder: nil,
                helpText: nil,
                validationRules: [],
                isMultiline: false,
                capitalizationMode: mode,
                visibility: .active,
                createdBy: .zero,
                createdAt: Date(),
                updatedBy: .zero,
                updatedAt: Date()
            )
            let viewModel = createViewModel(field: field)

            let view = FieldEditorSheet(
                field: field,
                viewModel: viewModel,
                onSave: { _ in },
                onCancel: {}
            )

            _ = try view.inspect()
            #expect(viewModel.capitalizationMode == mode)
        }
    }
}

// MARK: - New vs Existing Field Title Tests

extension FieldEditorSheetExtendedTests {
    @Test
    func newFieldHasNewFieldTitle() throws {
        let viewModel = createViewModel(fieldType: .string)

        let view = FieldEditorSheet(
            fieldType: .string,
            viewModel: viewModel,
            onSave: { _ in },
            onCancel: {}
        )

        _ = try view.inspect()
        #expect(viewModel.isNewField == true)
    }

    @Test
    func existingFieldHasEditFieldTitle() throws {
        let field = createTestField()
        let viewModel = createViewModel(field: field)

        let view = FieldEditorSheet(
            field: field,
            viewModel: viewModel,
            onSave: { _ in },
            onCancel: {}
        )

        _ = try view.inspect()
        #expect(viewModel.isNewField == false)
    }
}
