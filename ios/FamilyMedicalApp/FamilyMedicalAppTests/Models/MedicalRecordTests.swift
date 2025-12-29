import Foundation
import Testing
@testable import FamilyMedicalApp

struct MedicalRecordTests {
    // MARK: - Valid Initialization

    @Test
    func init_validRecord_succeeds() {
        let record = MedicalRecord(
            personId: UUID(),
            schemaId: "vaccine",
            encryptedContent: Data(repeating: 0x00, count: 100)
        )

        #expect(record.schemaId == "vaccine")
        #expect(record.version == 1)
        #expect(record.previousVersionId == nil)
    }

    @Test
    func init_freeformRecord_succeeds() {
        let record = MedicalRecord(
            personId: UUID(),
            schemaId: nil,
            encryptedContent: Data()
        )

        #expect(record.schemaId == nil)
        #expect(record.isFreeform)
    }

    // MARK: - Helpers

    @Test
    func isBuiltInSchema_builtInType_returnsTrue() {
        let record = MedicalRecord(
            personId: UUID(),
            schemaId: "vaccine",
            encryptedContent: Data()
        )
        #expect(record.isBuiltInSchema)
    }

    @Test
    func isBuiltInSchema_customType_returnsFalse() {
        let record = MedicalRecord(
            personId: UUID(),
            schemaId: "my-custom-type",
            encryptedContent: Data()
        )
        #expect(!record.isBuiltInSchema)
    }

    @Test
    func isBuiltInSchema_nilSchemaId_returnsFalse() {
        let record = MedicalRecord(
            personId: UUID(),
            schemaId: nil,
            encryptedContent: Data()
        )
        #expect(!record.isBuiltInSchema)
    }

    @Test
    func isFreeform_nilSchemaId_returnsTrue() {
        let record = MedicalRecord(
            personId: UUID(),
            schemaId: nil,
            encryptedContent: Data()
        )
        #expect(record.isFreeform)
    }

    @Test
    func isFreeform_withSchemaId_returnsFalse() {
        let record = MedicalRecord(
            personId: UUID(),
            schemaId: "vaccine",
            encryptedContent: Data()
        )
        #expect(!record.isFreeform)
    }

    // MARK: - Codable

    @Test
    func codable_roundTrip() throws {
        let original = MedicalRecord(
            id: UUID(),
            personId: UUID(),
            schemaId: "vaccine",
            encryptedContent: Data(repeating: 0x42, count: 100),
            createdAt: Date(timeIntervalSince1970: 1_000_000),
            updatedAt: Date(timeIntervalSince1970: 2_000_000),
            version: 2,
            previousVersionId: UUID()
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MedicalRecord.self, from: encoded)

        #expect(decoded == original)
        #expect(decoded.schemaId == original.schemaId)
        #expect(decoded.version == original.version)
    }

    // MARK: - Equatable

    @Test
    func equatable_sameRecord_equal() {
        let id = UUID()
        let personId = UUID()
        let now = Date()
        let record1 = MedicalRecord(
            id: id,
            personId: personId,
            schemaId: "vaccine",
            encryptedContent: Data(),
            createdAt: now,
            updatedAt: now
        )
        let record2 = MedicalRecord(
            id: id,
            personId: personId,
            schemaId: "vaccine",
            encryptedContent: Data(),
            createdAt: now,
            updatedAt: now
        )
        #expect(record1 == record2)
    }

    @Test
    func equatable_differentRecord_notEqual() {
        let record1 = MedicalRecord(
            personId: UUID(),
            schemaId: "vaccine",
            encryptedContent: Data()
        )
        let record2 = MedicalRecord(
            personId: UUID(),
            schemaId: "medication",
            encryptedContent: Data()
        )
        #expect(record1 != record2)
    }
}
