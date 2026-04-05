import SwiftUI
import Testing
import UIKit
import ViewInspector
@testable import FamilyMedicalApp

@MainActor
struct AttachmentThumbnailViewTests {
    // MARK: - Test Fixtures

    func makeDocument(
        title: String = "test.jpg",
        mimeType: String = "image/jpeg",
        thumbnailData: Data? = nil
    ) -> DocumentReferenceRecord {
        DocumentReferenceRecord(
            title: title,
            mimeType: mimeType,
            fileSize: 1_024,
            contentHMAC: Data(repeating: 0x42, count: 32),
            thumbnailData: thumbnailData
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
        let document = makeDocument()
        let view = AttachmentThumbnailView(
            document: document,
            onTap: {},
            onRemove: nil
        )

        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.Button.self)
        _ = try inspected.find(ViewType.ZStack.self)
    }

    @Test
    func viewRendersWithThumbnailData() throws {
        let thumbnailData = makeTestThumbnailData()
        let document = makeDocument(thumbnailData: thumbnailData)

        let view = AttachmentThumbnailView(
            document: document,
            onTap: {},
            onRemove: nil
        )

        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.Button.self)
        _ = try inspected.find(ViewType.Image.self)
    }

    @Test
    func viewRendersWithCustomSize() throws {
        let document = makeDocument()
        let view = AttachmentThumbnailView(
            document: document,
            onTap: {},
            onRemove: nil,
            size: 100
        )

        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.Button.self)
        _ = try inspected.find(ViewType.ZStack.self)
    }

    // MARK: - MIME Type Icon Tests

    @Test
    func jpegDocument_showsImageIconWithJPGText() throws {
        let document = makeDocument(mimeType: "image/jpeg")
        let view = AttachmentThumbnailView(
            document: document,
            onTap: {},
            onRemove: nil
        )

        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.Image.self)
        _ = try inspected.find(text: "JPG")
    }

    @Test
    func pngDocument_showsImageIconWithPNGText() throws {
        let document = makeDocument(title: "photo.png", mimeType: "image/png")
        let view = AttachmentThumbnailView(
            document: document,
            onTap: {},
            onRemove: nil
        )

        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.Image.self)
        _ = try inspected.find(text: "PNG")
    }

    @Test
    func pdfDocument_showsDocumentIcon() throws {
        let document = makeDocument(title: "document.pdf", mimeType: "application/pdf")
        let view = AttachmentThumbnailView(
            document: document,
            onTap: {},
            onRemove: nil
        )

        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.Image.self)
        _ = try inspected.find(text: "PDF")
    }

    // MARK: - Callback Tests

    @Test
    func viewWithTapCallback_rendersSuccessfully() throws {
        var tapped = false
        let document = makeDocument()

        let view = AttachmentThumbnailView(
            document: document,
            onTap: { tapped = true },
            onRemove: nil
        )

        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.Button.self)
        #expect(!tapped)
    }

    @Test
    func viewWithRemoveCallback_rendersSuccessfully() throws {
        var removed = false
        let document = makeDocument()

        let view = AttachmentThumbnailView(
            document: document,
            onTap: {},
            onRemove: { removed = true }
        )

        let inspected = try view.inspect()
        let buttons = inspected.findAll(ViewType.Button.self)
        #expect(buttons.count == 2)
        #expect(!removed)
    }

    @Test
    func viewWithBothCallbacks_rendersSuccessfully() throws {
        var tapped = false
        var removed = false
        let document = makeDocument()

        let view = AttachmentThumbnailView(
            document: document,
            onTap: { tapped = true },
            onRemove: { removed = true }
        )

        let inspected = try view.inspect()
        let buttons = inspected.findAll(ViewType.Button.self)
        #expect(buttons.count == 2)
        #expect(!tapped)
        #expect(!removed)
    }

    // MARK: - Remove Button Tests

    @Test
    func viewWithRemoveCallback_showsRemoveButton() throws {
        let document = makeDocument()
        let view = AttachmentThumbnailView(
            document: document,
            onTap: {},
            onRemove: {}
        )

        let inspected = try view.inspect()
        let buttons = inspected.findAll(ViewType.Button.self)
        #expect(buttons.count == 2)
    }

    @Test
    func viewWithoutRemoveCallback_hidesRemoveButton() throws {
        let document = makeDocument()
        let view = AttachmentThumbnailView(
            document: document,
            onTap: {},
            onRemove: nil
        )

        let inspected = try view.inspect()
        let buttons = inspected.findAll(ViewType.Button.self)
        #expect(buttons.count == 1)
    }

    // MARK: - Thumbnail Content Tests

    @Test
    func imageWithThumbnail_displaysImage() throws {
        let thumbnailData = makeTestThumbnailData()
        let document = makeDocument(
            title: "photo.jpg",
            mimeType: "image/jpeg",
            thumbnailData: thumbnailData
        )

        let view = AttachmentThumbnailView(
            document: document,
            onTap: {},
            onRemove: nil
        )

        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.Image.self)
    }

    @Test
    func imageWithoutThumbnail_showsFallbackIcon() throws {
        let document = makeDocument(
            title: "photo.jpg",
            mimeType: "image/jpeg",
            thumbnailData: nil
        )

        let view = AttachmentThumbnailView(
            document: document,
            onTap: {},
            onRemove: nil
        )

        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.Image.self)
        _ = try inspected.find(text: "JPG")
    }

    @Test
    func pdfDocument_showsDocIcon() throws {
        let document = makeDocument(
            title: "report.pdf",
            mimeType: "application/pdf",
            thumbnailData: nil
        )

        let view = AttachmentThumbnailView(
            document: document,
            onTap: {},
            onRemove: nil
        )

        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.Image.self)
        _ = try inspected.find(text: "PDF")
    }
}
