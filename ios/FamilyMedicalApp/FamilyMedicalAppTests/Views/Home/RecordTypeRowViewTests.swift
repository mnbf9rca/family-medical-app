import SwiftUI
import Testing
import ViewInspector
@testable import FamilyMedicalApp

@MainActor
struct RecordTypeRowViewTests {
    // MARK: - Content Tests

    @Test
    func viewDisplaysSchemaTypeName() throws {
        let view = RecordTypeRowView(schema: RecordSchema.builtIn(.vaccine), recordCount: 3)

        let hStack = try view.inspect().hStack()
        let nameText = try hStack.text(1)
        #expect(try nameText.string() == "Vaccine")
    }

    @Test
    func viewDisplaysRecordCount() throws {
        let view = RecordTypeRowView(schema: RecordSchema.builtIn(.condition), recordCount: 5)

        let hStack = try view.inspect().hStack()
        // HStack has: Image(0), Text(1), Spacer(2), Text(3) when count > 0
        let countText = try hStack.text(3)
        #expect(try countText.string() == "5")
    }

    @Test
    func viewHidesCountWhenZero() throws {
        let view = RecordTypeRowView(schema: RecordSchema.builtIn(.medication), recordCount: 0)

        let hStack = try view.inspect().hStack()
        // Should only have image, name text, and spacer - no count
        #expect(throws: (any Error).self) {
            _ = try hStack.text(2)
        }
    }

    @Test
    func viewDisplaysIcon() throws {
        let view = RecordTypeRowView(schema: RecordSchema.builtIn(.allergy), recordCount: 1)

        let hStack = try view.inspect().hStack()
        let image = try hStack.image(0)
        #expect(throws: Never.self) {
            _ = try image.actualImage()
        }
    }

    @Test
    func viewRendersSuccessfully() throws {
        let view = RecordTypeRowView(schema: RecordSchema.builtIn(.note), recordCount: 2)

        // Just verify the view structure can be inspected
        _ = try view.inspect()
    }

    @Test
    func viewHandlesMultipleRecordCounts() throws {
        for count in [0, 1, 5, 10, 100] {
            let view = RecordTypeRowView(schema: RecordSchema.builtIn(.vaccine), recordCount: count)
            _ = try view.inspect()
        }
    }

    @Test
    func viewWorksWithAllSchemaTypes() throws {
        for schemaType in BuiltInSchemaType.allCases {
            let view = RecordTypeRowView(schema: RecordSchema.builtIn(schemaType), recordCount: 1)
            _ = try view.inspect()
        }
    }
}
