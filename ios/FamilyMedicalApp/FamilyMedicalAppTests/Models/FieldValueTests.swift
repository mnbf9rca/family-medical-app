import Foundation
import Testing
@testable import FamilyMedicalApp

struct FieldValueTests {
    // MARK: - String Tests

    @Test
    func stringValue_returnsString() {
        let value = FieldValue.string("test")
        #expect(value.stringValue == "test")
        #expect(value.typeName == "string")
    }

    @Test
    func stringValue_otherTypesReturnNil() {
        #expect(FieldValue.int(42).stringValue == nil)
        #expect(FieldValue.bool(true).stringValue == nil)
    }

    // MARK: - Int Tests

    @Test
    func intValue_returnsInt() {
        let value = FieldValue.int(42)
        #expect(value.intValue == 42)
        #expect(value.typeName == "int")
    }

    @Test
    func intValue_otherTypesReturnNil() {
        #expect(FieldValue.string("test").intValue == nil)
        #expect(FieldValue.double(3.14).intValue == nil)
    }

    // MARK: - Double Tests

    @Test
    func doubleValue_returnsDouble() {
        let value = FieldValue.double(3.14)
        #expect(value.doubleValue == 3.14)
        #expect(value.typeName == "double")
    }

    // MARK: - Bool Tests

    @Test
    func boolValue_returnsBool() {
        let value = FieldValue.bool(true)
        #expect(value.boolValue == true)
        #expect(value.typeName == "bool")
    }

    // MARK: - Date Tests

    @Test
    func dateValue_returnsDate() {
        let date = Date()
        let value = FieldValue.date(date)
        #expect(value.dateValue == date)
        #expect(value.typeName == "date")
    }

    // MARK: - AttachmentIds Tests

    @Test
    func attachmentIdsValue_returnsUUIDs() {
        let ids = [UUID(), UUID()]
        let value = FieldValue.attachmentIds(ids)
        #expect(value.attachmentIdsValue == ids)
        #expect(value.typeName == "attachmentIds")
    }

    // MARK: - StringArray Tests

    @Test
    func stringArrayValue_returnsStringArray() {
        let array = ["one", "two", "three"]
        let value = FieldValue.stringArray(array)
        #expect(value.stringArrayValue == array)
        #expect(value.typeName == "stringArray")
    }

    // MARK: - Codable Tests

    @Test
    func codable_stringRoundTrip() throws {
        let original = FieldValue.string("test value")
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(FieldValue.self, from: encoded)
        #expect(decoded == original)
    }

    @Test
    func codable_intRoundTrip() throws {
        let original = FieldValue.int(42)
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(FieldValue.self, from: encoded)
        #expect(decoded == original)
    }

    @Test
    func codable_doubleRoundTrip() throws {
        let original = FieldValue.double(3.14159)
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(FieldValue.self, from: encoded)
        #expect(decoded == original)
    }

    @Test
    func codable_boolRoundTrip() throws {
        let original = FieldValue.bool(true)
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(FieldValue.self, from: encoded)
        #expect(decoded == original)
    }

    @Test
    func codable_dateRoundTrip() throws {
        let original = FieldValue.date(Date(timeIntervalSince1970: 1_000_000))
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(FieldValue.self, from: encoded)
        #expect(decoded == original)
    }

    @Test
    func codable_attachmentIdsRoundTrip() throws {
        let ids = [UUID(), UUID(), UUID()]
        let original = FieldValue.attachmentIds(ids)
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(FieldValue.self, from: encoded)
        #expect(decoded == original)
    }

    @Test
    func codable_stringArrayRoundTrip() throws {
        let original = FieldValue.stringArray(["one", "two", "three"])
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(FieldValue.self, from: encoded)
        #expect(decoded == original)
    }

    // MARK: - Equatable Tests

    @Test
    func equatable_sameValuesEqual() {
        #expect(FieldValue.string("test") == FieldValue.string("test"))
        #expect(FieldValue.int(42) == FieldValue.int(42))
        #expect(FieldValue.bool(true) == FieldValue.bool(true))
    }

    @Test
    func equatable_differentValuesNotEqual() {
        #expect(FieldValue.string("test") != FieldValue.string("other"))
        #expect(FieldValue.int(42) != FieldValue.int(43))
        #expect(FieldValue.string("42") != FieldValue.int(42))
    }

    // MARK: - Hashable Tests

    @Test
    func hashable_canUseInSet() {
        let set: Set<FieldValue> = [
            .string("test"),
            .int(42),
            .bool(true)
        ]
        #expect(set.count == 3)
        #expect(set.contains(.string("test")))
    }
}
