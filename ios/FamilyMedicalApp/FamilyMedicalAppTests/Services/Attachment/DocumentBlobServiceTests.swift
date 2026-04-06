import CryptoKit
import Foundation
import Testing
@testable import FamilyMedicalApp

@Suite("DocumentBlobService Tests")
struct DocumentBlobServiceTests {
    // MARK: - Fixtures

    private struct Fixture {
        let service: DocumentBlobService
        let fileStorage: MockDocumentFileStorageService
        let imageProcessor: MockImageProcessingService
        let encryption: MockEncryptionService
        let fmkService: MockFamilyMemberKeyService
        let personId: UUID
        let primaryKey: SymmetricKey
    }

    private static func makeFixture() -> Fixture {
        let fileStorage = MockDocumentFileStorageService()
        let imageProcessor = MockImageProcessingService()
        let encryption = MockEncryptionService()
        let fmkService = MockFamilyMemberKeyService()
        let personId = UUID()
        let primaryKey = SymmetricKey(size: .bits256)
        let fmk = SymmetricKey(size: .bits256)
        fmkService.setFMK(fmk, for: personId.uuidString)
        let service = DocumentBlobService(
            fileStorage: fileStorage,
            imageProcessor: imageProcessor,
            encryptionService: encryption,
            fmkService: fmkService
        )
        return Fixture(
            service: service,
            fileStorage: fileStorage,
            imageProcessor: imageProcessor,
            encryption: encryption,
            fmkService: fmkService,
            personId: personId,
            primaryKey: primaryKey
        )
    }

    private static func makeJPEG() -> Data {
        Data([0xFF, 0xD8, 0xFF, 0xE0] + Array(repeating: UInt8(0), count: 128))
    }

    private static func makePDF() -> Data {
        Data("%PDF-1.4\n".utf8) + Data(repeating: 0, count: 128)
    }

    // MARK: - store

    @Test("store encrypts plaintext and writes blob keyed by HMAC")
    func storeWritesBlob() async throws {
        let ctx = Self.makeFixture()
        let result = try await ctx.service.store(
            plaintext: Self.makeJPEG(),
            mimeType: "image/jpeg",
            personId: ctx.personId,
            primaryKey: ctx.primaryKey
        )
        #expect(!result.contentHMAC.isEmpty)
        #expect(result.encryptedSize > 0)
        #expect(ctx.encryption.encryptCalls.count == 1)
        #expect(ctx.fileStorage.storeCalls.count == 1)
        #expect(ctx.fileStorage.storeCalls.first?.contentHMAC == result.contentHMAC)
    }

    @Test("store generates thumbnail for image MIME types")
    func storeGeneratesThumbnailForImages() async throws {
        let ctx = Self.makeFixture()
        let result = try await ctx.service.store(
            plaintext: Self.makeJPEG(),
            mimeType: "image/jpeg",
            personId: ctx.personId,
            primaryKey: ctx.primaryKey
        )
        #expect(result.thumbnailData != nil)
        #expect(ctx.imageProcessor.compressCalls.count == 1)
        #expect(ctx.imageProcessor.thumbnailCalls.count == 1)
    }

    @Test("store skips thumbnail for PDFs")
    func storeSkipsThumbnailForPDF() async throws {
        let ctx = Self.makeFixture()
        let result = try await ctx.service.store(
            plaintext: Self.makePDF(),
            mimeType: "application/pdf",
            personId: ctx.personId,
            primaryKey: ctx.primaryKey
        )
        #expect(result.thumbnailData == nil)
        #expect(ctx.imageProcessor.compressCalls.isEmpty)
        #expect(ctx.imageProcessor.thumbnailCalls.isEmpty)
    }

