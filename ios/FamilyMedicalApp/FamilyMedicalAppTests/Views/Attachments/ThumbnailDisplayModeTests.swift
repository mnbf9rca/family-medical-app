import Foundation
import Testing
@testable import FamilyMedicalApp

struct ThumbnailDisplayModeTests {
    // MARK: - Test Helpers

    func makeAttachment(
        thumbnailData: Data? = nil,
        mimeType: String = "image/jpeg"
    ) throws -> FamilyMedicalApp.Attachment {
        try FamilyMedicalApp.Attachment(
            id: UUID(),
            fileName: "test.jpg",
            mimeType: mimeType,
            contentHMAC: Data(repeating: 0x42, count: 32),
            encryptedSize: 1_024,
            thumbnailData: thumbnailData,
            uploadedAt: Date()
        )
    }

    // MARK: - from() Tests

    @Test
    func from_withThumbnailData_returnsThumbnail() throws {
        let thumbnailData = Data([0x01, 0x02, 0x03])
        let attachment = try makeAttachment(thumbnailData: thumbnailData)

        let mode = ThumbnailDisplayMode.from(attachment)

        #expect(mode == .thumbnail(thumbnailData))
    }

    @Test
    func from_withEmptyThumbnailData_doesNotReturnThumbnail() throws {
        let attachment = try makeAttachment(thumbnailData: Data())

        let mode = ThumbnailDisplayMode.from(attachment)

        #expect(mode != .thumbnail(Data()))
    }

    @Test
    func from_pdfWithoutThumbnail_returnsPdfIcon() throws {
        let attachment = try makeAttachment(mimeType: "application/pdf")

        let mode = ThumbnailDisplayMode.from(attachment)

        #expect(mode == .pdfIcon)
    }

    @Test
    func from_imageWithoutThumbnail_returnsImageIcon() throws {
        let attachment = try makeAttachment(mimeType: "image/jpeg")

        let mode = ThumbnailDisplayMode.from(attachment)

        #expect(mode == .imageIcon)
    }

    @Test
    func from_pngImageWithoutThumbnail_returnsImageIcon() throws {
        let attachment = try makeAttachment(mimeType: "image/png")

        let mode = ThumbnailDisplayMode.from(attachment)

        #expect(mode == .imageIcon)
    }

    @Test
    func from_unknownTypeWithoutThumbnail_returnsGenericFileIcon() throws {
        let attachment = try makeAttachment(mimeType: "text/plain")

        let mode = ThumbnailDisplayMode.from(attachment)

        #expect(mode == .genericFileIcon)
    }

    @Test
    func from_thumbnailTakesPrecedenceOverMimeType() throws {
        // Even if it's a PDF, thumbnail data should take precedence
        let thumbnailData = Data([0xFF, 0xD8]) // JPEG magic bytes
        let attachment = try FamilyMedicalApp.Attachment(
            id: UUID(),
            fileName: "document.pdf",
            mimeType: "application/pdf",
            contentHMAC: Data(repeating: 0x42, count: 32),
            encryptedSize: 1_024,
            thumbnailData: thumbnailData,
            uploadedAt: Date()
        )

        let mode = ThumbnailDisplayMode.from(attachment)

        #expect(mode == .thumbnail(thumbnailData))
    }

    // MARK: - systemImageName Tests

    @Test
    func systemImageName_pdfIcon_returnsDocFill() {
        let mode = ThumbnailDisplayMode.pdfIcon

        #expect(mode.systemImageName == "doc.fill")
    }

    @Test
    func systemImageName_imageIcon_returnsPhotoFill() {
        let mode = ThumbnailDisplayMode.imageIcon

        #expect(mode.systemImageName == "photo.fill")
    }

    @Test
    func systemImageName_genericFileIcon_returnsDocFill() {
        let mode = ThumbnailDisplayMode.genericFileIcon

        #expect(mode.systemImageName == "doc.fill")
    }

    @Test
    func systemImageName_thumbnail_returnsPhoto() {
        let mode = ThumbnailDisplayMode.thumbnail(Data())

        #expect(mode.systemImageName == "photo")
    }

    // MARK: - iconColorName Tests

    @Test
    func iconColorName_pdfIcon_returnsRed() {
        let mode = ThumbnailDisplayMode.pdfIcon

        #expect(mode.iconColorName == "red")
    }

    @Test
    func iconColorName_imageIcon_returnsBlue() {
        let mode = ThumbnailDisplayMode.imageIcon

        #expect(mode.iconColorName == "blue")
    }

    @Test
    func iconColorName_genericFileIcon_returnsGray() {
        let mode = ThumbnailDisplayMode.genericFileIcon

        #expect(mode.iconColorName == "gray")
    }

    @Test
    func iconColorName_thumbnail_returnsClear() {
        let mode = ThumbnailDisplayMode.thumbnail(Data())

        #expect(mode.iconColorName == "clear")
    }

    // MARK: - hasThumbnailImage Tests

    @Test
    func hasThumbnailImage_thumbnail_returnsTrue() {
        let mode = ThumbnailDisplayMode.thumbnail(Data([0x01]))

        #expect(mode.hasThumbnailImage)
    }

    @Test
    func hasThumbnailImage_pdfIcon_returnsFalse() {
        let mode = ThumbnailDisplayMode.pdfIcon

        #expect(!mode.hasThumbnailImage)
    }

    @Test
    func hasThumbnailImage_imageIcon_returnsFalse() {
        let mode = ThumbnailDisplayMode.imageIcon

        #expect(!mode.hasThumbnailImage)
    }

    @Test
    func hasThumbnailImage_genericFileIcon_returnsFalse() {
        let mode = ThumbnailDisplayMode.genericFileIcon

        #expect(!mode.hasThumbnailImage)
    }

    // MARK: - Equatable Tests

    @Test
    func equatable_sameThumbnailData_areEqual() {
        let data = Data([0x01, 0x02, 0x03])
        let mode1 = ThumbnailDisplayMode.thumbnail(data)
        let mode2 = ThumbnailDisplayMode.thumbnail(data)

        #expect(mode1 == mode2)
    }

    @Test
    func equatable_differentThumbnailData_areNotEqual() {
        let mode1 = ThumbnailDisplayMode.thumbnail(Data([0x01]))
        let mode2 = ThumbnailDisplayMode.thumbnail(Data([0x02]))

        #expect(mode1 != mode2)
    }

    @Test
    func equatable_differentModes_areNotEqual() {
        #expect(ThumbnailDisplayMode.pdfIcon != ThumbnailDisplayMode.imageIcon)
        #expect(ThumbnailDisplayMode.imageIcon != ThumbnailDisplayMode.genericFileIcon)
        #expect(ThumbnailDisplayMode.pdfIcon != ThumbnailDisplayMode.genericFileIcon)
    }
}
