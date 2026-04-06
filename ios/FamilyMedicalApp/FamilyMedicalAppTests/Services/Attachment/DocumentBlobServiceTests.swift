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

    /// Minimal valid PDF that PDFDocument(data:) accepts.
    private static func makePDF() -> Data {
        let pdfString = """
        %PDF-1.0
        1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj
        2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj
        3 0 obj<</Type/Page/MediaBox[0 0 612 792]/Parent 2 0 R>>endobj
        xref
        0 4
        0000000000 65535 f\u{0020}
        0000000009 00000 n\u{0020}
        0000000058 00000 n\u{0020}
        0000000115 00000 n\u{0020}
        trailer<</Size 4/Root 1 0 R>>
        startxref
        190
        %%EOF
        """
        return Data(pdfString.utf8)
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
        #expect(ctx.imageProcessor.validateCalls.count == 1)
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
        #expect(ctx.imageProcessor.validateCalls.isEmpty)
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

    @Test("store rejects oversized image files")
    func storeRejectsOversizedImageFile() async throws {
        let ctx = Self.makeFixture()
        let tooBig = Data([0xFF, 0xD8, 0xFF, 0xE0]) + Data(count: DocumentBlobService.maxFileSizeBytes)
        await #expect(throws: ModelError.self) {
            _ = try await ctx.service.store(
                plaintext: tooBig,
                mimeType: "image/jpeg",
                personId: ctx.personId,
                primaryKey: ctx.primaryKey
            )
        }
    }

    @Test("store rejects oversized PDF files")
    func storeRejectsOversizedPDFFile() async throws {
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

    @Test("store preserves original image bytes without re-encoding")
    func storePreservesOriginalBytes() async throws {
        let ctx = Self.makeFixture()
        let originalData = Self.makeJPEG()
        _ = try await ctx.service.store(
            plaintext: originalData,
            mimeType: "image/jpeg",
            personId: ctx.personId,
            primaryKey: ctx.primaryKey
        )
        // The encrypted call should receive the original data, not re-encoded data
        #expect(ctx.encryption.encryptCalls.count == 1)
        #expect(ctx.encryption.encryptCalls.first?.data == originalData)
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

    @Test("store validates image via CGImageSource path for image/* MIME")
    func storeValidatesImageForImageMime() async throws {
        let ctx = Self.makeFixture()
        ctx.imageProcessor.validateResult = "image/heic"
        _ = try await ctx.service.store(
            plaintext: Self.makeJPEG(),
            mimeType: "image/heic",
            personId: ctx.personId,
            primaryKey: ctx.primaryKey
        )
        #expect(ctx.imageProcessor.validateCalls.count == 1)
    }

    @Test("store routes image data with wrong MIME to image path via header detection")
    func storeDetectsImageDataEvenWithWrongMime() async throws {
        let ctx = Self.makeFixture()
        // JPEG bytes but mimeType says "application/octet-stream"
        // isImageData() will detect the JPEG header and route to image path
        _ = try await ctx.service.store(
            plaintext: Self.makeJPEG(),
            mimeType: "application/octet-stream",
            personId: ctx.personId,
            primaryKey: ctx.primaryKey
        )
        #expect(ctx.imageProcessor.validateCalls.count == 1)
        #expect(ctx.imageProcessor.thumbnailCalls.count == 1)
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
        // Original bytes are stored unchanged, so round-trip equals the original.
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
