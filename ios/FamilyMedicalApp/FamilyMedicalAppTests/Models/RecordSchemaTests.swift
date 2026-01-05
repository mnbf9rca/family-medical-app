import Foundation
import Testing
@testable import FamilyMedicalApp

struct RecordSchemaTests {
    // MARK: - Test Field IDs

    // Stable UUIDs for consistent field identity across tests
    // swiftlint:disable force_unwrapping
    private static let field1Id = UUID(uuidString: "44444444-0001-0001-0000-000000000001")!
    private static let field2Id = UUID(uuidString: "44444444-0001-0002-0000-000000000001")!
    private static let field3Id = UUID(uuidString: "44444444-0001-0003-0000-000000000001")!
    private static let nameFieldId = UUID(uuidString: "44444444-0002-0001-0000-000000000001")!
    private static let required1Id = UUID(uuidString: "44444444-0003-0001-0000-000000000001")!
    private static let required2Id = UUID(uuidString: "44444444-0003-0002-0000-000000000001")!
    private static let optional1Id = UUID(uuidString: "44444444-0003-0003-0000-000000000001")!
    // swiftlint:enable force_unwrapping

    // MARK: - Valid Initialization

    @Test
    func init_validSchema_succeeds() throws {
        let schema = try RecordSchema(
            id: "test-schema",
            displayName: "Test Schema",
            iconSystemName: "star",
            fields: [
                .builtIn(
                    id: Self.field1Id,
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
                    .builtIn(
                        id: Self.field1Id,
                        displayName: "Field 1",
                        fieldType: .string
                    ),
                    .builtIn(
                        id: Self.field1Id,
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
                .builtIn(
                    id: Self.nameFieldId,
                    displayName: "Name",
                    fieldType: .string
                )
            ]
        )

        let field = schema.field(withId: Self.nameFieldId)
        #expect(field?.id == Self.nameFieldId)
    }

    @Test
    func field_withId_nonExistentField_returnsNil() throws {
        let schema = try RecordSchema(
            id: "test",
            displayName: "Test",
            iconSystemName: "star",
            fields: []
        )

        let field = schema.field(withId: UUID())
        #expect(field == nil)
    }

    @Test
    func requiredFieldIds_returnsOnlyRequired() throws {
        let schema = try RecordSchema(
            id: "test",
            displayName: "Test",
            iconSystemName: "star",
            fields: [
                .builtIn(
                    id: Self.required1Id,
                    displayName: "Required 1",
                    fieldType: .string,
                    isRequired: true
                ),
                .builtIn(
                    id: Self.optional1Id,
                    displayName: "Optional 1",
                    fieldType: .string,
                    isRequired: false
                ),
                .builtIn(
                    id: Self.required2Id,
                    displayName: "Required 2",
                    fieldType: .string,
                    isRequired: true
                )
            ]
        )

        let requiredIds = schema.requiredFieldIds
        #expect(requiredIds.count == 2)
        #expect(requiredIds.contains(Self.required1Id))
        #expect(requiredIds.contains(Self.required2Id))
    }

    @Test
    func fieldsByDisplayOrder_returnsSorted() throws {
        let schema = try RecordSchema(
            id: "test",
            displayName: "Test",
            iconSystemName: "star",
            fields: [
                .builtIn(
                    id: Self.field3Id,
                    displayName: "Field 3",
                    fieldType: .string,
                    displayOrder: 3
                ),
                .builtIn(
                    id: Self.field1Id,
                    displayName: "Field 1",
                    fieldType: .string,
                    displayOrder: 1
                ),
                .builtIn(
                    id: Self.field2Id,
                    displayName: "Field 2",
                    fieldType: .string,
                    displayOrder: 2
                )
            ]
        )

        let sorted = schema.fieldsByDisplayOrder
        #expect(sorted[0].id == Self.field1Id)
        #expect(sorted[1].id == Self.field2Id)
        #expect(sorted[2].id == Self.field3Id)
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
                .builtIn(
                    id: Self.field1Id,
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
