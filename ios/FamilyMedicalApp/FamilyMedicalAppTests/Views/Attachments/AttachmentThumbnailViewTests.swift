import SwiftUI
import Testing
import UIKit
import ViewInspector
@testable import FamilyMedicalApp

@MainActor
struct AttachmentThumbnailViewTests {
    // MARK: - Test Fixtures

    func makeTestAttachment(
        fileName: String = "test.jpg",
        mimeType: String = "image/jpeg",
        thumbnailData: Data? = nil
    ) throws -> FamilyMedicalApp.Attachment {
        try FamilyMedicalApp.Attachment(
            id: UUID(),
            fileName: fileName,
            mimeType: mimeType,
            contentHMAC: Data(repeating: UInt8.random(in: 0 ... 255), count: 32),
            encryptedSize: 1_024,
            thumbnailData: thumbnailData,
            uploadedAt: Date()
        )
    }

    func makeTestThumbnailData() -> Data {
        let size = CGSize(width: 50, height: 50)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            UIColor.blue.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
        // swiftlint:disable:next force_unwrapping
        return image.jpegData(compressionQuality: 0.5)!
    }

    // MARK: - Basic Rendering Tests

    @Test
    func viewRendersSuccessfully() throws {
        let attachment = try makeTestAttachment()
        let view = AttachmentThumbnailView(
            attachment: attachment,
            onTap: {},
            onRemove: nil
        )

        _ = try view.inspect()
    }

    @Test
    func viewRendersWithThumbnailData() throws {
        let thumbnailData = makeTestThumbnailData()
        let attachment = try makeTestAttachment(thumbnailData: thumbnailData)

        let view = AttachmentThumbnailView(
            attachment: attachment,
            onTap: {},
            onRemove: nil
        )

        _ = try view.inspect()
    }

    @Test
    func viewRendersWithCustomSize() throws {
        let attachment = try makeTestAttachment()
        let view = AttachmentThumbnailView(
            attachment: attachment,
            onTap: {},
            onRemove: nil,
            size: 100
        )

        _ = try view.inspect()
    }

    // MARK: - MIME Type Icon Tests

    @Test
    func jpegAttachment_showsImageThumbnail() throws {
        let attachment = try makeTestAttachment(mimeType: "image/jpeg")
        let view = AttachmentThumbnailView(
            attachment: attachment,
            onTap: {},
            onRemove: nil
        )

        _ = try view.inspect()
    }

    @Test
    func pngAttachment_showsImageThumbnail() throws {
        let attachment = try makeTestAttachment(fileName: "photo.png", mimeType: "image/png")
        let view = AttachmentThumbnailView(
            attachment: attachment,
            onTap: {},
            onRemove: nil
        )

        _ = try view.inspect()
    }

    @Test
    func pdfAttachment_showsDocumentIcon() throws {
        let attachment = try makeTestAttachment(fileName: "document.pdf", mimeType: "application/pdf")
        let view = AttachmentThumbnailView(
            attachment: attachment,
            onTap: {},
            onRemove: nil
        )

        _ = try view.inspect()
    }

    // MARK: - Callback Tests

    @Test
    func viewWithTapCallback_rendersSuccessfully() throws {
        var tapped = false
        let attachment = try makeTestAttachment()

        let view = AttachmentThumbnailView(
            attachment: attachment,
            onTap: { tapped = true },
            onRemove: nil
        )

        _ = try view.inspect()
        #expect(!tapped) // Not tapped yet
    }

    @Test
    func viewWithRemoveCallback_rendersSuccessfully() throws {
        var removed = false
        let attachment = try makeTestAttachment()

        let view = AttachmentThumbnailView(
            attachment: attachment,
            onTap: {},
            onRemove: { removed = true }
        )

        _ = try view.inspect()
        #expect(!removed) // Not removed yet
    }

    @Test
    func viewWithBothCallbacks_rendersSuccessfully() throws {
        var tapped = false
        var removed = false
        let attachment = try makeTestAttachment()

        let view = AttachmentThumbnailView(
            attachment: attachment,
            onTap: { tapped = true },
            onRemove: { removed = true }
        )

        _ = try view.inspect()
        #expect(!tapped)
        #expect(!removed)
    }

    // MARK: - Remove Button Tests

    @Test
    func viewWithRemoveCallback_showsRemoveButton() throws {
        let attachment = try makeTestAttachment()

        let view = AttachmentThumbnailView(
            attachment: attachment,
            onTap: {},
            onRemove: {}
        )

        // View should render with remove button overlay
        _ = try view.inspect()
    }

    @Test
    func viewWithoutRemoveCallback_hidesRemoveButton() throws {
        let attachment = try makeTestAttachment()

        let view = AttachmentThumbnailView(
            attachment: attachment,
            onTap: {},
            onRemove: nil // No remove callback
        )

        _ = try view.inspect()
    }

    // MARK: - Thumbnail Content Tests

    @Test
    func imageWithThumbnail_displaysImage() throws {
        let thumbnailData = makeTestThumbnailData()
        let attachment = try makeTestAttachment(
            fileName: "photo.jpg",
            mimeType: "image/jpeg",
            thumbnailData: thumbnailData
        )

        let view = AttachmentThumbnailView(
            attachment: attachment,
            onTap: {},
            onRemove: nil
        )

        _ = try view.inspect()
    }

    @Test
    func imageWithoutThumbnail_showsFallbackIcon() throws {
        let attachment = try makeTestAttachment(
            fileName: "photo.jpg",
            mimeType: "image/jpeg",
            thumbnailData: nil
        )

        let view = AttachmentThumbnailView(
            attachment: attachment,
            onTap: {},
            onRemove: nil
        )

        _ = try view.inspect()
    }

    @Test
    func pdfAttachment_showsDocIcon() throws {
        let attachment = try makeTestAttachment(
            fileName: "report.pdf",
            mimeType: "application/pdf",
            thumbnailData: nil
        )

        let view = AttachmentThumbnailView(
            attachment: attachment,
            onTap: {},
            onRemove: nil
        )

        _ = try view.inspect()
    }
}
