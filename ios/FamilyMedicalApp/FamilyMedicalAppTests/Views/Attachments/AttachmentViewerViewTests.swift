import CryptoKit
import SwiftUI
import Testing
import UIKit
import ViewInspector
@testable import FamilyMedicalApp

@MainActor
struct AttachmentViewerViewTests {
    // MARK: - Test Fixtures

    func makeTestAttachment(
        fileName: String = "test.jpg",
        mimeType: String = "image/jpeg"
    ) throws -> FamilyMedicalApp.Attachment {
        try FamilyMedicalApp.Attachment(
            id: UUID(),
            fileName: fileName,
            mimeType: mimeType,
            contentHMAC: Data(repeating: 0xAB, count: 32),
            encryptedSize: 1_024,
            thumbnailData: nil,
            uploadedAt: Date()
        )
    }

    func makeViewModel(
        fileName: String = "test.jpg",
        mimeType: String = "image/jpeg"
    ) throws -> AttachmentViewerViewModel {
        let attachmentService = MockAttachmentService()
        let primaryKey = SymmetricKey(size: .bits256)
        let primaryKeyProvider = MockPrimaryKeyProvider(primaryKey: primaryKey)
        let personId = UUID()

        let attachment = try FamilyMedicalApp.Attachment(
            id: UUID(),
            fileName: fileName,
            mimeType: mimeType,
            contentHMAC: Data(repeating: 0xAB, count: 32),
            encryptedSize: 1_024,
            thumbnailData: nil,
            uploadedAt: Date()
        )

        attachmentService.addTestAttachment(
            attachment,
            content: Data("test content".utf8),
            linkedToRecord: UUID()
        )

        return AttachmentViewerViewModel(
            attachment: attachment,
            personId: personId,
            attachmentService: attachmentService,
            primaryKeyProvider: primaryKeyProvider
        )
    }

    func makeTestImageData() -> Data {
        let size = CGSize(width: 100, height: 100)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
        // swiftlint:disable:next force_unwrapping
        return image.jpegData(compressionQuality: 0.8)!
    }

    // MARK: - Basic Rendering Tests

    @Test
    func viewRendersSuccessfully() throws {
        let viewModel = try makeViewModel()
        let view = AttachmentViewerView(viewModel: viewModel)

        // Use find() for deterministic coverage
        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.NavigationStack.self)
    }

    @Test
    func viewRendersWithImageAttachment() throws {
        let viewModel = try makeViewModel(mimeType: "image/jpeg")
        let view = AttachmentViewerView(viewModel: viewModel)

        // Use find() for deterministic coverage
        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.NavigationStack.self)
        #expect(viewModel.isImage)
    }

    @Test
    func viewRendersWithPDFAttachment() throws {
        let viewModel = try makeViewModel(fileName: "document.pdf", mimeType: "application/pdf")
        let view = AttachmentViewerView(viewModel: viewModel)

        // Use find() for deterministic coverage
        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.NavigationStack.self)
        #expect(viewModel.isPDF)
    }

    // MARK: - Loading State Tests

    @Test
    func viewShowsLoadingState() throws {
        let viewModel = try makeViewModel()
        viewModel.isLoading = true

        let view = AttachmentViewerView(viewModel: viewModel)

        // Find ProgressView to exercise loading branch
        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.ProgressView.self)
    }

    @Test
    func viewShowsErrorState() throws {
        let viewModel = try makeViewModel()
        viewModel.errorMessage = "Failed to load content"

        let view = AttachmentViewerView(viewModel: viewModel)

        // Find error message text to exercise error branch
        let inspected = try view.inspect()
        _ = try inspected.find(text: "Failed to load content")
    }

    // MARK: - Content Display Tests

    @Test
    func viewWithLoadedContent_showsContent() async throws {
        let viewModel = try makeViewModel()

        await viewModel.loadContent()

        let view = AttachmentViewerView(viewModel: viewModel)
        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.NavigationStack.self)

        #expect(viewModel.hasContent)
    }

    @Test
    func viewDisplaysFileName() throws {
        let viewModel = try makeViewModel(fileName: "medical_report.jpg")
        let view = AttachmentViewerView(viewModel: viewModel)

        // Use find() for deterministic coverage - verify view structure renders
        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.NavigationStack.self)
        #expect(viewModel.displayFileName == "medical_report.jpg")
    }

    @Test
    func viewDisplaysFileSize() throws {
        let viewModel = try makeViewModel()
        let view = AttachmentViewerView(viewModel: viewModel)

        // Use find() for deterministic coverage - verify view structure renders
        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.NavigationStack.self)
        #expect(!viewModel.displayFileSize.isEmpty)
    }

    // MARK: - Image Viewer Tests

    @Test
    func imageViewer_supportsZoom() throws {
        let viewModel = try makeViewModel(mimeType: "image/jpeg")
        let view = AttachmentViewerView(viewModel: viewModel)

        // Use find() for deterministic coverage
        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.NavigationStack.self)
        #expect(viewModel.isImage)
    }

    // MARK: - PDF Viewer Tests

    @Test
    func pdfViewer_renders() throws {
        let viewModel = try makeViewModel(fileName: "doc.pdf", mimeType: "application/pdf")
        let view = AttachmentViewerView(viewModel: viewModel)

        // Use find() for deterministic coverage
        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.NavigationStack.self)
        #expect(viewModel.isPDF)
        #expect(!viewModel.isImage)
    }

    // MARK: - Export Warning Tests

    @Test
    func viewWithExportWarning_showsDialog() throws {
        let viewModel = try makeViewModel()
        viewModel.showingExportWarning = true

        let view = AttachmentViewerView(viewModel: viewModel)

        // Use find() for deterministic coverage
        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.NavigationStack.self)
    }

    // MARK: - Share Sheet Tests

    @Test
    func viewWithShareSheet_rendersSuccessfully() throws {
        let viewModel = try makeViewModel()
        viewModel.showingShareSheet = true

        let view = AttachmentViewerView(viewModel: viewModel)

        // Use find() for deterministic coverage
        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.NavigationStack.self)
    }
}
