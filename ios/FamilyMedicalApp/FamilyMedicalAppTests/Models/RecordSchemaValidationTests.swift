import Foundation
import Testing
@testable import FamilyMedicalApp

struct RecordSchemaValidationTests {
    // MARK: - Test Field IDs

    // Stable UUIDs for consistent field identity across tests
    // swiftlint:disable force_unwrapping
    private static let nameFieldId = UUID(uuidString: "55555555-0001-0001-0000-000000000001")!
    private static let ageFieldId = UUID(uuidString: "55555555-0001-0002-0000-000000000001")!
    private static let extraFieldId = UUID(uuidString: "55555555-0001-0003-0000-000000000001")!
    // swiftlint:enable force_unwrapping

    // MARK: - Validation

    @Test
    func validate_allRequiredFieldsPresent_succeeds() throws {
        let schema = try RecordSchema(
            id: "test",
            displayName: "Test",
            iconSystemName: "star",
            fields: [
                .builtIn(
                    id: Self.nameFieldId,
                    displayName: "Name",
                    fieldType: .string,
                    isRequired: true
                )
            ]
        )

        var content = RecordContent()
        content.setString(Self.nameFieldId, "John")

        try schema.validate(content: content)
    }

    @Test
    func validate_missingRequiredField_throwsError() throws {
        let schema = try RecordSchema(
            id: "test",
            displayName: "Test",
            iconSystemName: "star",
            fields: [
                .builtIn(
                    id: Self.nameFieldId,
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
                .builtIn(
                    id: Self.nameFieldId,
                    displayName: "Name",
                    fieldType: .string,
                    isRequired: true
                )
            ]
        )

        var content = RecordContent()
        content.setString(Self.nameFieldId, "John")
        content.setInt(Self.extraFieldId, 42) // Not in schema, but allowed

        try schema.validate(content: content)
    }

    @Test
    func validate_wrongFieldType_throwsError() throws {
        let schema = try RecordSchema(
            id: "test",
            displayName: "Test",
            iconSystemName: "star",
            fields: [
                .builtIn(
                    id: Self.ageFieldId,
                    displayName: "Age",
                    fieldType: .int,
                    isRequired: true
                )
            ]
        )

        var content = RecordContent()
        content.setString(Self.ageFieldId, "42") // Wrong type

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
                .builtIn(
                    id: Self.nameFieldId,
                    displayName: "Name",
                    fieldType: .string,
                    isRequired: true
                )
            ]
        )

        var content = RecordContent()
        content.setString(Self.nameFieldId, "John")

        #expect(schema.isValid(content: content))
    }

    @Test
    func isValid_invalidContent_returnsFalse() throws {
        let schema = try RecordSchema(
            id: "test",
            displayName: "Test",
            iconSystemName: "star",
            fields: [
                .builtIn(
                    id: Self.nameFieldId,
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
