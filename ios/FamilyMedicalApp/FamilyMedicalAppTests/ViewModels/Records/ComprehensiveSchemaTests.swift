import Foundation
import Testing
@testable import FamilyMedicalApp

/// Tests for comprehensive schema exercising all field types
@MainActor
struct ComprehensiveSchemaTests {
    // MARK: - Test Helpers

    private func makeTestPerson() throws -> Person {
        try PersonTestHelper.makeTestPerson(labels: ["Test"])
    }

    // MARK: - Schema Validation Tests

    @Test
    func comprehensiveSchemaHasAllFieldTypes() {
        let schema = ExampleSchema.comprehensiveExample

        // Verify schema has all 7 field types
        let fieldTypes = Set(schema.fields.map(\.fieldType))
        #expect(fieldTypes.contains(.string))
        #expect(fieldTypes.contains(.int))
        #expect(fieldTypes.contains(.double))
        #expect(fieldTypes.contains(.bool))
        #expect(fieldTypes.contains(.date))
        #expect(fieldTypes.contains(.stringArray))
        #expect(fieldTypes.contains(.attachmentIds))
    }

    @Test
    func comprehensiveSchemaValidatesAllRequiredFields() throws {
        let schema = ExampleSchema.comprehensiveExample
        var content = RecordContent(schemaId: schema.id)

        // Missing required fields should fail validation
        #expect(throws: ModelError.self) {
            try schema.validate(content: content)
        }

        // Add required string field
        content.setString(ExampleSchema.FieldIds.exampleName, "Test Example")

