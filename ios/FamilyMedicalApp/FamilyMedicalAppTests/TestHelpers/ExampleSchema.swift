import Foundation
@testable import FamilyMedicalApp

/// Example schema that exercises all field types for comprehensive test coverage
enum ExampleSchema {
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
                // String field (required)
                FieldDefinition(
                    id: "exampleName",
                    displayName: "Example Name",
                    fieldType: .string,
                    isRequired: true,
                    displayOrder: 1,
                    placeholder: "Enter name",
                    helpText: "A required string field",
                    validationRules: [.minLength(1), .maxLength(100)]
                ),

                // Int field
                FieldDefinition(
                    id: "quantity",
                    displayName: "Quantity",
                    fieldType: .int,
                    isRequired: false,
                    displayOrder: 2,
                    placeholder: "0",
                    helpText: "An integer value",
                    validationRules: [.minValue(0), .maxValue(1_000)]
                ),

                // Double field
                FieldDefinition(
                    id: "measurement",
                    displayName: "Measurement",
                    fieldType: .double,
                    isRequired: false,
                    displayOrder: 3,
                    placeholder: "0.0",
                    helpText: "A decimal value",
                    validationRules: [.minValue(0.0), .maxValue(100.0)]
                ),

                // Bool field
                FieldDefinition(
                    id: "isActive",
                    displayName: "Is Active",
                    fieldType: .bool,
                    isRequired: false,
                    displayOrder: 4,
                    helpText: "A boolean flag"
                ),

                // Date field
                FieldDefinition(
                    id: "recordedDate",
                    displayName: "Recorded Date",
                    fieldType: .date,
                    isRequired: true,
                    displayOrder: 5,
                    helpText: "The date this was recorded"
                ),

                // StringArray field
                FieldDefinition(
                    id: "tags",
                    displayName: "Tags",
                    fieldType: .stringArray,
                    isRequired: false,
                    displayOrder: 6,
                    placeholder: "Enter tags (comma-separated)",
                    helpText: "A list of tags"
                ),

                // AttachmentIds field
                FieldDefinition(
                    id: "attachmentIds",
                    displayName: "Attachments",
                    fieldType: .attachmentIds,
                    isRequired: false,
                    displayOrder: 7,
                    helpText: "File attachments"
                ),

                // Optional string field (for testing optional validation)
                FieldDefinition(
                    id: "notes",
                    displayName: "Notes",
                    fieldType: .string,
                    isRequired: false,
                    displayOrder: 8,
                    placeholder: "Additional notes",
                    helpText: "Optional notes",
                    validationRules: [.maxLength(500)]
                )
            ]
        )
    }
}
