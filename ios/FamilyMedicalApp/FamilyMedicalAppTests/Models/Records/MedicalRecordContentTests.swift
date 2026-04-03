import Foundation
import Testing
@testable import FamilyMedicalApp

// MARK: - Test Helpers

/// Minimal MedicalRecordContent conformer for testing envelope and protocol logic.
private struct StubRecordA: MedicalRecordContent {
    static let recordType: RecordType = .immunization
    static let schemaVersion: Int = 1
    static let displayName: String = "Stub A"
    static let iconSystemName: String = "syringe"
    static let fieldMetadata: [FieldMetadata] = []

    var name: String
    var notes: String?
    var tags: [String]
    var unknownFields: [String: JSONValue]

    init(
        name: String = "test",
        notes: String? = nil,
        tags: [String] = [],
        unknownFields: [String: JSONValue] = [:]
    ) {
        self.name = name
        self.notes = notes
        self.tags = tags
        self.unknownFields = unknownFields
    }
}

/// Second conformer with a different recordType for mismatch testing.
private struct StubRecordB: MedicalRecordContent {
    static let recordType: RecordType = .condition
    static let schemaVersion: Int = 1
    static let displayName: String = "Stub B"
    static let iconSystemName: String = "heart"
    static let fieldMetadata: [FieldMetadata] = []

    var notes: String?
    var tags: [String]
    var unknownFields: [String: JSONValue]

    init(
        notes: String? = nil,
        tags: [String] = [],
        unknownFields: [String: JSONValue] = [:]
    ) {
        self.notes = notes
        self.tags = tags
        self.unknownFields = unknownFields
    }
}

// MARK: - RecordType Tests

@Suite("RecordType Tests")
struct RecordTypeTests {
    @Test("All 9 cases round-trip through Codable")
    func allCasesRoundTrip() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for recordType in RecordType.allCases {
            let data = try encoder.encode(recordType)
            let decoded = try decoder.decode(RecordType.self, from: data)
            #expect(decoded == recordType)
        }
    }

    @Test("Has exactly 9 cases")
    func caseCount() {
        #expect(RecordType.allCases.count == 9)
    }

    @Test("Raw values match expected strings")
    func rawValues() {
        #expect(RecordType.immunization.rawValue == "immunization")
        #expect(RecordType.medicationStatement.rawValue == "medicationStatement")
        #expect(RecordType.allergyIntolerance.rawValue == "allergyIntolerance")
        #expect(RecordType.condition.rawValue == "condition")
        #expect(RecordType.observation.rawValue == "observation")
        #expect(RecordType.procedure.rawValue == "procedure")
        #expect(RecordType.documentReference.rawValue == "documentReference")
        #expect(RecordType.familyMemberHistory.rawValue == "familyMemberHistory")
        #expect(RecordType.clinicalNote.rawValue == "clinicalNote")
    }
}

// MARK: - RecordContentEnvelope Tests

@Suite("RecordContentEnvelope Tests")
struct RecordContentEnvelopeTests {
    @Test("Round-trips a record through the envelope")
    func roundTrip() throws {
        let original = StubRecordA(name: "MMR Vaccine", notes: "First dose", tags: ["child"])
        let envelope = try RecordContentEnvelope(original)

        #expect(envelope.recordType == .immunization)
        #expect(envelope.schemaVersion == 1)

        let decoded = try envelope.decode(StubRecordA.self)
        #expect(decoded.name == "MMR Vaccine")
        #expect(decoded.notes == "First dose")
        #expect(decoded.tags == ["child"])
    }

    @Test("Decoding with mismatched type throws")
    func typeMismatchThrows() throws {
        let record = StubRecordA(name: "test")
        let envelope = try RecordContentEnvelope(record)

        #expect(throws: DecodingError.self) {
            _ = try envelope.decode(StubRecordB.self)
        }
    }

    @Test("Preserves recordType and schemaVersion")
    func preservesMetadata() throws {
        let record = StubRecordA()
        let envelope = try RecordContentEnvelope(record)

        #expect(envelope.recordType == StubRecordA.recordType)
        #expect(envelope.schemaVersion == StubRecordA.schemaVersion)
    }

    @Test("Envelope itself round-trips through Codable")
    func envelopeCodable() throws {
        let record = StubRecordA(name: "test", tags: ["a", "b"])
        let envelope = try RecordContentEnvelope(record)

        let data = try JSONEncoder().encode(envelope)
        let decoded = try JSONDecoder().decode(RecordContentEnvelope.self, from: data)

        #expect(decoded.recordType == envelope.recordType)
        #expect(decoded.schemaVersion == envelope.schemaVersion)

        let inner = try decoded.decode(StubRecordA.self)
        #expect(inner.name == "test")
        #expect(inner.tags == ["a", "b"])
    }
}

// MARK: - FieldMetadata Tests

@Suite("FieldMetadata Tests")
struct FieldMetadataTests {
    @Test("Equatable conformance works")
    func equatable() {
        let first = FieldMetadata(
            keyPath: "name",
            displayName: "Name",
            fieldType: .text,
            isRequired: true,
            displayOrder: 0
        )
        let second = FieldMetadata(
            keyPath: "name",
            displayName: "Name",
            fieldType: .text,
            isRequired: true,
            displayOrder: 0
        )
        let different = FieldMetadata(
            keyPath: "date",
            displayName: "Date",
            fieldType: .date,
            displayOrder: 1
        )
        #expect(first == second)
        #expect(first != different)
    }

    @Test("Default parameter values")
    func defaults() {
        let meta = FieldMetadata(
            keyPath: "test",
            displayName: "Test",
            fieldType: .text,
            displayOrder: 0
        )
        #expect(meta.isRequired == false)
        #expect(meta.placeholder == nil)
        #expect(meta.autocompleteSource == nil)
        #expect(meta.pickerOptions == nil)
    }
}
