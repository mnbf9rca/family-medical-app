import Foundation
import Testing
@testable import FamilyMedicalApp

// MARK: - Shared helpers

private let iso8601Encoder: JSONEncoder = {
    let enc = JSONEncoder()
    enc.dateEncodingStrategy = .iso8601
    return enc
}()

private let iso8601Decoder: JSONDecoder = {
    let dec = JSONDecoder()
    dec.dateDecodingStrategy = .iso8601
    return dec
}()

// MARK: - MedicationStatementRecord

@Suite("MedicationStatementRecord Tests")
struct MedicationStatementRecordTests {
    @Test("Round-trips all fields")
    func roundTrip() throws {
        let record = MedicationStatementRecord(
            medicationName: "Metformin",
            dosage: "500mg",
            frequency: "Twice daily",
            startDate: Date(timeIntervalSince1970: 1_700_000_000),
            reasonForUse: "Type 2 diabetes",
            notes: "Take with food",
            tags: ["diabetes", "oral"]
        )
        let data = try iso8601Encoder.encode(record)
        let decoded = try iso8601Decoder.decode(MedicationStatementRecord.self, from: data)
        #expect(decoded.medicationName == "Metformin")
        #expect(decoded.dosage == "500mg")
        #expect(decoded.frequency == "Twice daily")
        #expect(decoded.reasonForUse == "Type 2 diabetes")
        #expect(decoded.tags == ["diabetes", "oral"])
    }

    @Test("Unknown fields preserved on round-trip")
    func unknownFieldsPreserved() throws {
        let json = Data("""
        {"medicationName":"Aspirin","tags":[],"futureField":"extra data","futureCount":99}
        """.utf8)
        let decoded = try iso8601Decoder.decode(MedicationStatementRecord.self, from: json)
        #expect(decoded.unknownFields["futureField"] == .string("extra data"))
        #expect(decoded.unknownFields["futureCount"] == .int(99))
        let redecoded = try iso8601Decoder.decode(
            MedicationStatementRecord.self,
            from: iso8601Encoder.encode(decoded)
        )
        #expect(redecoded.unknownFields["futureField"] == .string("extra data"))
    }

    @Test("Missing optional fields decode as nil")
    func missingOptionalsDecodeAsNil() throws {
        let json = Data("{\"medicationName\":\"Ibuprofen\",\"tags\":[]}".utf8)
        let decoded = try iso8601Decoder.decode(MedicationStatementRecord.self, from: json)
        #expect(decoded.dosage == nil)
        #expect(decoded.frequency == nil)
        #expect(decoded.unknownFields.isEmpty)
    }

    @Test("Static metadata is correct")
    func staticMetadata() {
        #expect(MedicationStatementRecord.recordType == .medicationStatement)
        #expect(!MedicationStatementRecord.fieldMetadata.isEmpty)
    }
}

// MARK: - AllergyIntoleranceRecord

@Suite("AllergyIntoleranceRecord Tests")
struct AllergyIntoleranceRecordTests {
    @Test("Round-trips all fields")
    func roundTrip() throws {
        let record = AllergyIntoleranceRecord(
            substance: "Penicillin",
            reaction: "Hives",
            severity: "Moderate",
            onsetDate: Date(timeIntervalSince1970: 1_700_000_000),
            notes: "Confirmed by allergist",
            tags: ["antibiotic", "drug"]
        )
        let data = try iso8601Encoder.encode(record)
        let decoded = try iso8601Decoder.decode(AllergyIntoleranceRecord.self, from: data)
        #expect(decoded.substance == "Penicillin")
        #expect(decoded.reaction == "Hives")
        #expect(decoded.severity == "Moderate")
        #expect(decoded.tags == ["antibiotic", "drug"])
    }

