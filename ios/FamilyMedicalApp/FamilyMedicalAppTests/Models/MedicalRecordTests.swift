import Foundation
import Testing
@testable import FamilyMedicalApp

struct MedicalRecordTests {
    // MARK: - Valid Initialization

    @Test
    func init_validRecord_succeeds() {
        let record = MedicalRecord(
            personId: UUID(),
            encryptedContent: Data(repeating: 0x00, count: 100)
        )

        #expect(record.version == 1)
        #expect(record.previousVersionId == nil)
        #expect(record.encryptedContent.count == 100)
    }

    @Test
    func init_withAllParameters_succeeds() {
        let id = UUID()
        let personId = UUID()
        let previousId = UUID()
        let created = Date(timeIntervalSince1970: 1_000_000)
        let updated = Date(timeIntervalSince1970: 2_000_000)

        let record = MedicalRecord(
            id: id,
            personId: personId,
            encryptedContent: Data(repeating: 0x42, count: 50),
            createdAt: created,
            updatedAt: updated,
            version: 3,
            previousVersionId: previousId
        )

        #expect(record.id == id)
        #expect(record.personId == personId)
        #expect(record.createdAt == created)
        #expect(record.updatedAt == updated)
        #expect(record.version == 3)
        #expect(record.previousVersionId == previousId)
        #expect(record.encryptedContent.count == 50)
    }

    // MARK: - Codable

    @Test
    func codable_roundTrip() throws {
        let original = MedicalRecord(
            id: UUID(),
            personId: UUID(),
            encryptedContent: Data(repeating: 0x42, count: 100),
            createdAt: Date(timeIntervalSince1970: 1_000_000),
            updatedAt: Date(timeIntervalSince1970: 2_000_000),
            version: 2,
            previousVersionId: UUID()
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MedicalRecord.self, from: encoded)

        #expect(decoded == original)
        #expect(decoded.id == original.id)
        #expect(decoded.personId == original.personId)
        #expect(decoded.version == original.version)
        #expect(decoded.encryptedContent == original.encryptedContent)
    }

    // MARK: - Equatable

    @Test
    func equatable_sameRecord_equal() {
        let id = UUID()
        let personId = UUID()
        let now = Date()
        let content = Data(repeating: 0xAB, count: 10)

        let record1 = MedicalRecord(
            id: id,
            personId: personId,
            encryptedContent: content,
            createdAt: now,
            updatedAt: now
        )
        let record2 = MedicalRecord(
            id: id,
            personId: personId,
            encryptedContent: content,
            createdAt: now,
            updatedAt: now
        )
        #expect(record1 == record2)
    }

    @Test
    func equatable_differentContent_notEqual() {
        let personId = UUID()

        let record1 = MedicalRecord(
            personId: personId,
            encryptedContent: Data(repeating: 0x01, count: 10)
        )
        let record2 = MedicalRecord(
            personId: personId,
            encryptedContent: Data(repeating: 0x02, count: 10)
        )
        #expect(record1 != record2)
    }

    @Test
    func equatable_differentPersonId_notEqual() {
        let content = Data(repeating: 0xAB, count: 10)

        let record1 = MedicalRecord(
            personId: UUID(),
            encryptedContent: content
        )
        let record2 = MedicalRecord(
            personId: UUID(),
            encryptedContent: content
        )
        #expect(record1 != record2)
    }
}
