import CoreData
import CryptoKit
import Foundation
import Testing
@testable import FamilyMedicalApp

/// Extended tests for AttachmentRepository: fetchForRecord, unlinkFromRecord, linkCount, attachmentCountForRecord
/// Split from main test file to satisfy type_body_length limit
struct AttachmentRepositoryExtendedTests {
    // MARK: - Test Fixtures

    struct TestFixtures {
        let repository: AttachmentRepository
        let coreDataStack: MockCoreDataStack
        let encryptionService: MockEncryptionService
        let fmkService: MockFamilyMemberKeyService
    }

    func makeRepository() -> AttachmentRepository {
        let stack = MockCoreDataStack()
        let encryption = MockEncryptionService()
        let fmkService = MockFamilyMemberKeyService()
        return AttachmentRepository(
            coreDataStack: stack,
            encryptionService: encryption,
            fmkService: fmkService
        )
    }

    func makeRepositoryWithMocks() -> TestFixtures {
        let stack = MockCoreDataStack()
        let encryption = MockEncryptionService()
        let fmkService = MockFamilyMemberKeyService()
        let repo = AttachmentRepository(
            coreDataStack: stack,
            encryptionService: encryption,
            fmkService: fmkService
        )
        return TestFixtures(
            repository: repo,
            coreDataStack: stack,
            encryptionService: encryption,
            fmkService: fmkService
        )
    }

    func makeTestAttachment(
        id: UUID = UUID(),
        fileName: String = "test-file.jpg",
        mimeType: String = "image/jpeg"
    ) throws -> FamilyMedicalApp.Attachment {
        let contentHMAC = Data("test-hmac-\(id)".utf8)
        return try FamilyMedicalApp.Attachment(
            id: id,
            fileName: fileName,
            mimeType: mimeType,
            contentHMAC: contentHMAC,
            encryptedSize: 1_024,
            thumbnailData: Data("thumbnail".utf8),
            uploadedAt: Date(timeIntervalSince1970: 1_000_000_000)
        )
    }

    let testPrimaryKey = SymmetricKey(size: .bits256)
    let testPersonId = UUID()

    // MARK: - Fetch For Record Tests

    @Test
    func fetchForRecord_withLinkedAttachments_returnsAll() async throws {
        let fixtures = makeRepositoryWithMocks()
        let repo = fixtures.repository
        let fmkService = fixtures.fmkService
        let recordId = UUID()

        // Store FMK
        let fmk = SymmetricKey(size: .bits256)
        fmkService.storedFMKs[testPersonId.uuidString] = fmk

        // Create and save two attachments
        let attachment1 = try makeTestAttachment(id: UUID(), fileName: "file1.jpg")
        let attachment2 = try makeTestAttachment(id: UUID(), fileName: "file2.jpg")

        try await repo.save(attachment1, personId: testPersonId, primaryKey: testPrimaryKey)
        try await repo.save(attachment2, personId: testPersonId, primaryKey: testPrimaryKey)

        // Link both to the record
        try await repo.linkToRecord(attachmentId: attachment1.id, recordId: recordId)
        try await repo.linkToRecord(attachmentId: attachment2.id, recordId: recordId)

        // Fetch for record
        let attachments = try await repo.fetchForRecord(
            recordId: recordId,
            personId: testPersonId,
            primaryKey: testPrimaryKey
        )

        #expect(attachments.count == 2)
        let ids = attachments.map(\.id)
        #expect(ids.contains(attachment1.id))
        #expect(ids.contains(attachment2.id))
    }

    @Test
    func fetchForRecord_noLinks_returnsEmptyArray() async throws {
        let repo = makeRepository()
        let recordId = UUID()

        let attachments = try await repo.fetchForRecord(
            recordId: recordId,
            personId: testPersonId,
            primaryKey: testPrimaryKey
        )

        #expect(attachments.isEmpty)
    }

