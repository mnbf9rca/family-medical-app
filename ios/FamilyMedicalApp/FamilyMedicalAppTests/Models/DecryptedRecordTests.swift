import Foundation
import Testing
@testable import FamilyMedicalApp

struct DecryptedRecordTests {
    @Test
    func identifiableUsesRecordId() throws {
        let recordId = UUID()
        let record = MedicalRecord(id: recordId, personId: UUID(), encryptedContent: Data())
        let content = RecordContent(schemaId: "vaccine")
        let decrypted = DecryptedRecord(record: record, content: content)

        #expect(decrypted.id == recordId)
    }

    @Test
    func hashUsesRecordId() throws {
        let recordId = UUID()
        let record1 = MedicalRecord(id: recordId, personId: UUID(), encryptedContent: Data())
        let record2 = MedicalRecord(id: recordId, personId: UUID(), encryptedContent: Data())
        let content1 = RecordContent(schemaId: "vaccine")
        let content2 = RecordContent(schemaId: "medication")

        let decrypted1 = DecryptedRecord(record: record1, content: content1)
        let decrypted2 = DecryptedRecord(record: record2, content: content2)

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

        let content = RecordContent(schemaId: "vaccine")

        let decrypted1 = DecryptedRecord(record: record1, content: content)
        let decrypted2 = DecryptedRecord(record: record2, content: content)
        let decrypted3 = DecryptedRecord(record: record3, content: content)

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

        let content = RecordContent(schemaId: "vaccine")

        let decrypted1 = DecryptedRecord(record: record1, content: content)
        let decrypted2 = DecryptedRecord(record: record2, content: content)
        let decrypted3 = DecryptedRecord(record: record3, content: content)

        var set: Set<DecryptedRecord> = []
        set.insert(decrypted1)
        set.insert(decrypted2) // Should not increase size (same ID)
        set.insert(decrypted3) // Should increase size (different ID)

        #expect(set.count == 2)
    }
}