    @Test("store rejects unsupported MIME types")
    func storeRejectsUnsupportedMimeType() async throws {
        let ctx = Self.makeFixture()
        await #expect(throws: ModelError.self) {
            _ = try await ctx.service.store(
                plaintext: Data([0x00]),
                mimeType: "application/exe",
                personId: ctx.personId,
                primaryKey: ctx.primaryKey
            )
        }
    }

    @Test("store rejects oversized non-image files")
    func storeRejectsOversizedFile() async throws {
        let ctx = Self.makeFixture()
        let tooBig = Data(count: DocumentBlobService.maxFileSizeBytes + 1)
        await #expect(throws: ModelError.self) {
            _ = try await ctx.service.store(
                plaintext: tooBig,
                mimeType: "application/pdf",
                personId: ctx.personId,
                primaryKey: ctx.primaryKey
            )
        }
    }

    @Test("store does not rewrite blob when HMAC already on disk (dedup)")
    func storeDedupsExistingBlob() async throws {
        let ctx = Self.makeFixture()
        // First store
        let first = try await ctx.service.store(
            plaintext: Self.makePDF(),
            mimeType: "application/pdf",
            personId: ctx.personId,
            primaryKey: ctx.primaryKey
        )
        #expect(ctx.fileStorage.storeCalls.count == 1)
        // Second store of identical bytes — should dedupe (no second write)
        _ = try await ctx.service.store(
            plaintext: Self.makePDF(),
            mimeType: "application/pdf",
            personId: ctx.personId,
            primaryKey: ctx.primaryKey
        )
        // Storage write count should not increase because the file already exists.
        #expect(ctx.fileStorage.storeCalls.count == 1)
        #expect(ctx.fileStorage.existsCalls.count >= 1)
        // Encryption still only ran once
        #expect(ctx.encryption.encryptCalls.count == 1)
        #expect(first.contentHMAC == ctx.fileStorage.storeCalls.first?.contentHMAC)
    }

    // MARK: - retrieve

    @Test("retrieve returns decrypted bytes for known HMAC")
    func retrieveReturnsPlaintext() async throws {
        let ctx = Self.makeFixture()
        let original = Self.makeJPEG()
        let stored = try await ctx.service.store(
            plaintext: original,
            mimeType: "image/jpeg",
            personId: ctx.personId,
            primaryKey: ctx.primaryKey
        )
        let decrypted = try await ctx.service.retrieve(
            contentHMAC: stored.contentHMAC,
            personId: ctx.personId,
            primaryKey: ctx.primaryKey
        )
        #expect(ctx.encryption.decryptCalls.count == 1)
        #expect(ctx.fileStorage.retrieveCalls.count == 1)
        #expect(ctx.fileStorage.retrieveCalls.first == stored.contentHMAC)
        // The MockImageProcessingService returns the input unchanged when compressResult is nil,
        // so the round-trip should equal the original plaintext.
        #expect(decrypted == original)
    }

    @Test("retrieve throws when blob is missing from storage")
    func retrieveThrowsWhenMissing() async throws {
        let ctx = Self.makeFixture()
        await #expect(throws: ModelError.self) {
            _ = try await ctx.service.retrieve(
                contentHMAC: Data([0xFF, 0xEE, 0xDD]),
                personId: ctx.personId,
                primaryKey: ctx.primaryKey
            )
        }
    }

    @Test("retrieve surfaces documentContentCorrupted when decryption fails")
    func retrieveCorruptedBlob() async throws {
        let ctx = Self.makeFixture()
        // Seed storage with arbitrary "encrypted" bytes the mock encryption does not know
        ctx.fileStorage.addTestData(Data([0x01, 0x02, 0x03]), forHMAC: Data([0xBE, 0xEF]))
        await #expect(throws: ModelError.self) {
            _ = try await ctx.service.retrieve(
                contentHMAC: Data([0xBE, 0xEF]),
                personId: ctx.personId,
                primaryKey: ctx.primaryKey
            )
        }
    }

    // MARK: - deleteIfUnreferenced

    @Test("deleteIfUnreferenced removes blob when no records reference it")
    func deleteIfUnreferencedDeletesOrphan() async throws {
        let ctx = Self.makeFixture()
        try await ctx.service.deleteIfUnreferenced(
            contentHMAC: Data([0xAB, 0xCD]),
            isReferencedElsewhere: false
        )
        #expect(ctx.fileStorage.deleteCalls.count == 1)
        #expect(ctx.fileStorage.deleteCalls.first == Data([0xAB, 0xCD]))
    }

    @Test("deleteIfUnreferenced keeps blob when other records reference it")
    func deleteIfUnreferencedKeepsSharedBlob() async throws {
        let ctx = Self.makeFixture()
        try await ctx.service.deleteIfUnreferenced(
            contentHMAC: Data([0xAB, 0xCD]),
            isReferencedElsewhere: true
        )
        #expect(ctx.fileStorage.deleteCalls.isEmpty)
    }
}
