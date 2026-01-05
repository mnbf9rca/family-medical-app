import Foundation
import Testing
@testable import FamilyMedicalApp

struct RecordContentTests {
    // MARK: - Test Field IDs

    /// Test UUIDs for field identification
    private enum TestFieldIds {
        static let name = UUID()
        static let age = UUID()
        static let price = UUID()
        static let active = UUID()
        static let created = UUID()
        static let attachments = UUID()
        static let tags = UUID()
        static let field1 = UUID()
        static let field2 = UUID()
        static let test = UUID()
    }

    // MARK: - Initialization

    @Test
    func init_empty_succeeds() {
        let content = RecordContent()
        #expect(content.allFields.isEmpty)
        #expect(content.fieldKeys.isEmpty)
        #expect(content.schemaId == nil)
    }

    @Test
    func init_withFields_succeeds() {
        let content = RecordContent(fields: [TestFieldIds.name.uuidString: .string("test")])
        #expect(content.allFields.count == 1)
        #expect(content.getString(TestFieldIds.name) == "test")
        #expect(content.schemaId == nil)
    }

    @Test
    func init_withSchemaId_storesSchemaId() {
        let content = RecordContent(schemaId: "vaccine")
        #expect(content.schemaId == "vaccine")
        #expect(content.allFields.isEmpty)
    }

    @Test
    func init_withSchemaIdAndFields_storesBoth() {
        let content = RecordContent(
            schemaId: "medication",
            fields: [TestFieldIds.name.uuidString: .string("Aspirin")]
        )
        #expect(content.schemaId == "medication")
        #expect(content.getString(TestFieldIds.name) == "Aspirin")
    }

    // MARK: - Subscript Access

    @Test
    func subscript_getExistingField_returnsValue() {
        var content = RecordContent()
        content[TestFieldIds.test] = .string("value")
        #expect(content[TestFieldIds.test]?.stringValue == "value")
    }

    @Test
    func subscript_getNonExistentField_returnsNil() {
        let content = RecordContent()
        #expect(content[UUID()] == nil)
    }

    @Test
    func subscript_setField_storesValue() {
        var content = RecordContent()
        content[TestFieldIds.age] = .int(42)
        #expect(content[TestFieldIds.age]?.intValue == 42)
    }

    // MARK: - Field Management

    @Test
    func hasField_existingField_returnsTrue() {
        var content = RecordContent()
        content[TestFieldIds.test] = .string("value")
        #expect(content.hasField(TestFieldIds.test))
    }

    @Test
    func hasField_nonExistentField_returnsFalse() {
        let content = RecordContent()
        #expect(!content.hasField(TestFieldIds.test))
    }

    @Test
    func removeField_existingField_removes() {
        var content = RecordContent()
        content[TestFieldIds.test] = .string("value")
        content.removeField(TestFieldIds.test)
        #expect(!content.hasField(TestFieldIds.test))
    }

    @Test
    func removeAllFields_clearsAll() {
        var content = RecordContent(fields: [
            TestFieldIds.field1.uuidString: .string("value1"),
            TestFieldIds.field2.uuidString: .int(42)
        ])
        content.removeAllFields()
        #expect(content.allFields.isEmpty)
    }

    // MARK: - Convenience Getters

    @Test
    func getString_stringField_returnsValue() {
        var content = RecordContent()
        content[TestFieldIds.name] = .string("John")
        #expect(content.getString(TestFieldIds.name) == "John")
    }

    @Test
    func getString_nonStringField_returnsNil() {
        var content = RecordContent()
        content[TestFieldIds.age] = .int(42)
        #expect(content.getString(TestFieldIds.age) == nil)
    }

    @Test
    func getInt_intField_returnsValue() {
        var content = RecordContent()
        content[TestFieldIds.age] = .int(42)
        #expect(content.getInt(TestFieldIds.age) == 42)
    }

    @Test
    func getDouble_doubleField_returnsValue() {
        var content = RecordContent()
        content[TestFieldIds.price] = .double(3.14)
        #expect(content.getDouble(TestFieldIds.price) == 3.14)
    }

