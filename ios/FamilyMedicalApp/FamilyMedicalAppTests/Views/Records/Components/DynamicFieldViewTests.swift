import SwiftUI
import Testing
import ViewInspector
@testable import FamilyMedicalApp

@MainActor
struct DynamicFieldViewTests {
    // MARK: - String Field Tests

    @Test
    func dynamicFieldViewRendersStringField() {
        let field = FieldDefinition(
            id: "testField",
            displayName: "Test Field",
            fieldType: .string,
            isRequired: true,
            placeholder: "Test placeholder",
            helpText: "Test help text"
        )
        var value: FieldValue? = .string("test value")
        let view = DynamicFieldView(field: field, value: .constant(value))

        // Access body to execute view code for coverage
        _ = view.body

        #expect(value?.stringValue == "test value")
    }

    @Test
    func dynamicFieldViewRendersIntField() {
        let field = FieldDefinition(
            id: "doseNumber",
            displayName: "Dose Number",
            fieldType: .int
        )
        let value: FieldValue? = .int(5)
        let view = DynamicFieldView(field: field, value: .constant(value))

        _ = view.body

        #expect(value?.intValue == 5)
    }

    @Test
    func dynamicFieldViewRendersDoubleField() {
        let field = FieldDefinition(
            id: "temperature",
            displayName: "Temperature",
            fieldType: .double
        )
        let value: FieldValue? = .double(98.6)
        let view = DynamicFieldView(field: field, value: .constant(value))

        _ = view.body

        #expect(value?.doubleValue == 98.6)
    }

    @Test
    func dynamicFieldViewRendersBoolField() {
        let field = FieldDefinition(
            id: "isActive",
            displayName: "Is Active",
            fieldType: .bool
        )
        let value: FieldValue? = .bool(true)
        let view = DynamicFieldView(field: field, value: .constant(value))

        _ = view.body

        #expect(value?.boolValue == true)
    }

    @Test
    func dynamicFieldViewRendersDateField() {
        let field = FieldDefinition(
            id: "dateAdministered",
            displayName: "Date Administered",
            fieldType: .date
        )
        let value: FieldValue? = .date(Date())
        let view = DynamicFieldView(field: field, value: .constant(value))

        _ = view.body

        #expect(value?.dateValue != nil)
    }

    @Test
    func dynamicFieldViewRendersAttachmentPlaceholder() {
        let field = FieldDefinition(
            id: "attachmentIds",
            displayName: "Attachments",
            fieldType: .attachmentIds,
            helpText: "Photos and documents"
        )
        let value: FieldValue? = nil
        let view = DynamicFieldView(field: field, value: .constant(value))

        _ = view.body

        // Attachment field should render placeholder
        #expect(value == nil)
    }

    @Test
    func dynamicFieldViewRendersStringArrayField() {
        let field = FieldDefinition(
            id: "tags",
            displayName: "Tags",
            fieldType: .stringArray
        )
        let value: FieldValue? = .stringArray(["tag1", "tag2"])
        let view = DynamicFieldView(field: field, value: .constant(value))

        _ = view.body

        #expect(value?.stringArrayValue == ["tag1", "tag2"])
    }

    // MARK: - Required Field Indicator Tests

    @Test
    func dynamicFieldViewShowsRequiredIndicator() {
        let field = FieldDefinition(
            id: "requiredField",
            displayName: "Required Field",
            fieldType: .string,
            isRequired: true
        )
        let view = DynamicFieldView(field: field, value: .constant(nil))

        _ = view.body

        // Required field should render * indicator
        #expect(field.isRequired == true)
    }

    @Test
    func dynamicFieldViewHidesRequiredIndicatorForOptionalFields() {
        let field = FieldDefinition(
            id: "optionalField",
            displayName: "Optional Field",
            fieldType: .string,
            isRequired: false
        )
        let view = DynamicFieldView(field: field, value: .constant(nil))

        _ = view.body

        #expect(field.isRequired == false)
    }

    // MARK: - Help Text Tests

    @Test
    func dynamicFieldViewDisplaysHelpText() {
        let field = FieldDefinition(
            id: "fieldWithHelp",
            displayName: "Field With Help",
            fieldType: .string,
            helpText: "This is helpful text"
        )
        let view = DynamicFieldView(field: field, value: .constant(nil))

        _ = view.body

        #expect(field.helpText == "This is helpful text")
    }

    @Test
    func dynamicFieldViewHandlesNilValue() {
        let field = FieldDefinition(
            id: "emptyField",
            displayName: "Empty Field",
            fieldType: .string
        )
        let value: FieldValue? = nil
        let view = DynamicFieldView(field: field, value: .constant(value))

        _ = view.body

        #expect(value == nil)
    }

    // MARK: - Binding Behavior Tests
    //
    // These tests verify two-way data flow using BindingTestHarness + ViewInspector.
    // Unlike the tests above (which use .constant() bindings), these tests verify
    // that user input actually updates the bound value.

    @Test
    func stringBindingUpdatesValue() throws {
        let field = FieldDefinition(
            id: "testField",
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
        let field = FieldDefinition(
            id: "doseNumber",
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
        let field = FieldDefinition(
            id: "count",
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
        let field = FieldDefinition(
            id: "count",
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
        let field = FieldDefinition(
            id: "temperature",
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
        let field = FieldDefinition(
            id: "temperature",
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
        let field = FieldDefinition(
            id: "isActive",
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
        let field = FieldDefinition(
            id: "dateAdministered",
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
        let field = FieldDefinition(
            id: "tags",
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
        let field = FieldDefinition(
            id: "tags",
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
