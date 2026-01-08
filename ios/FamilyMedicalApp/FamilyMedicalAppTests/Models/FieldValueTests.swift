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

    /// Test data for parameterized codable round-trip tests
    /// Uses deterministic values (fixed UUIDs, timestamps) for reproducible tests
    static let codableTestCases: [FieldValue] = [
        .string("test value"),
        .int(42),
        .double(3.14159),
        .bool(true),
        .date(Date(timeIntervalSince1970: 1_000_000)),
        // swiftlint:disable:next force_unwrapping
        .attachmentIds([UUID(uuidString: "12345678-1234-1234-1234-123456789012")!]),
        .stringArray(["one", "two", "three"])
    ]

    @Test(arguments: codableTestCases)
    func codable_roundTrip(value: FieldValue) throws {
        let encoded = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(FieldValue.self, from: encoded)
        #expect(decoded == value)
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
