import Foundation
import Testing
@testable import FamilyMedicalApp

@Suite("JSONValue Tests")
struct JSONValueTests {
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    @Test("Round-trips String value")
    func roundTripString() throws {
        let value = JSONValue.string("hello")
        let data = try encoder.encode(value)
        let decoded = try decoder.decode(JSONValue.self, from: data)
        #expect(decoded == value)
    }

    @Test("Round-trips Int value")
    func roundTripInt() throws {
        let value = JSONValue.int(42)
        let data = try encoder.encode(value)
        let decoded = try decoder.decode(JSONValue.self, from: data)
        #expect(decoded == value)
    }

    @Test("Round-trips Double value")
    func roundTripDouble() throws {
        let value = JSONValue.double(3.14)
        let data = try encoder.encode(value)
        let decoded = try decoder.decode(JSONValue.self, from: data)
        #expect(decoded == value)
    }

    @Test("Round-trips Bool value")
    func roundTripBool() throws {
        let value = JSONValue.bool(true)
        let data = try encoder.encode(value)
        let decoded = try decoder.decode(JSONValue.self, from: data)
        #expect(decoded == value)
    }

    @Test("Round-trips null value")
    func roundTripNull() throws {
        let value = JSONValue.null
        let data = try encoder.encode(value)
        let decoded = try decoder.decode(JSONValue.self, from: data)
        #expect(decoded == value)
    }

    @Test("Round-trips nested object with mixed types")
    func roundTripNestedObject() throws {
        let value = JSONValue.object([
            "name": .string("test"),
            "count": .int(5),
            "nested": .object(["key": .bool(false)]),
            "items": .array([.int(1), .int(2), .string("three")])
        ])
        let data = try encoder.encode(value)
        let decoded = try decoder.decode(JSONValue.self, from: data)
        #expect(decoded == value)
    }

    @Test("JSON true decodes as .bool, not .int")
    func boolDecodesBeforeInt() throws {
        let json = Data("true".utf8)
        let decoded = try decoder.decode(JSONValue.self, from: json)
        #expect(decoded == .bool(true))
    }

    @Test("JSON numeric 0 and 1 decode as .int, not .bool")
    func numericZeroAndOneDecodeAsInt() throws {
        let zeroJSON = Data("0".utf8)
        let zeroDecoded = try decoder.decode(JSONValue.self, from: zeroJSON)
        #expect(zeroDecoded == .int(0))

        let oneJSON = Data("1".utf8)
        let oneDecoded = try decoder.decode(JSONValue.self, from: oneJSON)
        #expect(oneDecoded == .int(1))
    }
}
