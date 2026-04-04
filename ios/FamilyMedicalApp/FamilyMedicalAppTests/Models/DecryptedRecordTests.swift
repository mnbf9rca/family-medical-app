import Foundation
import Testing
@testable import FamilyMedicalApp

struct DecryptedRecordTests {
    private func makeEnvelope(recordType: RecordType = .immunization) throws -> RecordContentEnvelope {
        let record = ImmunizationRecord(vaccineCode: "Test", occurrenceDate: Date())
        if recordType == .immunization {
            return try RecordContentEnvelope(record)
        }
        // For other types, use direct init
        return RecordContentEnvelope(
            recordType: recordType,
            schemaVersion: 1,
            content: Data("{\"notes\":null,\"tags\":[]}".utf8)
        )
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
