import SwiftUI
import Testing
import ViewInspector
@testable import FamilyMedicalApp

// MARK: - Test Case Structure

/// Test case for parameterized FieldDisplayView testing
struct FieldDisplayTestCase: Sendable {
    let name: String
    let field: FieldDefinition
    let value: FieldValue?
    /// Expected text content in the value area (nil means check for empty placeholder "-")
    let expectedText: String?

    /// Convenience initializer with standard field
    init(
        name: String,
        fieldType: FieldType,
        value: FieldValue?,
        expectedText: String?
    ) {
        self.name = name
        field = FieldDefinition.builtIn(
            id: UUID(),
            displayName: "Test Field",
            fieldType: fieldType
        )
        self.value = value
        self.expectedText = expectedText
    }
}

extension FieldDisplayTestCase: CustomTestStringConvertible {
    var testDescription: String { name }
}

// MARK: - Test Cases

private let fieldDisplayTestCases: [FieldDisplayTestCase] = [
    // String values
    FieldDisplayTestCase(
        name: "string displays text content",
        fieldType: .string,
        value: .string("COVID-19 Vaccine"),
        expectedText: "COVID-19 Vaccine"
    ),
    FieldDisplayTestCase(
        name: "string displays empty string",
        fieldType: .string,
        value: .string(""),
        expectedText: ""
    ),

    // Int values
    FieldDisplayTestCase(
        name: "int displays number",
        fieldType: .int,
        value: .int(42),
        expectedText: "42"
    ),
    FieldDisplayTestCase(
        name: "int displays zero",
        fieldType: .int,
        value: .int(0),
        expectedText: "0"
    ),
    FieldDisplayTestCase(
        name: "int displays negative",
        fieldType: .int,
        value: .int(-5),
        expectedText: "-5"
    ),

    // Double values - Swift's number formatter handles precision
    FieldDisplayTestCase(
        name: "double displays whole number",
        fieldType: .double,
        value: .double(98.0),
        expectedText: "98"
    ),
    FieldDisplayTestCase(
        name: "double displays one decimal",
        fieldType: .double,
        value: .double(98.6),
        expectedText: "98.6"
    ),
    FieldDisplayTestCase(
        name: "double displays two decimals",
        fieldType: .double,
        value: .double(98.65),
        expectedText: "98.65"
    ),

    // Bool values - displays Yes/No with icon
    FieldDisplayTestCase(
        name: "bool true displays Yes",
        fieldType: .bool,
        value: .bool(true),
        expectedText: "Yes"
    ),
    FieldDisplayTestCase(
        name: "bool false displays No",
        fieldType: .bool,
        value: .bool(false),
        expectedText: "No"
    ),

    // Attachment IDs
    FieldDisplayTestCase(
        name: "attachmentIds single shows singular",
        fieldType: .attachmentIds,
        value: .attachmentIds([UUID()]),
        expectedText: "1 attachment"
    ),
    FieldDisplayTestCase(
        name: "attachmentIds multiple shows plural",
        fieldType: .attachmentIds,
        value: .attachmentIds([UUID(), UUID(), UUID()]),
        expectedText: "3 attachments"
    ),
    FieldDisplayTestCase(
        name: "attachmentIds empty shows placeholder",
        fieldType: .attachmentIds,
        value: .attachmentIds([]),
        expectedText: nil // Empty shows "-" placeholder
    ),

    // String arrays
    FieldDisplayTestCase(
        name: "stringArray shows comma-separated",
        fieldType: .stringArray,
        value: .stringArray(["Important", "Follow-up"]),
        expectedText: "Important, Follow-up"
    ),
    FieldDisplayTestCase(
        name: "stringArray single item",
        fieldType: .stringArray,
        value: .stringArray(["Urgent"]),
        expectedText: "Urgent"
    ),
    FieldDisplayTestCase(
        name: "stringArray empty shows placeholder",
        fieldType: .stringArray,
        value: .stringArray([]),
        expectedText: nil // Empty shows "-" placeholder
    ),

    // Nil values
    FieldDisplayTestCase(
        name: "nil value shows placeholder",
        fieldType: .string,
        value: nil,
        expectedText: nil // nil shows "-" placeholder
    )
]