    @Test
    func fetchForRecord_onlyReturnsLinkedAttachments() async throws {
        let fixtures = makeRepositoryWithMocks()
        let repo = fixtures.repository
        let fmkService = fixtures.fmkService
        let recordId1 = UUID()
        let recordId2 = UUID()

        // Store FMK
        let fmk = SymmetricKey(size: .bits256)
        fmkService.storedFMKs[testPersonId.uuidString] = fmk

        // Create attachments
        let attachment1 = try makeTestAttachment(id: UUID(), fileName: "file1.jpg")
        let attachment2 = try makeTestAttachment(id: UUID(), fileName: "file2.jpg")

        try await repo.save(attachment1, personId: testPersonId, primaryKey: testPrimaryKey)
        try await repo.save(attachment2, personId: testPersonId, primaryKey: testPrimaryKey)

        // Link attachment1 to record1, attachment2 to record2
        try await repo.linkToRecord(attachmentId: attachment1.id, recordId: recordId1)
        try await repo.linkToRecord(attachmentId: attachment2.id, recordId: recordId2)

        // Fetch for record1 should only return attachment1
        let attachments = try await repo.fetchForRecord(
            recordId: recordId1,
            personId: testPersonId,
            primaryKey: testPrimaryKey
        )

        #expect(attachments.count == 1)
        #expect(attachments[0].id == attachment1.id)
    }

    // MARK: - Unlink From Record Tests

    @Test
    func unlinkFromRecord_existingLink_removesLink() async throws {
        let fixtures = makeRepositoryWithMocks()
        let repo = fixtures.repository
        let fmkService = fixtures.fmkService
        let stack = fixtures.coreDataStack
        let attachment = try makeTestAttachment()
        let recordId = UUID()

        // Store FMK
        let fmk = SymmetricKey(size: .bits256)
        fmkService.storedFMKs[testPersonId.uuidString] = fmk

        try await repo.save(attachment, personId: testPersonId, primaryKey: testPrimaryKey)
        try await repo.linkToRecord(attachmentId: attachment.id, recordId: recordId)

        // Verify link exists
        let context = stack.viewContext
        let request: NSFetchRequest<RecordAttachmentEntity> = RecordAttachmentEntity.fetchRequest()
        request.predicate = NSPredicate(
            format: "attachmentId == %@ AND recordId == %@",
            attachment.id as CVarArg,
            recordId as CVarArg
        )
        let linksBefore = try context.fetch(request)
        #expect(linksBefore.count == 1)

        // Unlink
        try await repo.unlinkFromRecord(attachmentId: attachment.id, recordId: recordId)

        // Verify link is removed
        let linksAfter = try context.fetch(request)
        #expect(linksAfter.isEmpty)
    }

    @Test
    func unlinkFromRecord_nonExistentLink_doesNotThrow() async throws {
        let repo = makeRepository()

        // Should not throw - idempotent operation
        try await repo.unlinkFromRecord(attachmentId: UUID(), recordId: UUID())
    }

    @Test
    func unlinkFromRecord_preservesAttachment() async throws {
        let fixtures = makeRepositoryWithMocks()
        let repo = fixtures.repository
        let fmkService = fixtures.fmkService
        let attachment = try makeTestAttachment()
        let recordId = UUID()

        // Store FMK
        let fmk = SymmetricKey(size: .bits256)
        fmkService.storedFMKs[testPersonId.uuidString] = fmk

        try await repo.save(attachment, personId: testPersonId, primaryKey: testPrimaryKey)
        try await repo.linkToRecord(attachmentId: attachment.id, recordId: recordId)

        // Unlink
        try await repo.unlinkFromRecord(attachmentId: attachment.id, recordId: recordId)

        // Attachment should still exist
        let exists = try await repo.exists(id: attachment.id)
        #expect(exists)
    }

    // MARK: - Link Count Tests

    @Test
    func linkCount_noLinks_returnsZero() async throws {
        let fixtures = makeRepositoryWithMocks()
        let repo = fixtures.repository
        let fmkService = fixtures.fmkService
        let attachment = try makeTestAttachment()

        // Store FMK
        let fmk = SymmetricKey(size: .bits256)
        fmkService.storedFMKs[testPersonId.uuidString] = fmk

        try await repo.save(attachment, personId: testPersonId, primaryKey: testPrimaryKey)

        let count = try await repo.linkCount(attachmentId: attachment.id)
        #expect(count == 0)
    }

