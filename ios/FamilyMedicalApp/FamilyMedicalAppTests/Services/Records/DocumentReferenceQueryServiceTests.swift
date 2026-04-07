import CryptoKit
import Foundation
import Testing
@testable import FamilyMedicalApp

@Suite("DocumentReferenceQueryService Tests")
struct DocumentReferenceQueryServiceTests {
    // MARK: - Fixtures

    private struct Fixture {
        let service: DocumentReferenceQueryService
        let recordRepo: MockMedicalRecordRepository
        let contentService: MockRecordContentService
        let fmkService: MockFamilyMemberKeyService
        let personId: UUID
        let primaryKey: SymmetricKey
        let fmk: SymmetricKey
    }

    private static func makeFixture() -> Fixture {
        let recordRepo = MockMedicalRecordRepository()
        let contentService = MockRecordContentService()
        let fmkService = MockFamilyMemberKeyService()
        let personId = UUID()
        let primaryKey = SymmetricKey(size: .bits256)
        let fmk = SymmetricKey(size: .bits256)
        fmkService.setFMK(fmk, for: personId.uuidString)
        let service = DocumentReferenceQueryService(
            recordRepository: recordRepo,
            recordContentService: contentService,
            fmkService: fmkService
        )
        return Fixture(
            service: service,
            recordRepo: recordRepo,
            contentService: contentService,
            fmkService: fmkService,
            personId: personId,
            primaryKey: primaryKey,
            fmk: fmk
        )
    }

    /// Encrypts an envelope via the mock content service and returns a persisted MedicalRecord.
    private static func persist(
        _ content: some MedicalRecordContent,
        recordId: UUID = UUID(),
        in fixture: Fixture
    ) throws -> MedicalRecord {
        let envelope = try RecordContentEnvelope(content)
        let encrypted = try fixture.contentService.encrypt(envelope, using: fixture.fmk)
        let record = MedicalRecord(
            id: recordId,
            personId: fixture.personId,
            encryptedContent: encrypted,
            createdAt: Date(),
            updatedAt: Date(),
            version: 1,
            previousVersionId: nil
        )
        fixture.recordRepo.addRecord(record)
        return record
    }

    // MARK: - attachmentsFor

    @Test("attachmentsFor returns only DocumentReferenceRecords with matching sourceRecordId")
    func filterBySourceRecordId() async throws {
        let ctx = Self.makeFixture()
        let parentId = UUID()
        let otherParentId = UUID()

        _ = try Self.persist(
            DocumentReferenceRecord(
                title: "Matching",
                mimeType: "image/jpeg",
                fileSize: 1,
                contentHMAC: Data([0x01]),
                sourceRecordId: parentId
            ),
            in: ctx
        )
        _ = try Self.persist(
            DocumentReferenceRecord(
                title: "OtherParent",
                mimeType: "image/jpeg",
                fileSize: 1,
                contentHMAC: Data([0x02]),
                sourceRecordId: otherParentId
            ),
            in: ctx
        )
        _ = try Self.persist(
            DocumentReferenceRecord(
                title: "Standalone",
                mimeType: "image/jpeg",
                fileSize: 1,
                contentHMAC: Data([0x03]),
                sourceRecordId: nil
            ),
            in: ctx
        )
        _ = try Self.persist(ImmunizationRecord(vaccineCode: "MMR", occurrenceDate: Date()), in: ctx)

        let results = try await ctx.service.attachmentsFor(
            sourceRecordId: parentId,
            personId: ctx.personId,
            primaryKey: ctx.primaryKey
        )
        #expect(results.count == 1)
        #expect(results.first?.content.title == "Matching")
    }

    @Test("attachmentsFor returns empty when no attachments reference the record")
    func attachmentsForEmptyResult() async throws {
        let ctx = Self.makeFixture()
        _ = try Self.persist(ImmunizationRecord(vaccineCode: "MMR", occurrenceDate: Date()), in: ctx)
        let results = try await ctx.service.attachmentsFor(
            sourceRecordId: UUID(),
            personId: ctx.personId,
            primaryKey: ctx.primaryKey
        )
        #expect(results.isEmpty)
    }

    // MARK: - allDocuments

    @Test("allDocuments returns every DocumentReferenceRecord regardless of sourceRecordId")
    func allDocumentsUnfiltered() async throws {
        let ctx = Self.makeFixture()
        _ = try Self.persist(
            DocumentReferenceRecord(
                title: "Standalone",
                mimeType: "application/pdf",
                fileSize: 10,
                contentHMAC: Data([0xAA])
            ),
            in: ctx
        )
        _ = try Self.persist(
            DocumentReferenceRecord(
                title: "Attached",
                mimeType: "image/png",
                fileSize: 20,
                contentHMAC: Data([0xBB]),
                sourceRecordId: UUID()
            ),
            in: ctx
        )
        _ = try Self.persist(ClinicalNoteRecord(title: "Note"), in: ctx)

        let results = try await ctx.service.allDocuments(
            personId: ctx.personId,
            primaryKey: ctx.primaryKey
        )
        #expect(results.count == 2)
    }

    // MARK: - isHmacReferencedElsewhere

    @Test("isHmacReferencedElsewhere returns true when other record uses the same blob")
    func isHmacReferencedElsewhereDetectsSharedBlob() async throws {
        let ctx = Self.makeFixture()
        let sharedHMAC = Data([0xAB, 0xCD])
        let selfRecord = try Self.persist(
            DocumentReferenceRecord(
                title: "Self",
                mimeType: "image/jpeg",
                fileSize: 1,
                contentHMAC: sharedHMAC
            ),
            in: ctx
        )
        _ = try Self.persist(
            DocumentReferenceRecord(
                title: "Other",
                mimeType: "image/jpeg",
                fileSize: 1,
                contentHMAC: sharedHMAC
            ),
            in: ctx
        )

        let referenced = try await ctx.service.isHmacReferencedElsewhere(
            contentHMAC: sharedHMAC,
            excludingRecordId: selfRecord.id,
            personId: ctx.personId,
            primaryKey: ctx.primaryKey
        )
        #expect(referenced == true)
    }

    @Test("isHmacReferencedElsewhere returns false when only the excluded record uses the blob")
    func isHmacReferencedElsewhereReturnsFalseWhenAlone() async throws {
        let ctx = Self.makeFixture()
        let sharedHMAC = Data([0xAB, 0xCD])
        let selfRecord = try Self.persist(
            DocumentReferenceRecord(
                title: "Lone",
                mimeType: "image/jpeg",
                fileSize: 1,
                contentHMAC: sharedHMAC
            ),
            in: ctx
        )

        let referenced = try await ctx.service.isHmacReferencedElsewhere(
            contentHMAC: sharedHMAC,
            excludingRecordId: selfRecord.id,
            personId: ctx.personId,
            primaryKey: ctx.primaryKey
        )
        #expect(referenced == false)
    }

    @Test("isHmacReferencedElsewhere returns false when no documents exist")
    func isHmacReferencedElsewhereNoDocuments() async throws {
        let ctx = Self.makeFixture()
        let referenced = try await ctx.service.isHmacReferencedElsewhere(
            contentHMAC: Data([0x99]),
            excludingRecordId: UUID(),
            personId: ctx.personId,
            primaryKey: ctx.primaryKey
        )
        #expect(referenced == false)
    }
}