    @Test("Unknown fields preserved on round-trip")
    func unknownFieldsPreserved() throws {
        let json = Data("""
        {"substance":"Latex","tags":[],"futureField":"new info","futureFlag":true}
        """.utf8)
        let decoded = try iso8601Decoder.decode(AllergyIntoleranceRecord.self, from: json)
        #expect(decoded.unknownFields["futureField"] == .string("new info"))
        #expect(decoded.unknownFields["futureFlag"] == .bool(true))
        let redecoded = try iso8601Decoder.decode(
            AllergyIntoleranceRecord.self,
            from: iso8601Encoder.encode(decoded)
        )
        #expect(redecoded.unknownFields["futureFlag"] == .bool(true))
    }

    @Test("Missing optional fields decode as nil")
    func missingOptionalsDecodeAsNil() throws {
        let json = Data("{\"substance\":\"Shellfish\",\"tags\":[]}".utf8)
        let decoded = try iso8601Decoder.decode(AllergyIntoleranceRecord.self, from: json)
        #expect(decoded.reaction == nil)
        #expect(decoded.severity == nil)
        #expect(decoded.unknownFields.isEmpty)
    }

    @Test("Static metadata is correct")
    func staticMetadata() {
        #expect(AllergyIntoleranceRecord.recordType == .allergyIntolerance)
        #expect(!AllergyIntoleranceRecord.fieldMetadata.isEmpty)
    }
}

// MARK: - ConditionRecord

@Suite("ConditionRecord Tests")
struct ConditionRecordTests {
    @Test("Round-trips all fields")
    func roundTrip() throws {
        let record = ConditionRecord(
            conditionName: "Hypertension",
            onsetDate: Date(timeIntervalSince1970: 1_700_000_000),
            severity: "Moderate",
            status: "Active",
            notes: "Monitor monthly",
            tags: ["chronic", "cardiovascular"]
        )
        let data = try iso8601Encoder.encode(record)
        let decoded = try iso8601Decoder.decode(ConditionRecord.self, from: data)
        #expect(decoded.conditionName == "Hypertension")
        #expect(decoded.severity == "Moderate")
        #expect(decoded.status == "Active")
        #expect(decoded.tags == ["chronic", "cardiovascular"])
    }

    @Test("Unknown fields preserved on round-trip")
    func unknownFieldsPreserved() throws {
        let json = Data("""
        {"conditionName":"Asthma","tags":[],"futureField":"extra","futureNested":{"a":1}}
        """.utf8)
        let decoded = try iso8601Decoder.decode(ConditionRecord.self, from: json)
        #expect(decoded.unknownFields["futureField"] == .string("extra"))
        let redecoded = try iso8601Decoder.decode(
            ConditionRecord.self,
            from: iso8601Encoder.encode(decoded)
        )
        #expect(redecoded.unknownFields["futureNested"] == .object(["a": .int(1)]))
    }

    @Test("Missing optional fields decode as nil")
    func missingOptionalsDecodeAsNil() throws {
        let json = Data("{\"conditionName\":\"Migraine\",\"tags\":[]}".utf8)
        let decoded = try iso8601Decoder.decode(ConditionRecord.self, from: json)
        #expect(decoded.onsetDate == nil)
        #expect(decoded.severity == nil)
        #expect(decoded.unknownFields.isEmpty)
    }

    @Test("Static metadata is correct")
    func staticMetadata() {
        #expect(ConditionRecord.recordType == .condition)
        #expect(!ConditionRecord.fieldMetadata.isEmpty)
    }
}

// MARK: - ObservationRecord

@Suite("ObservationRecord Tests")
struct ObservationRecordTests {
    @Test("Round-trips all fields")
    func roundTrip() throws {
        let components = [
            ObservationComponent(name: "Systolic", value: 120, unit: "mmHg"),
            ObservationComponent(name: "Diastolic", value: 80, unit: "mmHg")
        ]
        let record = ObservationRecord(
            observationType: "Blood Pressure",
            components: components,
            effectiveDate: Date(timeIntervalSince1970: 1_700_000_000),
            method: "Cuff",
            referenceRange: "90-120 / 60-80 mmHg",
            notes: "Measured at rest",
            tags: ["vitals", "bp"]
        )
        let data = try iso8601Encoder.encode(record)
        let decoded = try iso8601Decoder.decode(ObservationRecord.self, from: data)
        #expect(decoded.observationType == "Blood Pressure")
        #expect(decoded.components.count == 2)
        #expect(decoded.components[0].name == "Systolic")
        #expect(decoded.method == "Cuff")
        #expect(decoded.tags == ["vitals", "bp"])
    }

