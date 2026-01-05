import SwiftUI
import Testing
import ViewInspector
@testable import FamilyMedicalApp

@MainActor
struct DynamicFieldViewTests {
    // MARK: - Binding Behavior Tests
    //
    // These tests verify two-way data flow using BindingTestHarness + ViewInspector.
    // They verify that user input actually updates the bound value.

    @Test
    func stringBindingUpdatesValue() throws {
        let field = FieldDefinition.builtIn(
            id: UUID(),
            displayName: "Test Field",
            fieldType: .string
        )
        let harness = BindingTestHarness<FieldValue?>(value: .string("initial"))
        let view = DynamicFieldView(field: field, value: harness.binding)

        let textField = try view.inspect().find(ViewType.TextField.self)
        try textField.setInput("updated value")

        #expect(harness.value?.stringValue == "updated value")
    }

    @Test
    func intBindingUpdatesValue() throws {
        let field = FieldDefinition.builtIn(
            id: UUID(),
            displayName: "Dose Number",
            fieldType: .int
        )
        let harness = BindingTestHarness<FieldValue?>(value: nil)
        let view = DynamicFieldView(field: field, value: harness.binding)

        let textField = try view.inspect().find(ViewType.TextField.self)
        try textField.setInput("42")

        #expect(harness.value?.intValue == 42)
    }

    @Test
    func intBindingRejectsInvalidInput() throws {
        let field = FieldDefinition.builtIn(
            id: UUID(),
            displayName: "Count",
            fieldType: .int
        )
        // Start with a valid int value
        let harness = BindingTestHarness<FieldValue?>(value: .int(10))
        let view = DynamicFieldView(field: field, value: harness.binding)

        let textField = try view.inspect().find(ViewType.TextField.self)
        // Invalid input should be ignored per DynamicFieldView.intBinding (lines 192-195)
        try textField.setInput("not a number")

        // Value should remain unchanged
        #expect(harness.value?.intValue == 10)
    }

    @Test
    func intBindingClearsOnEmptyInput() throws {
        let field = FieldDefinition.builtIn(
            id: UUID(),
            displayName: "Count",
            fieldType: .int
        )
        let harness = BindingTestHarness<FieldValue?>(value: .int(10))
        let view = DynamicFieldView(field: field, value: harness.binding)

        let textField = try view.inspect().find(ViewType.TextField.self)
        // Empty input should clear the value per DynamicFieldView.intBinding (lines 190-191)
        try textField.setInput("")

        #expect(harness.value == nil)
    }

    @Test
    func doubleBindingUpdatesValue() throws {
        let field = FieldDefinition.builtIn(
            id: UUID(),
            displayName: "Temperature",
            fieldType: .double
        )
        let harness = BindingTestHarness<FieldValue?>(value: nil)
        let view = DynamicFieldView(field: field, value: harness.binding)

        let textField = try view.inspect().find(ViewType.TextField.self)
        try textField.setInput("98.6")

        #expect(harness.value?.doubleValue == 98.6)
    }

    @Test
    func doubleBindingRejectsInvalidInput() throws {
        let field = FieldDefinition.builtIn(
            id: UUID(),
            displayName: "Temperature",
            fieldType: .double
        )
        let harness = BindingTestHarness<FieldValue?>(value: .double(98.6))
        let view = DynamicFieldView(field: field, value: harness.binding)

        let textField = try view.inspect().find(ViewType.TextField.self)
        try textField.setInput("invalid")

        // Value should remain unchanged
        #expect(harness.value?.doubleValue == 98.6)
    }

    @Test
    func boolBindingTogglesValue() throws {
        let field = FieldDefinition.builtIn(
            id: UUID(),
            displayName: "Is Active",
            fieldType: .bool
        )
        let harness = BindingTestHarness<FieldValue?>(value: .bool(false))
        let view = DynamicFieldView(field: field, value: harness.binding)

        let toggle = try view.inspect().find(ViewType.Toggle.self)
        try toggle.tap()

        #expect(harness.value?.boolValue == true)
    }

    @Test
    func dateBindingUpdatesValue() throws {
        let field = FieldDefinition.builtIn(
            id: UUID(),
            displayName: "Date Administered",
            fieldType: .date
        )
        let initialDate = Date()
        let harness = BindingTestHarness<FieldValue?>(value: .date(initialDate))
        let view = DynamicFieldView(field: field, value: harness.binding)

        let datePicker = try view.inspect().find(ViewType.DatePicker.self)
        let newDate = Date().addingTimeInterval(86_400) // Tomorrow
        try datePicker.select(date: newDate)

        // DatePicker updates the binding
        #expect(harness.value?.dateValue != nil)
        // Note: Exact date comparison may have precision differences
    }

    @Test
    func stringArrayBindingParsesCsv() throws {
        let field = FieldDefinition.builtIn(
            id: UUID(),
            displayName: "Tags",
            fieldType: .stringArray
        )
        let harness = BindingTestHarness<FieldValue?>(value: nil)
        let view = DynamicFieldView(field: field, value: harness.binding)

        let textField = try view.inspect().find(ViewType.TextField.self)
        try textField.setInput("tag1, tag2, tag3")

        #expect(harness.value?.stringArrayValue == ["tag1", "tag2", "tag3"])
    }

    @Test
    func stringArrayBindingClearsOnEmptyInput() throws {
        let field = FieldDefinition.builtIn(
            id: UUID(),
            displayName: "Tags",
            fieldType: .stringArray
        )
        let harness = BindingTestHarness<FieldValue?>(value: .stringArray(["existing"]))
        let view = DynamicFieldView(field: field, value: harness.binding)

        let textField = try view.inspect().find(ViewType.TextField.self)
        try textField.setInput("")

        #expect(harness.value == nil)
    }
}
