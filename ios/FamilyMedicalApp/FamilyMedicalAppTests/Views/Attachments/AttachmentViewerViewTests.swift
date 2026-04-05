import CryptoKit
import SwiftUI
import Testing
import UIKit
import ViewInspector
@testable import FamilyMedicalApp

@MainActor
struct AttachmentViewerViewTests {
    // MARK: - Test Fixtures

    func makeDocument(
        title: String = "test.jpg",
        mimeType: String = "image/jpeg"
    ) -> DocumentReferenceRecord {
        DocumentReferenceRecord(
            title: title,
            mimeType: mimeType,
            fileSize: 1_024,
            contentHMAC: Data(repeating: 0xAB, count: 32)
        )
    }

    func makeViewModel(
        title: String = "test.jpg",
        mimeType: String = "image/jpeg"
    ) -> AttachmentViewerViewModel {
        let blobService = MockAttachmentBlobService()
        blobService.retrieveResult = Data("test content".utf8)
        let primaryKey = SymmetricKey(size: .bits256)
        let document = makeDocument(title: title, mimeType: mimeType)

        return AttachmentViewerViewModel(
            document: document,
            personId: UUID(),
            primaryKey: primaryKey,
            blobService: blobService
        )
    }

    // MARK: - Basic Rendering Tests

    @Test
    func viewRendersSuccessfully() throws {
        let viewModel = makeViewModel()
        let view = AttachmentViewerView(viewModel: viewModel)

        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.NavigationStack.self)
    }

    @Test
    func viewRendersWithImageDocument() throws {
        let viewModel = makeViewModel(mimeType: "image/jpeg")
        let view = AttachmentViewerView(viewModel: viewModel)

        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.NavigationStack.self)
        #expect(viewModel.isImage)
    }

    @Test
    func viewRendersWithPDFDocument() throws {
        let viewModel = makeViewModel(title: "document.pdf", mimeType: "application/pdf")
        let view = AttachmentViewerView(viewModel: viewModel)

        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.NavigationStack.self)
        #expect(viewModel.isPDF)
    }

    // MARK: - Loading State Tests

    @Test
    func viewShowsLoadingState() throws {
        let viewModel = makeViewModel()
        viewModel.isLoading = true

        let view = AttachmentViewerView(viewModel: viewModel)
        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.ProgressView.self)
    }

    @Test
    func viewShowsErrorState() throws {
        let viewModel = makeViewModel()
        viewModel.errorMessage = "Failed to load content"

        let view = AttachmentViewerView(viewModel: viewModel)
        let inspected = try view.inspect()
        _ = try inspected.find(text: "Failed to load content")
    }

    // MARK: - Content Display Tests

    @Test
    func viewWithLoadedContent_showsContent() async throws {
        let viewModel = makeViewModel()
        await viewModel.loadContent()

        let view = AttachmentViewerView(viewModel: viewModel)
        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.NavigationStack.self)
        #expect(viewModel.hasContent)
    }

    @Test
    func viewDisplaysFileName() throws {
        let viewModel = makeViewModel(title: "medical_report.jpg")
        let view = AttachmentViewerView(viewModel: viewModel)

        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.NavigationStack.self)
        #expect(viewModel.displayFileName == "medical_report.jpg")
    }

    @Test
    func viewDisplaysFileSize() throws {
        let viewModel = makeViewModel()
        let view = AttachmentViewerView(viewModel: viewModel)

        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.NavigationStack.self)
        #expect(!viewModel.displayFileSize.isEmpty)
    }

    // MARK: - Image Viewer Tests

    @Test
    func imageViewer_supportsZoom() throws {
        let viewModel = makeViewModel(mimeType: "image/jpeg")
        let view = AttachmentViewerView(viewModel: viewModel)

        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.NavigationStack.self)
        #expect(viewModel.isImage)
    }

    // MARK: - PDF Viewer Tests

    @Test
    func pdfViewer_renders() throws {
        let viewModel = makeViewModel(title: "doc.pdf", mimeType: "application/pdf")
        let view = AttachmentViewerView(viewModel: viewModel)

        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.NavigationStack.self)
        #expect(viewModel.isPDF)
        #expect(!viewModel.isImage)
    }

    // MARK: - Export Warning Tests

    @Test
    func viewWithExportWarning_rendersSuccessfully() throws {
        let viewModel = makeViewModel()
        viewModel.showingExportWarning = true

        let view = AttachmentViewerView(viewModel: viewModel)
        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.NavigationStack.self)
    }

    // MARK: - Share Sheet Tests

    @Test
    func viewWithShareSheet_rendersSuccessfully() throws {
        let viewModel = makeViewModel()
        viewModel.showingShareSheet = true

        let view = AttachmentViewerView(viewModel: viewModel)
        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.NavigationStack.self)
    }
}
