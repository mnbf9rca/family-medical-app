import Foundation
import Testing
@testable import FamilyMedicalApp

/// Tests for comprehensive schema exercising all field types
@MainActor
struct ComprehensiveSchemaTests {
    // MARK: - Test Helpers

    private func makeTestPerson() throws -> Person {
        try Person(
            id: UUID(),
            name: "Test Person",
            dateOfBirth: Date(),
            labels: ["Test"],
            notes: nil
        )
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
        content.setString("exampleName", "Test Example")

        // Still missing required date field
        #expect(throws: ModelError.self) {
            try schema.validate(content: content)
        }

        // Add required date field
        content.setDate("recordedDate", Date())

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
        content.setString("exampleName", "Test")
        content.setDate("recordedDate", Date())

        // Test integer within valid range (0-1000)
        content.setInt("quantity", 500)
        #expect(throws: Never.self) {
            try schema.validate(content: content)
        }

        // Test integer at minimum boundary
        content.setInt("quantity", 0)
        #expect(throws: Never.self) {
            try schema.validate(content: content)
        }

        // Test integer at maximum boundary
        content.setInt("quantity", 1_000)
        #expect(throws: Never.self) {
            try schema.validate(content: content)
        }

        // Test integer below minimum
        content.setInt("quantity", -1)
        #expect(throws: ModelError.self) {
            try schema.validate(content: content)
        }

        // Test integer above maximum
        content.setInt("quantity", 1_001)
        #expect(throws: ModelError.self) {
            try schema.validate(content: content)
        }
    }

    @Test
    func comprehensiveSchemaValidatesDoubleRange() throws {
        let schema = ExampleSchema.comprehensiveExample
        var content = RecordContent(schemaId: schema.id)

        // Add required fields
        content.setString("exampleName", "Test")
        content.setDate("recordedDate", Date())

        // Test double within valid range (0.0-100.0)
        content.setDouble("measurement", 50.5)
        #expect(throws: Never.self) {
            try schema.validate(content: content)
        }

        // Test double at minimum boundary
        content.setDouble("measurement", 0.0)
        #expect(throws: Never.self) {
            try schema.validate(content: content)
        }

        // Test double at maximum boundary
        content.setDouble("measurement", 100.0)
        #expect(throws: Never.self) {
            try schema.validate(content: content)
        }

        // Test double below minimum
        content.setDouble("measurement", -0.1)
        #expect(throws: ModelError.self) {
            try schema.validate(content: content)
        }

        // Test double above maximum
        content.setDouble("measurement", 100.1)
        #expect(throws: ModelError.self) {
            try schema.validate(content: content)
        }
    }

    @Test
    func comprehensiveSchemaHandlesBooleanValues() throws {
        let schema = ExampleSchema.comprehensiveExample
        var content = RecordContent(schemaId: schema.id)

        // Add required fields
        content.setString("exampleName", "Test")
        content.setDate("recordedDate", Date())

        // Test boolean true
        content.setBool("isActive", true)
        #expect(throws: Never.self) {
            try schema.validate(content: content)
        }
        #expect(content.getBool("isActive") == true)

        // Test boolean false
        content.setBool("isActive", false)
        #expect(throws: Never.self) {
            try schema.validate(content: content)
        }
        #expect(content.getBool("isActive") == false)
    }

    @Test
    func comprehensiveSchemaHandlesStringArrays() throws {
        let schema = ExampleSchema.comprehensiveExample
        var content = RecordContent(schemaId: schema.id)

        // Add required fields
        content.setString("exampleName", "Test")
        content.setDate("recordedDate", Date())

        // Test string array
        content.setStringArray("tags", ["tag1", "tag2", "tag3"])
        #expect(throws: Never.self) {
            try schema.validate(content: content)
        }
        #expect(content.getStringArray("tags") == ["tag1", "tag2", "tag3"])

        // Test empty string array
        content.setStringArray("tags", [])
        #expect(throws: Never.self) {
            try schema.validate(content: content)
        }
        #expect(content.getStringArray("tags")?.isEmpty == true)
    }

    @Test
    func comprehensiveSchemaHandlesAttachmentIds() throws {
        let schema = ExampleSchema.comprehensiveExample
        var content = RecordContent(schemaId: schema.id)

        // Add required fields
        content.setString("exampleName", "Test")
        content.setDate("recordedDate", Date())

        // Test attachment IDs
        let attachmentIds = [UUID(), UUID()]
        content.setAttachmentIds("attachmentIds", attachmentIds)
        #expect(throws: Never.self) {
            try schema.validate(content: content)
        }
        #expect(content.getAttachmentIds("attachmentIds") == attachmentIds)

        // Test empty attachment IDs
        content.setAttachmentIds("attachmentIds", [])
        #expect(throws: Never.self) {
            try schema.validate(content: content)
        }
        #expect(content.getAttachmentIds("attachmentIds")?.isEmpty == true)
    }

    @Test
    func comprehensiveSchemaHandlesOptionalFields() throws {
        let schema = ExampleSchema.comprehensiveExample
        var content = RecordContent(schemaId: schema.id)

        // Add only required fields
        content.setString("exampleName", "Test")
        content.setDate("recordedDate", Date())

        // Should pass validation without optional fields
        #expect(throws: Never.self) {
            try schema.validate(content: content)
        }

        // Verify optional fields are not set
        #expect(content.getInt("quantity") == nil)
        #expect(content.getDouble("measurement") == nil)
        #expect(content.getBool("isActive") == nil)
        #expect(content.getStringArray("tags") == nil)
        #expect(content.getAttachmentIds("attachmentIds") == nil)
        #expect(content.getString("notes") == nil)
    }

    @Test
    func comprehensiveSchemaValidatesStringLength() throws {
        let schema = ExampleSchema.comprehensiveExample
        var content = RecordContent(schemaId: schema.id)

        // Add required date field
        content.setDate("recordedDate", Date())

        // Test string below minimum length (empty string)
        content.setString("exampleName", "")
        #expect(throws: ModelError.self) {
            try schema.validate(content: content)
        }

        // Test string at minimum length (1 character)
        content.setString("exampleName", "A")
        #expect(throws: Never.self) {
            try schema.validate(content: content)
        }

        // Test string at maximum length (100 characters)
        content.setString("exampleName", String(repeating: "A", count: 100))
        #expect(throws: Never.self) {
            try schema.validate(content: content)
        }

        // Test string above maximum length (101 characters)
        content.setString("exampleName", String(repeating: "A", count: 101))
        #expect(throws: ModelError.self) {
            try schema.validate(content: content)
        }
    }

    @Test
    func comprehensiveSchemaValidatesOptionalNotesLength() throws {
        let schema = ExampleSchema.comprehensiveExample
        var content = RecordContent(schemaId: schema.id)

        // Add required fields
        content.setString("exampleName", "Test")
        content.setDate("recordedDate", Date())

        // Test notes at maximum length (500 characters)
        content.setString("notes", String(repeating: "A", count: 500))
        #expect(throws: Never.self) {
            try schema.validate(content: content)
        }

        // Test notes above maximum length (501 characters)
        content.setString("notes", String(repeating: "A", count: 501))
        #expect(throws: ModelError.self) {
            try schema.validate(content: content)
        }
    }

    @Test
    func comprehensiveSchemaAllowsAllFieldTypesTogether() throws {
        let schema = ExampleSchema.comprehensiveExample
        var content = RecordContent(schemaId: schema.id)

        // Set all fields with valid values
        content.setString("exampleName", "Complete Example")
        content.setInt("quantity", 42)
        content.setDouble("measurement", 98.6)
        content.setBool("isActive", true)
        content.setDate("recordedDate", Date())
        content.setStringArray("tags", ["important", "test", "comprehensive"])
        content.setAttachmentIds("attachmentIds", [UUID(), UUID()])
        content.setString("notes", "All field types are populated")

        // Should pass validation with all fields set
        #expect(throws: Never.self) {
            try schema.validate(content: content)
        }

        // Verify all values are retrievable
        #expect(content.getString("exampleName") == "Complete Example")
        #expect(content.getInt("quantity") == 42)
        #expect(content.getDouble("measurement") == 98.6)
        #expect(content.getBool("isActive") == true)
        #expect(content.getDate("recordedDate") != nil)
        #expect(content.getStringArray("tags") == ["important", "test", "comprehensive"])
        #expect(content.getAttachmentIds("attachmentIds")?.count == 2)
        #expect(content.getString("notes") == "All field types are populated")
    }
}
