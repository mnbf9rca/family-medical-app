import Foundation
@testable import FamilyMedicalApp

/// Example schema that exercises all field types for comprehensive test coverage
enum ExampleSchema {
    // MARK: - Field IDs for Test Schema

    /// Hardcoded UUIDs for test schema fields (following BuiltInFieldIds pattern)
    enum FieldIds {
        // swiftlint:disable force_unwrapping
        static let exampleName = UUID(uuidString: "00000001-FFFE-0001-0000-000000000000")!
        static let quantity = UUID(uuidString: "00000001-FFFE-0002-0000-000000000000")!
        static let measurement = UUID(uuidString: "00000001-FFFE-0003-0000-000000000000")!
        static let isActive = UUID(uuidString: "00000001-FFFE-0004-0000-000000000000")!
        static let recordedDate = UUID(uuidString: "00000001-FFFE-0005-0000-000000000000")!
        static let tags = UUID(uuidString: "00000001-FFFE-0006-0000-000000000000")!
        static let attachmentIds = UUID(uuidString: "00000001-FFFE-0007-0000-000000000000")!
        static let notes = UUID(uuidString: "00000001-FFFE-0008-0000-000000000000")!
        // swiftlint:enable force_unwrapping
    }

    /// A comprehensive example schema containing all supported field types
    ///
    /// This schema is designed for testing purposes to ensure all field types
    /// are properly handled by the UI components and validation logic.
    static var comprehensiveExample: RecordSchema {
        RecordSchema(
            unsafeId: "comprehensive_example",
            displayName: "Comprehensive Example",
            iconSystemName: "doc.text.magnifyingglass",
            fields: [
                // String field (required, with .words capitalization)
                .builtIn(
                    id: FieldIds.exampleName,
                    displayName: "Example Name",
                    fieldType: .string,
                    isRequired: true,
                    displayOrder: 1,
                    placeholder: "Enter name",
                    helpText: "A required string field",
                    validationRules: [.minLength(1), .maxLength(100)],
                    capitalizationMode: .words
                ),

                // Int field
                .builtIn(
                    id: FieldIds.quantity,
                    displayName: "Quantity",
                    fieldType: .int,
                    isRequired: false,
                    displayOrder: 2,
                    placeholder: "0",
                    helpText: "An integer value",
                    validationRules: [.minValue(0), .maxValue(1_000)]
                ),

                // Double field
                .builtIn(
                    id: FieldIds.measurement,
                    displayName: "Measurement",
                    fieldType: .double,
                    isRequired: false,
                    displayOrder: 3,
                    placeholder: "0.0",
                    helpText: "A decimal value",
                    validationRules: [.minValue(0.0), .maxValue(100.0)]
                ),

                // Bool field
                .builtIn(
                    id: FieldIds.isActive,
                    displayName: "Is Active",
                    fieldType: .bool,
                    isRequired: false,
                    displayOrder: 4,
                    helpText: "A boolean flag"
                ),

                // Date field
                .builtIn(
                    id: FieldIds.recordedDate,
                    displayName: "Recorded Date",
                    fieldType: .date,
                    isRequired: true,
                    displayOrder: 5,
                    helpText: "The date this was recorded"
                ),

                // StringArray field
                .builtIn(
                    id: FieldIds.tags,
                    displayName: "Tags",
                    fieldType: .stringArray,
                    isRequired: false,
                    displayOrder: 6,
                    placeholder: "Enter tags (comma-separated)",
                    helpText: "A list of tags"
                ),

                // AttachmentIds field
                .builtIn(
                    id: FieldIds.attachmentIds,
                    displayName: "Attachments",
                    fieldType: .attachmentIds,
                    isRequired: false,
                    displayOrder: 7,
                    helpText: "File attachments"
                ),

                // Optional string field (multiline, for testing optional validation)
                .builtIn(
                    id: FieldIds.notes,
                    displayName: "Notes",
                    fieldType: .string,
                    isRequired: false,
                    displayOrder: 8,
                    placeholder: "Additional notes",
                    helpText: "Optional notes",
                    validationRules: [.maxLength(500)],
                    isMultiline: true
                )
            ]
        )
    }
}
