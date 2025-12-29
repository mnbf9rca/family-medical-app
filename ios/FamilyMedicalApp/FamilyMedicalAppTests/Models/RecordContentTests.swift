import Foundation
import Testing
@testable import FamilyMedicalApp

struct RecordContentTests {
    // MARK: - Initialization

    @Test
    func init_empty_succeeds() {
        let content = RecordContent()
        #expect(content.allFields.isEmpty)
        #expect(content.fieldKeys.isEmpty)
    }

    @Test
    func init_withFields_succeeds() {
        let content = RecordContent(fields: ["name": .string("test")])
        #expect(content.allFields.count == 1)
        #expect(content.getString("name") == "test")
    }

    // MARK: - Subscript Access

    @Test
    func subscript_getExistingField_returnsValue() {
        var content = RecordContent()
        content["test"] = .string("value")
        #expect(content["test"]?.stringValue == "value")
    }

    @Test
    func subscript_getNonExistentField_returnsNil() {
        let content = RecordContent()
        #expect(content["nonexistent"] == nil)
    }

    @Test
    func subscript_setField_storesValue() {
        var content = RecordContent()
        content["key"] = .int(42)
        #expect(content["key"]?.intValue == 42)
    }

    // MARK: - Field Management

    @Test
    func hasField_existingField_returnsTrue() {
        var content = RecordContent()
        content["test"] = .string("value")
        #expect(content.hasField("test"))
    }

    @Test
    func hasField_nonExistentField_returnsFalse() {
        let content = RecordContent()
        #expect(!content.hasField("test"))
    }

    @Test
    func removeField_existingField_removes() {
        var content = RecordContent()
        content["test"] = .string("value")
        content.removeField("test")
        #expect(!content.hasField("test"))
    }

    @Test
    func removeAllFields_clearsAll() {
        var content = RecordContent(fields: [
            "field1": .string("value1"),
            "field2": .int(42)
        ])
        content.removeAllFields()
        #expect(content.allFields.isEmpty)
    }

    // MARK: - Convenience Getters

    @Test
    func getString_stringField_returnsValue() {
        var content = RecordContent()
        content["name"] = .string("John")
        #expect(content.getString("name") == "John")
    }

    @Test
    func getString_nonStringField_returnsNil() {
        var content = RecordContent()
        content["age"] = .int(42)
        #expect(content.getString("age") == nil)
    }

    @Test
    func getInt_intField_returnsValue() {
        var content = RecordContent()
        content["age"] = .int(42)
        #expect(content.getInt("age") == 42)
    }

    @Test
    func getDouble_doubleField_returnsValue() {
        var content = RecordContent()
        content["price"] = .double(3.14)
        #expect(content.getDouble("price") == 3.14)
    }

    @Test
    func getBool_boolField_returnsValue() {
        var content = RecordContent()
        content["active"] = .bool(true)
        #expect(content.getBool("active") == true)
    }

    @Test
    func getDate_dateField_returnsValue() {
        var content = RecordContent()
        let date = Date()
        content["created"] = .date(date)
        #expect(content.getDate("created") == date)
    }

    @Test
    func getAttachmentIds_attachmentIdsField_returnsValue() {
        var content = RecordContent()
        let ids = [UUID(), UUID()]
        content["attachments"] = .attachmentIds(ids)
        #expect(content.getAttachmentIds("attachments") == ids)
    }

    @Test
    func getStringArray_stringArrayField_returnsValue() {
        var content = RecordContent()
        let tags = ["tag1", "tag2"]
        content["tags"] = .stringArray(tags)
        #expect(content.getStringArray("tags") == tags)
    }

    // MARK: - Convenience Setters

    @Test
    func setString_setsStringValue() {
        var content = RecordContent()
        content.setString("name", "John")
        #expect(content.getString("name") == "John")
    }

    @Test
    func setInt_setsIntValue() {
        var content = RecordContent()
        content.setInt("age", 42)
        #expect(content.getInt("age") == 42)
    }

    @Test
    func setDouble_setsDoubleValue() {
        var content = RecordContent()
        content.setDouble("price", 3.14)
        #expect(content.getDouble("price") == 3.14)
    }

    @Test
    func setBool_setsBoolValue() {
        var content = RecordContent()
        content.setBool("active", true)
        #expect(content.getBool("active") == true)
    }

    @Test
    func setDate_setsDateValue() {
        var content = RecordContent()
        let date = Date()
        content.setDate("created", date)
        #expect(content.getDate("created") == date)
    }

    @Test
    func setAttachmentIds_setsAttachmentIdsValue() {
        var content = RecordContent()
        let ids = [UUID(), UUID()]
        content.setAttachmentIds("attachments", ids)
        #expect(content.getAttachmentIds("attachments") == ids)
    }

    @Test
    func setStringArray_setsStringArrayValue() {
        var content = RecordContent()
        let tags = ["tag1", "tag2"]
        content.setStringArray("tags", tags)
        #expect(content.getStringArray("tags") == tags)
    }

    // MARK: - Codable

    @Test
    func codable_roundTrip() throws {
        var original = RecordContent()
        original.setString("name", "John Doe")
        original.setInt("age", 42)
        original.setDate("created", Date(timeIntervalSince1970: 1_000_000))

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RecordContent.self, from: encoded)

        #expect(decoded == original)
        #expect(decoded.getString("name") == "John Doe")
        #expect(decoded.getInt("age") == 42)
    }

    // MARK: - Equatable

    @Test
    func equatable_sameFields_equal() {
        var content1 = RecordContent()
        content1.setString("name", "John")

        var content2 = RecordContent()
        content2.setString("name", "John")

        #expect(content1 == content2)
    }

    @Test
    func equatable_differentFields_notEqual() {
        var content1 = RecordContent()
        content1.setString("name", "John")

        var content2 = RecordContent()
        content2.setString("name", "Jane")

        #expect(content1 != content2)
    }
}