    @Test("Unknown fields preserved on round-trip")
    func unknownFieldsPreserved() throws {
        let json = Data("""
        {
            "observationType":"Weight",
            "components":[{"name":"Weight","value":70.5,"unit":"kg"}],
            "effectiveDate":"2026-01-15T10:00:00Z",
            "tags":[],
            "futureField":"new",
            "futureScore":42
        }
        """.utf8)
        let decoded = try iso8601Decoder.decode(ObservationRecord.self, from: json)
        #expect(decoded.unknownFields["futureField"] == .string("new"))
        #expect(decoded.unknownFields["futureScore"] == .int(42))
        let redecoded = try iso8601Decoder.decode(
            ObservationRecord.self,
            from: iso8601Encoder.encode(decoded)
        )
        #expect(redecoded.unknownFields["futureScore"] == .int(42))
    }

    @Test("Missing optional fields decode as nil")
    func missingOptionalsDecodeAsNil() throws {
        let json = Data("""
        {
            "observationType":"Height",
            "components":[{"name":"Height","value":175,"unit":"cm"}],
            "effectiveDate":"2026-01-15T10:00:00Z",
            "tags":[]
        }
        """.utf8)
        let decoded = try iso8601Decoder.decode(ObservationRecord.self, from: json)
        #expect(decoded.method == nil)
        #expect(decoded.providerId == nil)
        #expect(decoded.unknownFields.isEmpty)
    }

    @Test("Static metadata is correct")
    func staticMetadata() {
        #expect(ObservationRecord.recordType == .observation)
        #expect(!ObservationRecord.fieldMetadata.isEmpty)
    }
}

// MARK: - ProcedureRecord

@Suite("ProcedureRecord Tests")
struct ProcedureRecordTests {
    @Test("Round-trips all fields")
    func roundTrip() throws {
        let record = ProcedureRecord(
            procedureName: "Appendectomy",
            performedDate: Date(timeIntervalSince1970: 1_700_000_000),
            reason: "Acute appendicitis",
            outcome: "Successful",
            bodySite: "Abdomen",
            notes: "Laparoscopic",
            tags: ["surgery", "emergency"]
        )
        let data = try iso8601Encoder.encode(record)
        let decoded = try iso8601Decoder.decode(ProcedureRecord.self, from: data)
        #expect(decoded.procedureName == "Appendectomy")
        #expect(decoded.reason == "Acute appendicitis")
        #expect(decoded.outcome == "Successful")
        #expect(decoded.tags == ["surgery", "emergency"])
    }

    @Test("Unknown fields preserved on round-trip")
    func unknownFieldsPreserved() throws {
        let json = Data("""
        {"procedureName":"Colonoscopy","tags":[],"futureField":"data","futureCodes":["A","B"]}
        """.utf8)
        let decoded = try iso8601Decoder.decode(ProcedureRecord.self, from: json)
        #expect(decoded.unknownFields["futureField"] == .string("data"))
        #expect(decoded.unknownFields["futureCodes"] == .array([.string("A"), .string("B")]))
        let redecoded = try iso8601Decoder.decode(
            ProcedureRecord.self,
            from: iso8601Encoder.encode(decoded)
        )
        #expect(redecoded.unknownFields["futureCodes"] == .array([.string("A"), .string("B")]))
    }

