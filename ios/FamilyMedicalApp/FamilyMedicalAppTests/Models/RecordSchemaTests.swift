import Foundation
import Testing
@testable import FamilyMedicalApp

struct RecordSchemaTests {
    // MARK: - Valid Initialization

    @Test
    func init_validSchema_succeeds() throws {
        let schema = try RecordSchema(
            id: "test-schema",
            displayName: "Test Schema",
            iconSystemName: "star",
            fields: [
                FieldDefinition(
                    id: "field1",
                    displayName: "Field 1",
                    fieldType: .string
                )
            ]
        )

        #expect(schema.id == "test-schema")
        #expect(schema.displayName == "Test Schema")
        #expect(schema.fields.count == 1)
    }

    // MARK: - Schema ID Validation

    @Test
    func init_emptySchemaId_throwsError() {
        #expect(throws: ModelError.self) {
            _ = try RecordSchema(
                id: "",
                displayName: "Test",
                iconSystemName: "star",
                fields: []
            )
        }
    }

    @Test
    func init_whitespaceSchemaId_throwsError() {
        #expect(throws: ModelError.self) {
            _ = try RecordSchema(
                id: "   ",
                displayName: "Test",
                iconSystemName: "star",
                fields: []
            )
        }
    }

    // MARK: - Duplicate Field Detection

    @Test
    func init_duplicateFieldIds_throwsError() {
        #expect(throws: ModelError.self) {
            _ = try RecordSchema(
                id: "test",
                displayName: "Test",
                iconSystemName: "star",
                fields: [
                    FieldDefinition(
                        id: "field1",
                        displayName: "Field 1",
                        fieldType: .string
                    ),
                    FieldDefinition(
                        id: "field1",
                        displayName: "Duplicate Field",
                        fieldType: .int
                    )
                ]
            )
        }
    }

    // MARK: - Field Access

    @Test
    func field_withId_existingField_returnsField() throws {
        let schema = try RecordSchema(
            id: "test",
            displayName: "Test",
            iconSystemName: "star",
            fields: [
                FieldDefinition(
                    id: "name",
                    displayName: "Name",
                    fieldType: .string
                )
            ]
        )

        let field = schema.field(withId: "name")
        #expect(field?.id == "name")
    }

    @Test
    func field_withId_nonExistentField_returnsNil() throws {
        let schema = try RecordSchema(
            id: "test",
            displayName: "Test",
            iconSystemName: "star",
            fields: []
        )

        let field = schema.field(withId: "nonexistent")
        #expect(field == nil)
    }

    @Test
    func requiredFieldIds_returnsOnlyRequired() throws {
        let schema = try RecordSchema(
            id: "test",
            displayName: "Test",
            iconSystemName: "star",
            fields: [
                FieldDefinition(
                    id: "required1",
                    displayName: "Required 1",
                    fieldType: .string,
                    isRequired: true
                ),
                FieldDefinition(
                    id: "optional1",
                    displayName: "Optional 1",
                    fieldType: .string,
                    isRequired: false
                ),
                FieldDefinition(
                    id: "required2",
                    displayName: "Required 2",
                    fieldType: .string,
                    isRequired: true
                )
            ]
        )

        let requiredIds = schema.requiredFieldIds
        #expect(requiredIds.count == 2)
        #expect(requiredIds.contains("required1"))
        #expect(requiredIds.contains("required2"))
    }

    @Test
    func fieldsByDisplayOrder_returnsSorted() throws {
        let schema = try RecordSchema(
            id: "test",
            displayName: "Test",
            iconSystemName: "star",
            fields: [
                FieldDefinition(
                    id: "field3",
                    displayName: "Field 3",
                    fieldType: .string,
                    displayOrder: 3
                ),
                FieldDefinition(
                    id: "field1",
                    displayName: "Field 1",
                    fieldType: .string,
                    displayOrder: 1
                ),
                FieldDefinition(
                    id: "field2",
                    displayName: "Field 2",
                    fieldType: .string,
                    displayOrder: 2
                )
            ]
        )

        let sorted = schema.fieldsByDisplayOrder
        #expect(sorted[0].id == "field1")
        #expect(sorted[1].id == "field2")
        #expect(sorted[2].id == "field3")
    }

    // MARK: - Built-in Schema Types

    @Test
    func builtInSchemaType_allCasesHaveNamesAndIcons() {
        for type in BuiltInSchemaType.allCases {
            #expect(!type.displayName.isEmpty)
            #expect(!type.iconSystemName.isEmpty)
        }
    }

    @Test
    func builtIn_returnsCorrectSchema() {
        let vaccineSchema = RecordSchema.builtIn(.vaccine)
        #expect(vaccineSchema.id == "vaccine")
        #expect(vaccineSchema.isBuiltIn)
    }

    // MARK: - Codable

    @Test
    func codable_roundTrip() throws {
        let original = try RecordSchema(
            id: "test-schema",
            displayName: "Test Schema",
            iconSystemName: "star",
            fields: [
                FieldDefinition(
                    id: "field1",
                    displayName: "Field 1",
                    fieldType: .string,
                    isRequired: true
                )
            ],
            isBuiltIn: false,
            description: "A test schema"
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RecordSchema.self, from: encoded)

        #expect(decoded == original)
        #expect(decoded.id == original.id)
        #expect(decoded.fields.count == original.fields.count)
    }

    // MARK: - Equatable

    @Test
    func equatable_sameSchema_equal() throws {
        let schema1 = try RecordSchema(
            id: "test",
            displayName: "Test",
            iconSystemName: "star",
            fields: []
        )
        let schema2 = try RecordSchema(
            id: "test",
            displayName: "Test",
            iconSystemName: "star",
            fields: []
        )
        #expect(schema1 == schema2)
    }

    @Test
    func equatable_differentSchema_notEqual() throws {
        let schema1 = try RecordSchema(
            id: "test1",
            displayName: "Test 1",
            iconSystemName: "star",
            fields: []
        )
        let schema2 = try RecordSchema(
            id: "test2",
            displayName: "Test 2",
            iconSystemName: "star",
            fields: []
        )
        #expect(schema1 != schema2)
    }
}
