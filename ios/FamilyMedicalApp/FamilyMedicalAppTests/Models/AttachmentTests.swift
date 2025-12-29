import Foundation
import Testing
@testable import FamilyMedicalApp

struct AttachmentTests {
    // MARK: - Valid Initialization

    @Test
    func init_validAttachment_succeeds() throws {
        let attachment = try Attachment(
            fileName: "vaccine-card.jpg",
            mimeType: "image/jpeg",
            contentHMAC: Data(repeating: 0x01, count: 32),
            encryptedSize: 1_024
        )

        #expect(attachment.fileName == "vaccine-card.jpg")
        #expect(attachment.mimeType == "image/jpeg")
        #expect(attachment.encryptedSize == 1_024)
    }

    // MARK: - FileName Validation

    @Test
    func init_emptyFileName_throwsError() {
        #expect(throws: ModelError.self) {
            _ = try Attachment(
                fileName: "",
                mimeType: "image/jpeg",
                contentHMAC: Data(),
                encryptedSize: 100
            )
        }
    }

    @Test
    func init_whitespaceFileName_throwsError() {
        #expect(throws: ModelError.self) {
            _ = try Attachment(
                fileName: "   ",
                mimeType: "image/jpeg",
                contentHMAC: Data(),
                encryptedSize: 100
            )
        }
    }

    @Test
    func init_fileNameTooLong_throwsError() {
        let longName = String(repeating: "a", count: Attachment.fileNameMaxLength + 1)
        #expect(throws: ModelError.self) {
            _ = try Attachment(
                fileName: longName,
                mimeType: "image/jpeg",
                contentHMAC: Data(),
                encryptedSize: 100
            )
        }
    }

    @Test
    func init_fileNameTrimsWhitespace() throws {
        let attachment = try Attachment(
            fileName: "  test.jpg  ",
            mimeType: "image/jpeg",
            contentHMAC: Data(),
            encryptedSize: 100
        )
        #expect(attachment.fileName == "test.jpg")
    }

    // MARK: - MIME Type Validation

    @Test
    func init_mimeTypeTooLong_throwsError() {
        let longMimeType = String(repeating: "a", count: Attachment.mimeTypeMaxLength + 1)
        #expect(throws: ModelError.self) {
            _ = try Attachment(
                fileName: "test.jpg",
                mimeType: longMimeType,
                contentHMAC: Data(),
                encryptedSize: 100
            )
        }
    }

    // MARK: - Size Validation

    @Test
    func init_negativeSizeThrowsError() {
        #expect(throws: ModelError.self) {
            _ = try Attachment(
                fileName: "test.jpg",
                mimeType: "image/jpeg",
                contentHMAC: Data(),
                encryptedSize: -1
            )
        }
    }

    @Test
    func init_zeroSize_succeeds() throws {
        let attachment = try Attachment(
            fileName: "empty.txt",
            mimeType: "text/plain",
            contentHMAC: Data(),
            encryptedSize: 0
        )
        #expect(attachment.encryptedSize == 0)
    }

    // MARK: - Helper Methods

    @Test
    func fileExtension_withExtension_returnsExtension() throws {
        let attachment = try Attachment(
            fileName: "document.pdf",
            mimeType: "application/pdf",
            contentHMAC: Data(),
            encryptedSize: 100
        )
        #expect(attachment.fileExtension == "pdf")
    }

    @Test
    func fileExtension_multipleDotsReturnsLast() throws {
        let attachment = try Attachment(
            fileName: "archive.tar.gz",
            mimeType: "application/gzip",
            contentHMAC: Data(),
            encryptedSize: 100
        )
        #expect(attachment.fileExtension == "gz")
    }

    @Test
    func fileExtension_noExtensionReturnsNil() throws {
        let attachment = try Attachment(
            fileName: "README",
            mimeType: "text/plain",
            contentHMAC: Data(),
            encryptedSize: 100
        )
        #expect(attachment.fileExtension == nil)
    }

    @Test
    func isImage_imageTypes_returnsTrue() throws {
        let jpgAttachment = try Attachment(
            fileName: "photo.jpg",
            mimeType: "image/jpeg",
            contentHMAC: Data(),
            encryptedSize: 100
        )
        #expect(jpgAttachment.isImage)

        let pngAttachment = try Attachment(
            fileName: "photo.png",
            mimeType: "image/png",
            contentHMAC: Data(),
            encryptedSize: 100
        )
        #expect(pngAttachment.isImage)
    }

    @Test
    func isImage_nonImageType_returnsFalse() throws {
        let attachment = try Attachment(
            fileName: "document.pdf",
            mimeType: "application/pdf",
            contentHMAC: Data(),
            encryptedSize: 100
        )
        #expect(!attachment.isImage)
    }

    @Test
    func isPDF_pdfType_returnsTrue() throws {
        let attachment = try Attachment(
            fileName: "document.pdf",
            mimeType: "application/pdf",
            contentHMAC: Data(),
            encryptedSize: 100
        )
        #expect(attachment.isPDF)
    }

    @Test
    func isPDF_nonPDFType_returnsFalse() throws {
        let attachment = try Attachment(
            fileName: "photo.jpg",
            mimeType: "image/jpeg",
            contentHMAC: Data(),
            encryptedSize: 100
        )
        #expect(!attachment.isPDF)
    }

    @Test
    func fileSizeFormatted_returnsReadableString() throws {
        let attachment = try Attachment(
            fileName: "large-file.bin",
            mimeType: "application/octet-stream",
            contentHMAC: Data(),
            encryptedSize: 1_048_576 // 1 MB
        )
        #expect(!attachment.fileSizeFormatted.isEmpty)
    }

    // MARK: - Codable

    @Test
    func codable_roundTrip() throws {
        let original = try Attachment(
            id: UUID(),
            fileName: "test-document.pdf",
            mimeType: "application/pdf",
            contentHMAC: Data(repeating: 0x42, count: 32),
            encryptedSize: 2_048,
            thumbnailData: Data(repeating: 0xFF, count: 100),
            uploadedAt: Date(timeIntervalSince1970: 1_000_000)
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Attachment.self, from: encoded)

        #expect(decoded == original)
        #expect(decoded.fileName == original.fileName)
        #expect(decoded.contentHMAC == original.contentHMAC)
    }

    // MARK: - Equatable

    @Test
    func equatable_sameAttachment_equal() throws {
        let id = UUID()
        let now = Date()
        let attachment1 = try Attachment(
            id: id,
            fileName: "test.jpg",
            mimeType: "image/jpeg",
            contentHMAC: Data(),
            encryptedSize: 100,
            uploadedAt: now
        )
        let attachment2 = try Attachment(
            id: id,
            fileName: "test.jpg",
            mimeType: "image/jpeg",
            contentHMAC: Data(),
            encryptedSize: 100,
            uploadedAt: now
        )
        #expect(attachment1 == attachment2)
    }

    @Test
    func equatable_differentAttachment_notEqual() throws {
        let attachment1 = try Attachment(
            fileName: "test1.jpg",
            mimeType: "image/jpeg",
            contentHMAC: Data(),
            encryptedSize: 100
        )
        let attachment2 = try Attachment(
            fileName: "test2.jpg",
            mimeType: "image/jpeg",
            contentHMAC: Data(),
            encryptedSize: 100
        )
        #expect(attachment1 != attachment2)
    }
}