    @Test("Missing optional fields decode as nil")
    func missingOptionalsDecodeAsNil() throws {
        let json = Data("{\"procedureName\":\"Blood draw\",\"tags\":[]}".utf8)
        let decoded = try iso8601Decoder.decode(ProcedureRecord.self, from: json)
        #expect(decoded.performedDate == nil)
        #expect(decoded.reason == nil)
        #expect(decoded.unknownFields.isEmpty)
    }

    @Test("Static metadata is correct")
    func staticMetadata() {
        #expect(ProcedureRecord.recordType == .procedure)
        #expect(!ProcedureRecord.fieldMetadata.isEmpty)
    }
}

// MARK: - DocumentReferenceRecord

@Suite("DocumentReferenceRecord Tests")
struct DocumentReferenceRecordTests {
    @Test("Round-trips all fields")
    func roundTrip() throws {
        let sourceId = UUID()
        let record = DocumentReferenceRecord(
            title: "Chest X-Ray Report",
            documentType: "PDF",
            mimeType: "application/pdf",
            fileSize: 204_800,
            sourceRecordId: sourceId,
            notes: "Reviewed by radiologist",
            tags: ["imaging", "xray"]
        )
        let data = try iso8601Encoder.encode(record)
        let decoded = try iso8601Decoder.decode(DocumentReferenceRecord.self, from: data)
        #expect(decoded.title == "Chest X-Ray Report")
        #expect(decoded.mimeType == "application/pdf")
        #expect(decoded.fileSize == 204_800)
        #expect(decoded.sourceRecordId == sourceId)
        #expect(decoded.tags == ["imaging", "xray"])
    }

    @Test("Unknown fields preserved on round-trip")
    func unknownFieldsPreserved() throws {
        let json = Data("""
        {
            "title":"Lab Results","mimeType":"application/pdf","fileSize":1024,
            "tags":[],"futureField":"extra","futureVersion":2
        }
        """.utf8)
        let decoded = try iso8601Decoder.decode(DocumentReferenceRecord.self, from: json)
        #expect(decoded.unknownFields["futureField"] == .string("extra"))
        #expect(decoded.unknownFields["futureVersion"] == .int(2))
        let redecoded = try iso8601Decoder.decode(
            DocumentReferenceRecord.self,
            from: iso8601Encoder.encode(decoded)
        )
        #expect(redecoded.unknownFields["futureVersion"] == .int(2))
    }

    @Test("Missing optional fields decode as nil")
    func missingOptionalsDecodeAsNil() throws {
        let json = Data("{\"title\":\"Scan\",\"mimeType\":\"image / jpeg\",\"fileSize\":512,\"tags\":[]}".utf8)
        let decoded = try iso8601Decoder.decode(DocumentReferenceRecord.self, from: json)
        #expect(decoded.documentType == nil)
        #expect(decoded.sourceRecordId == nil)
        #expect(decoded.unknownFields.isEmpty)
    }

    @Test("Static metadata is correct")
    func staticMetadata() {
        #expect(DocumentReferenceRecord.recordType == .documentReference)
        #expect(!DocumentReferenceRecord.fieldMetadata.isEmpty)
    }
}

// MARK: - FamilyMemberHistoryRecord

@Suite("FamilyMemberHistoryRecord Tests")
struct FamilyMemberHistoryRecordTests {
    @Test("Round-trips all fields")
    func roundTrip() throws {
        let record = FamilyMemberHistoryRecord(
            relationship: "Mother",
            conditionName: "Breast cancer",
            onsetAge: 52,
            deceased: true,
            deceasedAge: 68,
            notes: "Maternal side",
            tags: ["cancer", "maternal"]
        )
        let data = try iso8601Encoder.encode(record)
        let decoded = try iso8601Decoder.decode(FamilyMemberHistoryRecord.self, from: data)
        #expect(decoded.relationship == "Mother")
        #expect(decoded.conditionName == "Breast cancer")
        #expect(decoded.onsetAge == 52)
        #expect(decoded.deceased == true)
        #expect(decoded.deceasedAge == 68)
    }

