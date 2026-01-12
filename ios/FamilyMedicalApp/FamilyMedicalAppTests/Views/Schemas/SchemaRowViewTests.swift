import SwiftUI
import Testing
import ViewInspector
@testable import FamilyMedicalApp

@MainActor
struct SchemaRowViewTests {
    // MARK: - Test Data

    func createTestSchema(
        id: String = "test-schema",
        displayName: String = "Test Schema",
        isBuiltIn: Bool = false
    ) -> RecordSchema {
        RecordSchema(
            unsafeId: id,
            displayName: displayName,
            iconSystemName: "doc.text",
            fields: [],
            isBuiltIn: isBuiltIn,
            description: nil
        )
    }

    // MARK: - Content Tests

    @Test
    func viewDisplaysSchemaName() throws {
        let schema = createTestSchema(displayName: "Test Records")
        let view = SchemaRowView(schema: schema, recordCount: 3)

        let hStack = try view.inspect().hStack()
        // VStack is at index 1 after the Image
        let vStack = try hStack.vStack(1)
        // Schema name is the first Text in VStack
        let nameText = try vStack.text(0)
        #expect(try nameText.string() == "Test Records")
    }

    @Test
    func viewDisplaysBuiltInLabel() throws {
        let schema = createTestSchema(isBuiltIn: true)
        let view = SchemaRowView(schema: schema, recordCount: 0)

        let hStack = try view.inspect().hStack()
        let vStack = try hStack.vStack(1)
        let typeText = try vStack.text(1)
        #expect(try typeText.string() == "Built-in")
    }

    @Test
    func viewDisplaysCustomLabel() throws {
        let schema = createTestSchema(isBuiltIn: false)
        let view = SchemaRowView(schema: schema, recordCount: 0)

        let hStack = try view.inspect().hStack()
        let vStack = try hStack.vStack(1)
        let typeText = try vStack.text(1)
        #expect(try typeText.string() == "Custom")
    }

    @Test
    func viewDisplaysRecordCount() throws {
        let schema = createTestSchema()
        let view = SchemaRowView(schema: schema, recordCount: 5)

        let hStack = try view.inspect().hStack()
        // HStack has: Image(0), VStack(1), Spacer(2), Text(3) when count > 0
        let countText = try hStack.text(3)
        #expect(try countText.string() == "5")
    }

    @Test
    func viewHidesCountWhenZero() throws {
        let schema = createTestSchema()
        let view = SchemaRowView(schema: schema, recordCount: 0)

        let hStack = try view.inspect().hStack()
        // When count is 0, there should be no count text
        #expect(throws: (any Error).self) {
            _ = try hStack.text(3)
        }
    }

    @Test
    func viewDisplaysIcon() throws {
        let schema = createTestSchema()
        let view = SchemaRowView(schema: schema, recordCount: 1)

        let hStack = try view.inspect().hStack()
        let image = try hStack.image(0)
        #expect(throws: Never.self) {
            _ = try image.actualImage()
        }
    }

    @Test
    func viewRendersSuccessfully() throws {
        let schema = createTestSchema()
        let view = SchemaRowView(schema: schema, recordCount: 2)

        _ = try view.inspect()
    }

    @Test
    func viewHandlesMultipleRecordCounts() throws {
        let schema = createTestSchema()
        for count in [0, 1, 5, 10, 100] {
            let view = SchemaRowView(schema: schema, recordCount: count)
            _ = try view.inspect()
        }
    }

    @Test
    func viewWorksWithBuiltInSchemas() throws {
        for schemaType in BuiltInSchemaType.allCases {
            let schema = RecordSchema.builtIn(schemaType)
            let view = SchemaRowView(schema: schema, recordCount: 1)
            _ = try view.inspect()
        }
    }
}
