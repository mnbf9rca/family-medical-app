import CryptoKit
import Foundation
import Testing
@testable import FamilyMedicalApp

struct AttachmentRepositoryTests {
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
        let contentHMAC = Data("test-hmac".utf8)
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

    // MARK: - Save Tests

    @Test
    func save_newAttachment_storesInCoreData() async throws {
        let fixtures = makeRepositoryWithMocks()
        let repo = fixtures.repository
        let fmkService = fixtures.fmkService
        let attachment = try makeTestAttachment()

        // Pre-store FMK for the person
        let fmk = SymmetricKey(size: .bits256)
        fmkService.storedFMKs[testPersonId.uuidString] = fmk

        try await repo.save(attachment, personId: testPersonId, primaryKey: testPrimaryKey)

        // Verify attachment was saved
        let fetched = try await repo.fetch(id: attachment.id, personId: testPersonId, primaryKey: testPrimaryKey)
        #expect(fetched != nil)
        #expect(fetched?.id == attachment.id)
        #expect(fetched?.fileName == attachment.fileName)
    }

    @Test
    func save_newAttachment_encryptsMetadata() async throws {
        let fixtures = makeRepositoryWithMocks()
        let repo = fixtures.repository
        let encryption = fixtures.encryptionService
        let fmkService = fixtures.fmkService
        let attachment = try makeTestAttachment()

        // Pre-store FMK
        let fmk = SymmetricKey(size: .bits256)
        fmkService.storedFMKs[testPersonId.uuidString] = fmk

        try await repo.save(attachment, personId: testPersonId, primaryKey: testPrimaryKey)

        // Encryption should be called for metadata
        #expect(encryption.encryptCalls.count == 1)
    }

    // MARK: - Fetch Tests

    @Test
    func fetch_existingAttachment_returnsDecrypted() async throws {
        let repo = makeRepository()
        let attachment = try makeTestAttachment()

        // Store FMK first
        let mockFMKService = MockFamilyMemberKeyService()
        let fmk = SymmetricKey(size: .bits256)
        mockFMKService.storedFMKs[testPersonId.uuidString] = fmk

        let repoWithMocks = AttachmentRepository(
            coreDataStack: MockCoreDataStack(),
            encryptionService: MockEncryptionService(),
            fmkService: mockFMKService
        )

        try await repoWithMocks.save(attachment, personId: testPersonId, primaryKey: testPrimaryKey)
        let fetched = try await repoWithMocks.fetch(
            id: attachment.id,
            personId: testPersonId,
            primaryKey: testPrimaryKey
        )

        #expect(fetched != nil)
        #expect(fetched?.id == attachment.id)
        #expect(fetched?.fileName == attachment.fileName)
        #expect(fetched?.mimeType == attachment.mimeType)
        #expect(fetched?.contentHMAC == attachment.contentHMAC)
        #expect(fetched?.encryptedSize == attachment.encryptedSize)
        #expect(fetched?.thumbnailData == attachment.thumbnailData)
    }

    @Test
    func fetch_nonExistentAttachment_returnsNil() async throws {
        let repo = makeRepository()

        let result = try await repo.fetch(id: UUID(), personId: testPersonId, primaryKey: testPrimaryKey)

        #expect(result == nil)
    }

    // MARK: - Find by Content HMAC Tests

    @Test
    func findByContentHMAC_existingAttachment_returnsId() async throws {
        let fixtures = makeRepositoryWithMocks()
        let repo = fixtures.repository
        let fmkService = fixtures.fmkService
        let attachment = try makeTestAttachment()

        // Store FMK
        let fmk = SymmetricKey(size: .bits256)
        fmkService.storedFMKs[testPersonId.uuidString] = fmk

        try await repo.save(attachment, personId: testPersonId, primaryKey: testPrimaryKey)

        let foundId = try await repo.findByContentHMAC(attachment.contentHMAC)

        #expect(foundId == attachment.id)
    }

    @Test
    func findByContentHMAC_nonExistent_returnsNil() async throws {
        let repo = makeRepository()
        let nonExistentHMAC = Data("nonexistent-hmac".utf8)

        let result = try await repo.findByContentHMAC(nonExistentHMAC)

        #expect(result == nil)
    }

    @Test
    func findByContentHMAC_duplicateContent_returnsSameId() async throws {
        let fixtures = makeRepositoryWithMocks()
        let repo = fixtures.repository
        let fmkService = fixtures.fmkService
        let sharedHMAC = Data("shared-hmac".utf8)

        // Store FMK
        let fmk = SymmetricKey(size: .bits256)
        fmkService.storedFMKs[testPersonId.uuidString] = fmk

        // Save attachment with specific HMAC
        let attachment = try FamilyMedicalApp.Attachment(
            fileName: "duplicate.jpg",
            mimeType: "image/jpeg",
            contentHMAC: sharedHMAC,
            encryptedSize: 1_024
        )

        try await repo.save(attachment, personId: testPersonId, primaryKey: testPrimaryKey)

        // Look up by HMAC
        let foundId = try await repo.findByContentHMAC(sharedHMAC)

        #expect(foundId == attachment.id)
    }

    // MARK: - Link to Record Tests

    @Test
    func linkToRecord_createsJoinTableEntry() async throws {
        let repo = makeRepository()
        let attachmentId = UUID()
        let recordId = UUID()

        try await repo.linkToRecord(attachmentId: attachmentId, recordId: recordId)

        // Since we can't directly query join table, we'll just verify no error was thrown
        // In real implementation, could add a method to check if link exists
    }

    @Test
    func linkToRecord_duplicateLink_doesNotThrow() async throws {
        let repo = makeRepository()
        let attachmentId = UUID()
        let recordId = UUID()

        // Create link twice
        try await repo.linkToRecord(attachmentId: attachmentId, recordId: recordId)
        try await repo.linkToRecord(attachmentId: attachmentId, recordId: recordId)

        // Should not throw - idempotent operation
    }

    // MARK: - Delete Tests

    @Test
    func delete_existingAttachment_removes() async throws {
        let fixtures = makeRepositoryWithMocks()
        let repo = fixtures.repository
        let fmkService = fixtures.fmkService
        let attachment = try makeTestAttachment()

        // Store FMK
        let fmk = SymmetricKey(size: .bits256)
        fmkService.storedFMKs[testPersonId.uuidString] = fmk

        try await repo.save(attachment, personId: testPersonId, primaryKey: testPrimaryKey)
        #expect(try await repo.exists(id: attachment.id))

        try await repo.delete(id: attachment.id)

        let exists = try await repo.exists(id: attachment.id)
        #expect(!exists)
    }

    @Test
    func delete_nonExistentAttachment_throwsError() async throws {
        let repo = makeRepository()

        await #expect(throws: RepositoryError.self) {
            try await repo.delete(id: UUID())
        }
    }

    // MARK: - Exists Tests

    @Test
    func exists_existingAttachment_returnsTrue() async throws {
        let fixtures = makeRepositoryWithMocks()
        let repo = fixtures.repository
        let fmkService = fixtures.fmkService
        let attachment = try makeTestAttachment()

        // Store FMK
        let fmk = SymmetricKey(size: .bits256)
        fmkService.storedFMKs[testPersonId.uuidString] = fmk

        try await repo.save(attachment, personId: testPersonId, primaryKey: testPrimaryKey)

        let exists = try await repo.exists(id: attachment.id)
        #expect(exists)
    }

    @Test
    func exists_nonExistentAttachment_returnsFalse() async throws {
        let repo = makeRepository()

        let exists = try await repo.exists(id: UUID())
        #expect(!exists)
    }
}