        // Still missing required date field
        #expect(throws: ModelError.self) {
            try schema.validate(content: content)
        }

        // Add required date field
        content.setDate(ExampleSchema.FieldIds.recordedDate, Date())

        // Should now pass validation
        #expect(throws: Never.self) {
            try schema.validate(content: content)
        }
    }

    @Test
    func comprehensiveSchemaValidatesIntegerRange() throws {
        let schema = ExampleSchema.comprehensiveExample
        var content = RecordContent(schemaId: schema.id)

        // Add required fields
        content.setString(ExampleSchema.FieldIds.exampleName, "Test")
        content.setDate(ExampleSchema.FieldIds.recordedDate, Date())

        // Test integer within valid range (0-1000)
        content.setInt(ExampleSchema.FieldIds.quantity, 500)
        #expect(throws: Never.self) {
            try schema.validate(content: content)
        }

        // Test integer at minimum boundary
        content.setInt(ExampleSchema.FieldIds.quantity, 0)
        #expect(throws: Never.self) {
            try schema.validate(content: content)
        }

        // Test integer at maximum boundary
        content.setInt(ExampleSchema.FieldIds.quantity, 1_000)
        #expect(throws: Never.self) {
            try schema.validate(content: content)
        }

        // Test integer below minimum
        content.setInt(ExampleSchema.FieldIds.quantity, -1)
        #expect(throws: ModelError.self) {
            try schema.validate(content: content)
        }

        // Test integer above maximum
        content.setInt(ExampleSchema.FieldIds.quantity, 1_001)
        #expect(throws: ModelError.self) {
            try schema.validate(content: content)
        }
    }

    @Test
    func comprehensiveSchemaValidatesDoubleRange() throws {
        let schema = ExampleSchema.comprehensiveExample
        var content = RecordContent(schemaId: schema.id)

        // Add required fields
        content.setString(ExampleSchema.FieldIds.exampleName, "Test")
        content.setDate(ExampleSchema.FieldIds.recordedDate, Date())

        // Test double within valid range (0.0-100.0)
        content.setDouble(ExampleSchema.FieldIds.measurement, 50.5)
        #expect(throws: Never.self) {
            try schema.validate(content: content)
        }

        // Test double at minimum boundary
        content.setDouble(ExampleSchema.FieldIds.measurement, 0.0)
        #expect(throws: Never.self) {
            try schema.validate(content: content)
        }

        // Test double at maximum boundary
        content.setDouble(ExampleSchema.FieldIds.measurement, 100.0)
        #expect(throws: Never.self) {
            try schema.validate(content: content)
        }

        // Test double below minimum
        content.setDouble(ExampleSchema.FieldIds.measurement, -0.1)
        #expect(throws: ModelError.self) {
            try schema.validate(content: content)
        }

        // Test double above maximum
        content.setDouble(ExampleSchema.FieldIds.measurement, 100.1)
        #expect(throws: ModelError.self) {
            try schema.validate(content: content)
        }
    }

    @Test
    func comprehensiveSchemaHandlesBooleanValues() throws {
        let schema = ExampleSchema.comprehensiveExample
        var content = RecordContent(schemaId: schema.id)

        // Add required fields
        content.setString(ExampleSchema.FieldIds.exampleName, "Test")
        content.setDate(ExampleSchema.FieldIds.recordedDate, Date())

        // Test boolean true
        content.setBool(ExampleSchema.FieldIds.isActive, true)
        #expect(throws: Never.self) {
            try schema.validate(content: content)
        }
        #expect(content.getBool(ExampleSchema.FieldIds.isActive) == true)

        // Test boolean false
        content.setBool(ExampleSchema.FieldIds.isActive, false)
        #expect(throws: Never.self) {
            try schema.validate(content: content)
        }
        #expect(content.getBool(ExampleSchema.FieldIds.isActive) == false)
    }

    @Test
    func comprehensiveSchemaHandlesStringArrays() throws {
        let schema = ExampleSchema.comprehensiveExample
        var content = RecordContent(schemaId: schema.id)

        // Add required fields
        content.setString(ExampleSchema.FieldIds.exampleName, "Test")
        content.setDate(ExampleSchema.FieldIds.recordedDate, Date())

        // Test string array
        content.setStringArray(ExampleSchema.FieldIds.tags, ["tag1", "tag2", "tag3"])
        #expect(throws: Never.self) {
            try schema.validate(content: content)
        }
        #expect(content.getStringArray(ExampleSchema.FieldIds.tags) == ["tag1", "tag2", "tag3"])

        // Test empty string array
        content.setStringArray(ExampleSchema.FieldIds.tags, [])
        #expect(throws: Never.self) {
            try schema.validate(content: content)
        }
        #expect(content.getStringArray(ExampleSchema.FieldIds.tags)?.isEmpty == true)
    }

    @Test
    func comprehensiveSchemaHandlesAttachmentIds() throws {
        let schema = ExampleSchema.comprehensiveExample
        var content = RecordContent(schemaId: schema.id)

        // Add required fields
        content.setString(ExampleSchema.FieldIds.exampleName, "Test")
        content.setDate(ExampleSchema.FieldIds.recordedDate, Date())

        // Test attachment IDs
        let attachmentIds = [UUID(), UUID()]
        content.setAttachmentIds(ExampleSchema.FieldIds.attachmentIds, attachmentIds)
        #expect(throws: Never.self) {
            try schema.validate(content: content)
        }
        #expect(content.getAttachmentIds(ExampleSchema.FieldIds.attachmentIds) == attachmentIds)

        // Test empty attachment IDs
        content.setAttachmentIds(ExampleSchema.FieldIds.attachmentIds, [])
        #expect(throws: Never.self) {
            try schema.validate(content: content)
        }
        #expect(content.getAttachmentIds(ExampleSchema.FieldIds.attachmentIds)?.isEmpty == true)
    }

    @Test
    func comprehensiveSchemaHandlesOptionalFields() throws {
        let schema = ExampleSchema.comprehensiveExample
        var content = RecordContent(schemaId: schema.id)

        // Add only required fields
        content.setString(ExampleSchema.FieldIds.exampleName, "Test")
        content.setDate(ExampleSchema.FieldIds.recordedDate, Date())

        // Should pass validation without optional fields
        #expect(throws: Never.self) {
            try schema.validate(content: content)
        }

        // Verify optional fields are not set
        #expect(content.getInt(ExampleSchema.FieldIds.quantity) == nil)
        #expect(content.getDouble(ExampleSchema.FieldIds.measurement) == nil)
        #expect(content.getBool(ExampleSchema.FieldIds.isActive) == nil)
        #expect(content.getStringArray(ExampleSchema.FieldIds.tags) == nil)
        #expect(content.getAttachmentIds(ExampleSchema.FieldIds.attachmentIds) == nil)
        #expect(content.getString(ExampleSchema.FieldIds.notes) == nil)
    }

    @Test
    func comprehensiveSchemaValidatesStringLength() throws {
        let schema = ExampleSchema.comprehensiveExample
        var content = RecordContent(schemaId: schema.id)

        // Add required date field
        content.setDate(ExampleSchema.FieldIds.recordedDate, Date())

        // Test string below minimum length (empty string)
        content.setString(ExampleSchema.FieldIds.exampleName, "")
        #expect(throws: ModelError.self) {
            try schema.validate(content: content)
        }

        // Test string at minimum length (1 character)
        content.setString(ExampleSchema.FieldIds.exampleName, "A")
        #expect(throws: Never.self) {
            try schema.validate(content: content)
        }

        // Test string at maximum length (100 characters)
        content.setString(ExampleSchema.FieldIds.exampleName, String(repeating: "A", count: 100))
        #expect(throws: Never.self) {
            try schema.validate(content: content)
        }

        // Test string above maximum length (101 characters)
        content.setString(ExampleSchema.FieldIds.exampleName, String(repeating: "A", count: 101))
        #expect(throws: ModelError.self) {
            try schema.validate(content: content)
        }
    }

    @Test
    func comprehensiveSchemaValidatesOptionalNotesLength() throws {
        let schema = ExampleSchema.comprehensiveExample
        var content = RecordContent(schemaId: schema.id)

        // Add required fields
        content.setString(ExampleSchema.FieldIds.exampleName, "Test")
        content.setDate(ExampleSchema.FieldIds.recordedDate, Date())

        // Test notes at maximum length (500 characters)
        content.setString(ExampleSchema.FieldIds.notes, String(repeating: "A", count: 500))
        #expect(throws: Never.self) {
            try schema.validate(content: content)
        }

        // Test notes above maximum length (501 characters)
        content.setString(ExampleSchema.FieldIds.notes, String(repeating: "A", count: 501))
        #expect(throws: ModelError.self) {
            try schema.validate(content: content)
        }
    }

    @Test
    func comprehensiveSchemaAllowsAllFieldTypesTogether() throws {
        let schema = ExampleSchema.comprehensiveExample
        var content = RecordContent(schemaId: schema.id)

        // Set all fields with valid values
        content.setString(ExampleSchema.FieldIds.exampleName, "Complete Example")
        content.setInt(ExampleSchema.FieldIds.quantity, 42)
        content.setDouble(ExampleSchema.FieldIds.measurement, 98.6)
        content.setBool(ExampleSchema.FieldIds.isActive, true)
        content.setDate(ExampleSchema.FieldIds.recordedDate, Date())
        content.setStringArray(ExampleSchema.FieldIds.tags, ["important", "test", "comprehensive"])
        content.setAttachmentIds(ExampleSchema.FieldIds.attachmentIds, [UUID(), UUID()])
        content.setString(ExampleSchema.FieldIds.notes, "All field types are populated")

        // Should pass validation with all fields set
        #expect(throws: Never.self) {
            try schema.validate(content: content)
        }

        // Verify all values are retrievable
        #expect(content.getString(ExampleSchema.FieldIds.exampleName) == "Complete Example")
        #expect(content.getInt(ExampleSchema.FieldIds.quantity) == 42)
        #expect(content.getDouble(ExampleSchema.FieldIds.measurement) == 98.6)
        #expect(content.getBool(ExampleSchema.FieldIds.isActive) == true)
        #expect(content.getDate(ExampleSchema.FieldIds.recordedDate) != nil)
        #expect(content.getStringArray(ExampleSchema.FieldIds.tags) == ["important", "test", "comprehensive"])
        #expect(content.getAttachmentIds(ExampleSchema.FieldIds.attachmentIds)?.count == 2)
        #expect(content.getString(ExampleSchema.FieldIds.notes) == "All field types are populated")
    }
}
