import Foundation
import Testing
@testable import FamilyMedicalApp

@Suite("ImmunizationRecord Tests")
struct ImmunizationRecordTests {
    private let encoder: JSONEncoder = {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        return enc
    }()

    private let decoder: JSONDecoder = {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return dec
    }()

    @Test("Round-trips all fields")
    func roundTrip() throws {
        let record = ImmunizationRecord(
            vaccineCode: "Pfizer-BioNTech COVID-19",
            occurrenceDate: Date(timeIntervalSince1970: 1_700_000_000),
            lotNumber: "EL9262",
            site: "Left arm",
            doseNumber: 2,
            dosesInSeries: 3,
            notes: "No side effects",
            tags: ["covid", "booster"]
        )
        let data = try encoder.encode(record)
        let decoded = try decoder.decode(ImmunizationRecord.self, from: data)
        #expect(decoded.vaccineCode == "Pfizer-BioNTech COVID-19")
        #expect(decoded.lotNumber == "EL9262")
        #expect(decoded.doseNumber == 2)
        #expect(decoded.tags == ["covid", "booster"])
    }

    @Test("Unknown fields preserved on round-trip")
    func unknownFieldsPreserved() throws {
        let json = Data("""
        {
            "vaccineCode": "MMR",
            "occurrenceDate": "2026-01-15T10:00:00Z",
            "tags": [],
            "futureField": "some new data",
            "futureNestedField": {"key": "value", "count": 42}
        }
        """.utf8)
        let decoded = try decoder.decode(ImmunizationRecord.self, from: json)
        #expect(decoded.vaccineCode == "MMR")
        #expect(decoded.unknownFields.count == 2)
        #expect(decoded.unknownFields["futureField"] == .string("some new data"))

        let reencoded = try encoder.encode(decoded)
        let redecoded = try decoder.decode(ImmunizationRecord.self, from: reencoded)
        #expect(redecoded.unknownFields["futureField"] == .string("some new data"))
        #expect(redecoded.unknownFields["futureNestedField"] == .object(["key": .string("value"), "count": .int(42)]))
    }

    @Test("Missing optional fields decode as nil")
    func missingOptionals() throws {
        let json = Data("""
        {
            "vaccineCode": "BCG",
            "occurrenceDate": "2026-01-15T10:00:00Z",
            "tags": []
        }
        """.utf8)
        let decoded = try decoder.decode(ImmunizationRecord.self, from: json)
        #expect(decoded.vaccineCode == "BCG")
        #expect(decoded.lotNumber == nil)
        #expect(decoded.doseNumber == nil)
        #expect(decoded.unknownFields.isEmpty)
    }

    @Test("Static metadata is correct")
    func staticMetadata() {
        #expect(ImmunizationRecord.recordType == .immunization)
        #expect(ImmunizationRecord.schemaVersion == 1)
        #expect(ImmunizationRecord.displayName == "Immunization")
        #expect(!ImmunizationRecord.fieldMetadata.isEmpty)
    }
}
