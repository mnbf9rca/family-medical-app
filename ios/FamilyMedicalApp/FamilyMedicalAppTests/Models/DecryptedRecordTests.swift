import Foundation
import Testing
@testable import FamilyMedicalApp

struct DecryptedRecordTests {
    /// Build a valid envelope for the requested record type using real typed records,
    /// so the JSON content matches what `envelope.decode(T.self)` would expect.
    private func makeEnvelope(recordType: RecordType = .immunization) throws -> RecordContentEnvelope {
        switch recordType {
        case .immunization:
            try RecordContentEnvelope(ImmunizationRecord(vaccineCode: "Test", occurrenceDate: Date()))
        case .medicationStatement:
            try RecordContentEnvelope(MedicationStatementRecord(medicationName: "Test"))
        case .allergyIntolerance:
            try RecordContentEnvelope(AllergyIntoleranceRecord(substance: "Test"))
        case .condition:
            try RecordContentEnvelope(ConditionRecord(conditionName: "Test"))
        case .observation:
            try RecordContentEnvelope(
                ObservationRecord(
                    observationType: "Test",
                    components: [ObservationComponent(name: "Test", value: 1.0, unit: "unit")],
                    effectiveDate: Date()
                )
            )
        case .procedure:
            try RecordContentEnvelope(ProcedureRecord(procedureName: "Test"))
        case .documentReference:
            try RecordContentEnvelope(
                DocumentReferenceRecord(title: "Test", mimeType: "text/plain", fileSize: 0)
            )
        case .familyMemberHistory:
            try RecordContentEnvelope(
                FamilyMemberHistoryRecord(relationship: "Test", conditionName: "Test")
            )
        case .clinicalNote:
            try RecordContentEnvelope(ClinicalNoteRecord(title: "Test"))
        }
    }

    @Test
    func identifiableUsesRecordId() throws {
        let recordId = UUID()
        let record = MedicalRecord(id: recordId, personId: UUID(), encryptedContent: Data())
        let envelope = try makeEnvelope()
        let decrypted = DecryptedRecord(record: record, envelope: envelope)

        #expect(decrypted.id == recordId)
    }

    @Test
    func hashUsesRecordId() throws {
        let recordId = UUID()
        let record1 = MedicalRecord(id: recordId, personId: UUID(), encryptedContent: Data())
        let record2 = MedicalRecord(id: recordId, personId: UUID(), encryptedContent: Data())
        let envelope1 = try makeEnvelope(recordType: .immunization)
        let envelope2 = try makeEnvelope(recordType: .condition)

        let decrypted1 = DecryptedRecord(record: record1, envelope: envelope1)
        let decrypted2 = DecryptedRecord(record: record2, envelope: envelope2)

        // Same record ID should produce same hash
        var hasher1 = Hasher()
        var hasher2 = Hasher()
        decrypted1.hash(into: &hasher1)
        decrypted2.hash(into: &hasher2)

        #expect(hasher1.finalize() == hasher2.finalize())
    }

    @Test
    func equatableComparesRecordIds() throws {
        let recordId1 = UUID()
        let recordId2 = UUID()

        let record1 = MedicalRecord(id: recordId1, personId: UUID(), encryptedContent: Data())
        let record2 = MedicalRecord(id: recordId1, personId: UUID(), encryptedContent: Data())
        let record3 = MedicalRecord(id: recordId2, personId: UUID(), encryptedContent: Data())

        let envelope = try makeEnvelope()

        let decrypted1 = DecryptedRecord(record: record1, envelope: envelope)
        let decrypted2 = DecryptedRecord(record: record2, envelope: envelope)
        let decrypted3 = DecryptedRecord(record: record3, envelope: envelope)

        // Same record ID should be equal (even with different content)
        #expect(decrypted1 == decrypted2)
        // Different record ID should not be equal
        #expect(decrypted1 != decrypted3)
    }

    @Test
    func canBeUsedInSet() throws {
        let recordId1 = UUID()
        let recordId2 = UUID()

        let record1 = MedicalRecord(id: recordId1, personId: UUID(), encryptedContent: Data())
        let record2 = MedicalRecord(id: recordId1, personId: UUID(), encryptedContent: Data())
        let record3 = MedicalRecord(id: recordId2, personId: UUID(), encryptedContent: Data())

        let envelope = try makeEnvelope()

        let decrypted1 = DecryptedRecord(record: record1, envelope: envelope)
        let decrypted2 = DecryptedRecord(record: record2, envelope: envelope)
        let decrypted3 = DecryptedRecord(record: record3, envelope: envelope)

        var set: Set<DecryptedRecord> = []
        set.insert(decrypted1)
        set.insert(decrypted2) // Should not increase size (same ID)
        set.insert(decrypted3) // Should increase size (different ID)

        #expect(set.count == 2)
    }
}
