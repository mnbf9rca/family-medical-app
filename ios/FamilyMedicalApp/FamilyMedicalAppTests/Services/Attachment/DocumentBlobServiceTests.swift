import CryptoKit
import Foundation
import Testing
import UIKit
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

    /// Real, CGImageSource-decodable JPEG bytes. The service uses content-based detection
    /// via CGImageSource, so test fixtures cannot rely on a hand-rolled SOI marker — the
    /// sniffer would reject it. A 10×10 UIGraphicsImageRenderer frame is cheap to build
    /// and always yields a valid JPEG header plus body.
    private static func makeJPEG() -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10))
        let image = renderer.image { ctx in
            UIColor.blue.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 10, height: 10))
        }
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            fatalError("UIGraphicsImageRenderer failed to produce JPEG bytes")
        }
        return data
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
            personId: ctx.personId,
            primaryKey: ctx.primaryKey
        )
        #expect(!result.contentHMAC.isEmpty)
        #expect(result.encryptedSize > 0)
        #expect(ctx.encryption.encryptCalls.count == 1)
        #expect(ctx.fileStorage.storeCalls.count == 1)
        #expect(ctx.fileStorage.storeCalls.first?.contentHMAC == result.contentHMAC)
    }

    @Test("store generates thumbnail for image content")
    func storeGeneratesThumbnailForImages() async throws {
        let ctx = Self.makeFixture()
        let result = try await ctx.service.store(
            plaintext: Self.makeJPEG(),
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
            personId: ctx.personId,
            primaryKey: ctx.primaryKey
        )
        #expect(result.thumbnailData == nil)
        #expect(ctx.imageProcessor.validateCalls.isEmpty)
        #expect(ctx.imageProcessor.thumbnailCalls.isEmpty)
    }

    @Test("store rejects content that is neither a valid image nor a PDF")
    func storeRejectsUnsupportedContent() async throws {
        let ctx = Self.makeFixture()
        // Bytes that do not start with %PDF-. In production, CGImageSource
        // would reject arbitrary bytes inside ImageProcessingService.validateImage;
        // we mirror that by flipping shouldFailValidate on the mock so the
        // single-pass image probe in DocumentBlobService.process throws and
        // is re-thrown as ModelError.unsupportedContent.
        ctx.imageProcessor.shouldFailValidate = true
        let arbitrary = Data([0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07])
        await #expect(throws: ModelError.self) {
            _ = try await ctx.service.store(
                plaintext: arbitrary,
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
            personId: ctx.personId,
            primaryKey: ctx.primaryKey
        )
        #expect(ctx.fileStorage.storeCalls.count == 1)
        // Second store of identical bytes — should dedupe (no second write)
        _ = try await ctx.service.store(
            plaintext: Self.makePDF(),
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

    @Test("store validates image via CGImageSource and reports the detected MIME")
    func storeValidatesImageViaCGImageSource() async throws {
        let ctx = Self.makeFixture()
        ctx.imageProcessor.validateResult = "image/heic"
        let result = try await ctx.service.store(
            plaintext: Self.makeJPEG(),
            personId: ctx.personId,
            primaryKey: ctx.primaryKey
        )
        #expect(ctx.imageProcessor.validateCalls.count == 1)
        #expect(result.detectedMimeType == "image/heic")
    }

    // MARK: - retrieve

    @Test("retrieve returns decrypted bytes for known HMAC")
    func retrieveReturnsPlaintext() async throws {
        let ctx = Self.makeFixture()
        let original = Self.makeJPEG()
        let stored = try await ctx.service.store(
            plaintext: original,
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
        #expect(ctx.fileStorage.retrieveCalls.first?.contentHMAC == stored.contentHMAC)
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
        ctx.fileStorage.addTestData(Data([0x01, 0x02, 0x03]), forHMAC: Data([0xBE, 0xEF]), personId: ctx.personId)
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
        #expect(ctx.fileStorage.deleteCalls.first?.contentHMAC == Data([0xAB, 0xCD]))
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
