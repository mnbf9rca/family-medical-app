import XCTest
@testable import FamilyMedicalApp

final class JSONValueTests: XCTestCase {
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    func testRoundTripString() throws {
        let value = JSONValue.string("hello")
        let data = try encoder.encode(value)
        let decoded = try decoder.decode(JSONValue.self, from: data)
        XCTAssertEqual(decoded, value)
    }

    func testRoundTripInt() throws {
        let value = JSONValue.int(42)
        let data = try encoder.encode(value)
        let decoded = try decoder.decode(JSONValue.self, from: data)
        XCTAssertEqual(decoded, value)
    }

    func testRoundTripDouble() throws {
        let value = JSONValue.double(3.14)
        let data = try encoder.encode(value)
        let decoded = try decoder.decode(JSONValue.self, from: data)
        XCTAssertEqual(decoded, value)
    }

    func testRoundTripBool() throws {
        let value = JSONValue.bool(true)
        let data = try encoder.encode(value)
        let decoded = try decoder.decode(JSONValue.self, from: data)
        XCTAssertEqual(decoded, value)
    }

    func testRoundTripNull() throws {
        let value = JSONValue.null
        let data = try encoder.encode(value)
        let decoded = try decoder.decode(JSONValue.self, from: data)
        XCTAssertEqual(decoded, value)
    }

    func testRoundTripNestedObject() throws {
        let value = JSONValue.object([
            "name": .string("test"),
            "count": .int(5),
            "nested": .object(["key": .bool(false)]),
            "items": .array([.int(1), .int(2), .string("three")])
        ])
        let data = try encoder.encode(value)
        let decoded = try decoder.decode(JSONValue.self, from: data)
        XCTAssertEqual(decoded, value)
    }

    func testBoolDecodesBeforeInt() throws {
        // JSON true must decode as .bool(true), not .int(1)
        let json = Data("true".utf8)
        let decoded = try decoder.decode(JSONValue.self, from: json)
        XCTAssertEqual(decoded, .bool(true))
    }
}
