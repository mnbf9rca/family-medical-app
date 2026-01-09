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

        // Use find() for deterministic coverage - verify Button and ZStack render
        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.Button.self)
        _ = try inspected.find(ViewType.ZStack.self)
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

        // With thumbnail data, should render Image
        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.Button.self)
        _ = try inspected.find(ViewType.Image.self)
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

        // Custom size still renders the same structure
        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.Button.self)
        _ = try inspected.find(ViewType.ZStack.self)
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

        // JPEG without thumbnail shows image icon and extension text
        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.Image.self)
        _ = try inspected.find(text: "JPG")
    }

    @Test
    func pngAttachment_showsImageThumbnail() throws {
        let attachment = try makeTestAttachment(fileName: "photo.png", mimeType: "image/png")
        let view = AttachmentThumbnailView(
            attachment: attachment,
            onTap: {},
            onRemove: nil
        )

        // PNG without thumbnail shows image icon and extension text
        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.Image.self)
        _ = try inspected.find(text: "PNG")
    }

    @Test
    func pdfAttachment_showsDocumentIcon() throws {
        let attachment = try makeTestAttachment(fileName: "document.pdf", mimeType: "application/pdf")
        let view = AttachmentThumbnailView(
            attachment: attachment,
            onTap: {},
            onRemove: nil
        )

        // PDF shows doc icon and extension text
        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.Image.self)
        _ = try inspected.find(text: "PDF")
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

        // Verify view renders with tap callback set
        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.Button.self)
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

        // With remove callback, there should be 2 buttons (tap + remove)
        let inspected = try view.inspect()
        let buttons = inspected.findAll(ViewType.Button.self)
        #expect(buttons.count == 2)
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

        // With both callbacks, should have 2 buttons
        let inspected = try view.inspect()
        let buttons = inspected.findAll(ViewType.Button.self)
        #expect(buttons.count == 2)
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

        // With remove callback, should have 2 buttons
        let inspected = try view.inspect()
        let buttons = inspected.findAll(ViewType.Button.self)
        #expect(buttons.count == 2)
    }

    @Test
    func viewWithoutRemoveCallback_hidesRemoveButton() throws {
        let attachment = try makeTestAttachment()

        let view = AttachmentThumbnailView(
            attachment: attachment,
            onTap: {},
            onRemove: nil // No remove callback
        )

        // Without remove callback, should only have 1 button (main tap)
        let inspected = try view.inspect()
        let buttons = inspected.findAll(ViewType.Button.self)
        #expect(buttons.count == 1)
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

        // With thumbnail data, Image is rendered
        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.Image.self)
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

        // Without thumbnail, shows fallback icon with extension
        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.Image.self)
        _ = try inspected.find(text: "JPG")
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

        // PDF shows doc icon with PDF extension
        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.Image.self)
        _ = try inspected.find(text: "PDF")
    }
}