    @Test
    func linkCount_multipleLinks_returnsCorrectCount() async throws {
        let fixtures = makeRepositoryWithMocks()
        let repo = fixtures.repository
        let fmkService = fixtures.fmkService
        let attachment = try makeTestAttachment()
        let recordId1 = UUID()
        let recordId2 = UUID()
        let recordId3 = UUID()

        // Store FMK
        let fmk = SymmetricKey(size: .bits256)
        fmkService.storedFMKs[testPersonId.uuidString] = fmk

        try await repo.save(attachment, personId: testPersonId, primaryKey: testPrimaryKey)

        // Link to multiple records
        try await repo.linkToRecord(attachmentId: attachment.id, recordId: recordId1)
        try await repo.linkToRecord(attachmentId: attachment.id, recordId: recordId2)
        try await repo.linkToRecord(attachmentId: attachment.id, recordId: recordId3)

        let count = try await repo.linkCount(attachmentId: attachment.id)
        #expect(count == 3)
    }

    @Test
    func linkCount_afterUnlink_decrements() async throws {
        let fixtures = makeRepositoryWithMocks()
        let repo = fixtures.repository
        let fmkService = fixtures.fmkService
        let attachment = try makeTestAttachment()
        let recordId1 = UUID()
        let recordId2 = UUID()

        // Store FMK
        let fmk = SymmetricKey(size: .bits256)
        fmkService.storedFMKs[testPersonId.uuidString] = fmk

        try await repo.save(attachment, personId: testPersonId, primaryKey: testPrimaryKey)
        try await repo.linkToRecord(attachmentId: attachment.id, recordId: recordId1)
        try await repo.linkToRecord(attachmentId: attachment.id, recordId: recordId2)

        #expect(try await repo.linkCount(attachmentId: attachment.id) == 2)

        try await repo.unlinkFromRecord(attachmentId: attachment.id, recordId: recordId1)

        #expect(try await repo.linkCount(attachmentId: attachment.id) == 1)
    }

    // MARK: - Attachment Count For Record Tests

    @Test
    func attachmentCountForRecord_noAttachments_returnsZero() async throws {
        let repo = makeRepository()
        let recordId = UUID()

        let count = try await repo.attachmentCountForRecord(recordId: recordId)
        #expect(count == 0)
    }

    @Test
    func attachmentCountForRecord_multipleAttachments_returnsCorrectCount() async throws {
        let fixtures = makeRepositoryWithMocks()
        let repo = fixtures.repository
        let fmkService = fixtures.fmkService
        let recordId = UUID()

        // Store FMK
        let fmk = SymmetricKey(size: .bits256)
        fmkService.storedFMKs[testPersonId.uuidString] = fmk

        // Create and link 3 attachments
        for index in 0 ..< 3 {
            let attachment = try makeTestAttachment(id: UUID(), fileName: "file\(index).jpg")
            try await repo.save(attachment, personId: testPersonId, primaryKey: testPrimaryKey)
            try await repo.linkToRecord(attachmentId: attachment.id, recordId: recordId)
        }

        let count = try await repo.attachmentCountForRecord(recordId: recordId)
        #expect(count == 3)
    }

    @Test
    func attachmentCountForRecord_afterUnlink_decrements() async throws {
        let fixtures = makeRepositoryWithMocks()
        let repo = fixtures.repository
        let fmkService = fixtures.fmkService
        let recordId = UUID()

        // Store FMK
        let fmk = SymmetricKey(size: .bits256)
        fmkService.storedFMKs[testPersonId.uuidString] = fmk

        // Create and link 2 attachments
        let attachment1 = try makeTestAttachment(id: UUID(), fileName: "file1.jpg")
        let attachment2 = try makeTestAttachment(id: UUID(), fileName: "file2.jpg")

        try await repo.save(attachment1, personId: testPersonId, primaryKey: testPrimaryKey)
        try await repo.save(attachment2, personId: testPersonId, primaryKey: testPrimaryKey)
        try await repo.linkToRecord(attachmentId: attachment1.id, recordId: recordId)
        try await repo.linkToRecord(attachmentId: attachment2.id, recordId: recordId)

        #expect(try await repo.attachmentCountForRecord(recordId: recordId) == 2)

        try await repo.unlinkFromRecord(attachmentId: attachment1.id, recordId: recordId)

        #expect(try await repo.attachmentCountForRecord(recordId: recordId) == 1)
    }
}