    @Test("Unknown fields preserved on round-trip")
    func unknownFieldsPreserved() throws {
        let json = Data("""
        {
            "relationship":"Father","conditionName":"Type 2 diabetes",
            "tags":[],"futureField":"genetic marker","futureRisk":0.35
        }
        """.utf8)
        let decoded = try iso8601Decoder.decode(FamilyMemberHistoryRecord.self, from: json)
        #expect(decoded.unknownFields["futureField"] == .string("genetic marker"))
        let redecoded = try iso8601Decoder.decode(
            FamilyMemberHistoryRecord.self,
            from: iso8601Encoder.encode(decoded)
        )
        #expect(redecoded.unknownFields["futureRisk"] == .double(0.35))
    }

    @Test("Missing optional fields decode as nil")
    func missingOptionalsDecodeAsNil() throws {
        let json = Data("{\"relationship\":\"Sister\",\"conditionName\":\"Celiac disease\",\"tags\":[]}".utf8)
        let decoded = try iso8601Decoder.decode(FamilyMemberHistoryRecord.self, from: json)
        #expect(decoded.onsetAge == nil)
        #expect(decoded.deceased == nil)
        #expect(decoded.unknownFields.isEmpty)
    }

    @Test("Static metadata is correct")
    func staticMetadata() {
        #expect(FamilyMemberHistoryRecord.recordType == .familyMemberHistory)
        #expect(!FamilyMemberHistoryRecord.fieldMetadata.isEmpty)
    }
}

// MARK: - ClinicalNoteRecord

@Suite("ClinicalNoteRecord Tests")
struct ClinicalNoteRecordTests {
    @Test("Round-trips all fields")
    func roundTrip() throws {
        let record = ClinicalNoteRecord(
            title: "Post-op follow-up",
            body: "Patient recovering well. No signs of infection.",
            tags: ["post-op", "follow-up"]
        )
        let data = try iso8601Encoder.encode(record)
        let decoded = try iso8601Decoder.decode(ClinicalNoteRecord.self, from: data)
        #expect(decoded.title == "Post-op follow-up")
        #expect(decoded.body == "Patient recovering well. No signs of infection.")
        #expect(decoded.tags == ["post-op", "follow-up"])
    }

    @Test("Unknown fields preserved on round-trip")
    func unknownFieldsPreserved() throws {
        let json = Data("""
        {"title":"Annual checkup","tags":[],"futureField":"extra note","futureCategory":"routine"}
        """.utf8)
        let decoded = try iso8601Decoder.decode(ClinicalNoteRecord.self, from: json)
        #expect(decoded.unknownFields["futureField"] == .string("extra note"))
        let redecoded = try iso8601Decoder.decode(
            ClinicalNoteRecord.self,
            from: iso8601Encoder.encode(decoded)
        )
        #expect(redecoded.unknownFields["futureCategory"] == .string("routine"))
    }

    @Test("Missing optional fields decode as nil")
    func missingOptionalsDecodeAsNil() throws {
        let json = Data("{\"title\":\"Quick note\",\"tags\":[]}".utf8)
        let decoded = try iso8601Decoder.decode(ClinicalNoteRecord.self, from: json)
        #expect(decoded.body == nil)
        #expect(decoded.notes == nil)
        #expect(decoded.unknownFields.isEmpty)
    }

    @Test("Static metadata has no notes field (body IS the notes)")
    func staticMetadataNoNotesField() {
        #expect(ClinicalNoteRecord.recordType == .clinicalNote)
        #expect(ClinicalNoteRecord.displayName == "Note")
        let notesMeta = ClinicalNoteRecord.fieldMetadata.first { $0.keyPath == "notes" }
        #expect(notesMeta == nil)
        let bodyMeta = ClinicalNoteRecord.fieldMetadata.first { $0.keyPath == "body" }
        #expect(bodyMeta != nil)
    }
}