    @Test
    func getBool_boolField_returnsValue() {
        var content = RecordContent()
        content[TestFieldIds.active] = .bool(true)
        #expect(content.getBool(TestFieldIds.active) == true)
    }

    @Test
    func getDate_dateField_returnsValue() {
        var content = RecordContent()
        let date = Date()
        content[TestFieldIds.created] = .date(date)
        #expect(content.getDate(TestFieldIds.created) == date)
    }

    @Test
    func getAttachmentIds_attachmentIdsField_returnsValue() {
        var content = RecordContent()
        let ids = [UUID(), UUID()]
        content[TestFieldIds.attachments] = .attachmentIds(ids)
        #expect(content.getAttachmentIds(TestFieldIds.attachments) == ids)
    }

    @Test
    func getStringArray_stringArrayField_returnsValue() {
        var content = RecordContent()
        let tags = ["tag1", "tag2"]
        content[TestFieldIds.tags] = .stringArray(tags)
        #expect(content.getStringArray(TestFieldIds.tags) == tags)
    }

    // MARK: - Convenience Setters

    @Test
    func setString_setsStringValue() {
        var content = RecordContent()
        content.setString(TestFieldIds.name, "John")
        #expect(content.getString(TestFieldIds.name) == "John")
    }

    @Test
    func setInt_setsIntValue() {
        var content = RecordContent()
        content.setInt(TestFieldIds.age, 42)
        #expect(content.getInt(TestFieldIds.age) == 42)
    }

    @Test
    func setDouble_setsDoubleValue() {
        var content = RecordContent()
        content.setDouble(TestFieldIds.price, 3.14)
        #expect(content.getDouble(TestFieldIds.price) == 3.14)
    }

    @Test
    func setBool_setsBoolValue() {
        var content = RecordContent()
        content.setBool(TestFieldIds.active, true)
        #expect(content.getBool(TestFieldIds.active) == true)
    }

    @Test
    func setDate_setsDateValue() {
        var content = RecordContent()
        let date = Date()
        content.setDate(TestFieldIds.created, date)
        #expect(content.getDate(TestFieldIds.created) == date)
    }

    @Test
    func setAttachmentIds_setsAttachmentIdsValue() {
        var content = RecordContent()
        let ids = [UUID(), UUID()]
        content.setAttachmentIds(TestFieldIds.attachments, ids)
        #expect(content.getAttachmentIds(TestFieldIds.attachments) == ids)
    }

    @Test
    func setStringArray_setsStringArrayValue() {
        var content = RecordContent()
        let tags = ["tag1", "tag2"]
        content.setStringArray(TestFieldIds.tags, tags)
        #expect(content.getStringArray(TestFieldIds.tags) == tags)
    }

    // MARK: - Codable

    @Test
    func codable_roundTrip() throws {
        var original = RecordContent(schemaId: "vaccine")
        original.setString(TestFieldIds.name, "John Doe")
        original.setInt(TestFieldIds.age, 42)
        original.setDate(TestFieldIds.created, Date(timeIntervalSince1970: 1_000_000))

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RecordContent.self, from: encoded)

        #expect(decoded == original)
        #expect(decoded.schemaId == "vaccine")
        #expect(decoded.getString(TestFieldIds.name) == "John Doe")
        #expect(decoded.getInt(TestFieldIds.age) == 42)
    }

    // MARK: - Equatable

    @Test
    func equatable_sameFields_equal() {
        var content1 = RecordContent(schemaId: "test")
        content1.setString(TestFieldIds.name, "John")

        var content2 = RecordContent(schemaId: "test")
        content2.setString(TestFieldIds.name, "John")

        #expect(content1 == content2)
    }

    @Test
    func equatable_differentFields_notEqual() {
        var content1 = RecordContent()
        content1.setString(TestFieldIds.name, "John")

        var content2 = RecordContent()
        content2.setString(TestFieldIds.name, "Jane")

        #expect(content1 != content2)
    }

    @Test
    func equatable_differentSchemaId_notEqual() {
        var content1 = RecordContent(schemaId: "vaccine")
        content1.setString(TestFieldIds.name, "Test")

        var content2 = RecordContent(schemaId: "medication")
        content2.setString(TestFieldIds.name, "Test")

        #expect(content1 != content2)
    }
}
