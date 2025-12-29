import Foundation
import Testing
@testable import FamilyMedicalApp

struct RecordSchemaValidationTests {
    // MARK: - Validation

    @Test
    func validate_allRequiredFieldsPresent_succeeds() throws {
        let schema = try RecordSchema(
            id: "test",
            displayName: "Test",
            iconSystemName: "star",
            fields: [
                FieldDefinition(
                    id: "name",
                    displayName: "Name",
                    fieldType: .string,
                    isRequired: true
                )
            ]
        )

        var content = RecordContent()
        content.setString("name", "John")

        try schema.validate(content: content)
    }

    @Test
    func validate_missingRequiredField_throwsError() throws {
        let schema = try RecordSchema(
            id: "test",
            displayName: "Test",
            iconSystemName: "star",
            fields: [
                FieldDefinition(
                    id: "name",
                    displayName: "Name",
                    fieldType: .string,
                    isRequired: true
                )
            ]
        )

        let content = RecordContent()

        #expect(throws: ModelError.self) {
            try schema.validate(content: content)
        }
    }

    @Test
    func validate_extraFieldsAllowed_succeeds() throws {
        let schema = try RecordSchema(
            id: "test",
            displayName: "Test",
            iconSystemName: "star",
            fields: [
                FieldDefinition(
                    id: "name",
                    displayName: "Name",
                    fieldType: .string,
                    isRequired: true
                )
            ]
        )

        var content = RecordContent()
        content.setString("name", "John")
        content.setInt("extraField", 42) // Not in schema, but allowed

        try schema.validate(content: content)
    }

    @Test
    func validate_wrongFieldType_throwsError() throws {
        let schema = try RecordSchema(
            id: "test",
            displayName: "Test",
            iconSystemName: "star",
            fields: [
                FieldDefinition(
                    id: "age",
                    displayName: "Age",
                    fieldType: .int,
                    isRequired: true
                )
            ]
        )

        var content = RecordContent()
        content.setString("age", "42") // Wrong type

        #expect(throws: ModelError.self) {
            try schema.validate(content: content)
        }
    }

    @Test
    func isValid_validContent_returnsTrue() throws {
        let schema = try RecordSchema(
            id: "test",
            displayName: "Test",
            iconSystemName: "star",
            fields: [
                FieldDefinition(
                    id: "name",
                    displayName: "Name",
                    fieldType: .string,
                    isRequired: true
                )
            ]
        )

        var content = RecordContent()
        content.setString("name", "John")

        #expect(schema.isValid(content: content))
    }

    @Test
    func isValid_invalidContent_returnsFalse() throws {
        let schema = try RecordSchema(
            id: "test",
            displayName: "Test",
            iconSystemName: "star",
            fields: [
                FieldDefinition(
                    id: "name",
                    displayName: "Name",
                    fieldType: .string,
                    isRequired: true
                )
            ]
        )

        let content = RecordContent() // Missing required field

        #expect(!schema.isValid(content: content))
    }
}