// MARK: - Tests

@MainActor
struct FieldDisplayViewTests {
    // MARK: - Parameterized Tests

    @Test(arguments: fieldDisplayTestCases)
    func fieldDisplayViewShowsCorrectContent(_ testCase: FieldDisplayTestCase) throws {
        let view = FieldDisplayView(field: testCase.field, value: testCase.value)

        if let expectedText = testCase.expectedText {
            // Find the text in the view
            let text = try view.inspect().find(text: expectedText)
            #expect(try text.string() == expectedText)
        } else {
            // Empty/nil values should show "-" placeholder
            let placeholder = try view.inspect().find(text: "-")
            #expect(try placeholder.string() == "-")
        }
    }

    // MARK: - Label Tests

    @Test
    func fieldDisplayViewShowsFieldLabel() throws {
        let field = FieldDefinition.builtIn(
            id: UUID(),
            displayName: "Vaccine Name",
            fieldType: .string
        )
        let view = FieldDisplayView(field: field, value: .string("Pfizer"))

        let labelText = try view.inspect().find(text: "Vaccine Name")
        #expect(try labelText.string() == "Vaccine Name")
    }

    // MARK: - Date Display Tests

    // Date tests are separate because the formatted output is locale-dependent
    @Test
    func fieldDisplayViewShowsDateValue() throws {
        let testDate = Date(timeIntervalSince1970: 631_152_000) // Jan 1, 1990
        let field = FieldDefinition.builtIn(
            id: UUID(),
            displayName: "Date Administered",
            fieldType: .date
        )
        let view = FieldDisplayView(field: field, value: .date(testDate))

        // Date is formatted by Text(date, style: .date)
        // Verify the view renders without throwing and contains the label
        let labelText = try view.inspect().find(text: "Date Administered")
        #expect(try labelText.string() == "Date Administered")
    }

    // MARK: - Bool Icon Tests

    @Test
    func boolTrueShowsCheckmarkIcon() throws {
        let field = FieldDefinition.builtIn(
            id: UUID(),
            displayName: "Is Active",
            fieldType: .bool
        )
        let view = FieldDisplayView(field: field, value: .bool(true))

        // Bool values use Label which contains an Image
        let label = try view.inspect().find(ViewType.Label.self)
        let image = try label.icon().image()
        #expect(try image.actualImage().name() == "checkmark.circle.fill")
    }

    @Test
    func boolFalseShowsXmarkIcon() throws {
        let field = FieldDefinition.builtIn(
            id: UUID(),
            displayName: "Is Active",
            fieldType: .bool
        )
        let view = FieldDisplayView(field: field, value: .bool(false))

        let label = try view.inspect().find(ViewType.Label.self)
        let image = try label.icon().image()
        #expect(try image.actualImage().name() == "xmark.circle")
    }

    // MARK: - Empty Value Style Tests

    @Test
    func emptyPlaceholderIsRendered() throws {
        let field = FieldDefinition.builtIn(
            id: UUID(),
            displayName: "Notes",
            fieldType: .string
        )
        let view = FieldDisplayView(field: field, value: nil)

        let placeholder = try view.inspect().find(text: "-")
        // Verify the placeholder text exists and view renders correctly
        #expect(try placeholder.string() == "-")
    }

    // MARK: - LabeledContent Structure Tests

    @Test
    func viewUsesLabeledContentStructure() throws {
        let field = FieldDefinition.builtIn(
            id: UUID(),
            displayName: "Test Label",
            fieldType: .string
        )
        let view = FieldDisplayView(field: field, value: .string("Test Value"))

        // Verify both the label and value are present
        _ = try view.inspect().find(text: "Test Label")
        _ = try view.inspect().find(text: "Test Value")
    }
}
