import PDFKit
import SwiftUI

/// Full-screen viewer for attachment content
///
/// Supports:
/// - Images with pinch-to-zoom
/// - PDF documents with PDFKit
/// - Share/export with security warning
struct AttachmentViewerView: View {
    /// ViewModel for content loading and state
    @Bindable var viewModel: AttachmentViewerViewModel

    /// Environment for dismissing the view
    @Environment(\.dismiss)
    private var dismiss

    /// Current zoom scale for images
    @State private var scale: CGFloat = 1.0

    /// Last committed scale (for gesture updates)
    @State private var lastScale: CGFloat = 1.0

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color.black.ignoresSafeArea()

                // Content
                contentView
            }
            .navigationTitle(viewModel.displayFileName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        viewModel.clearDecryptedData()
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    if viewModel.hasContent {
                        Button {
                            viewModel.requestExport()
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .accessibilityLabel("Share")
                    }
                }
            }
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .task {
            await viewModel.loadContent()
        }
        .onDisappear {
            viewModel.clearDecryptedData()
            viewModel.cleanupTemporaryFile()
        }
        .exportWarning(isPresented: $viewModel.showingExportWarning) {
            viewModel.confirmExport()
        } onCancel: {
            viewModel.cancelExport()
        }
        .sheet(isPresented: $viewModel.showingShareSheet) {
            if let url = viewModel.getTemporaryFileURL() {
                ShareSheet(items: [url])
            }
        }
    }

    // MARK: - Content Views

    @ViewBuilder private var contentView: some View {
        if viewModel.isLoading {
            loadingView
        } else if let errorMessage = viewModel.errorMessage {
            errorView(message: errorMessage)
        } else if let data = viewModel.decryptedData {
            if viewModel.isImage {
                imageView(data: data)
            } else if viewModel.isPDF {
                pdfView(data: data)
            } else {
                unsupportedView
            }
        } else {
            loadingView
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)

            Text("Loading...")
                .foregroundStyle(.white)
        }
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.yellow)

            Text(message)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Retry") {
                Task {
                    await viewModel.loadContent()
                }
            }
            .buttonStyle(.bordered)
            .tint(.white)
        }
    }

    private func imageView(data: Data) -> some View {
        GeometryReader { geometry in
            if let uiImage = UIImage(data: data) {
                ScrollView([.horizontal, .vertical], showsIndicators: false) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(
                            width: geometry.size.width * scale,
                            height: geometry.size.height * scale
                        )
                }
                .gesture(magnificationGesture)
                .onTapGesture(count: 2) {
                    withAnimation {
                        if scale > 1.0 {
                            scale = 1.0
                            lastScale = 1.0
                        } else {
                            scale = 2.0
                            lastScale = 2.0
                        }
                    }
                }
            }
        }
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let newScale = lastScale * value
                scale = min(max(newScale, 1.0), 5.0) // Clamp between 1x and 5x
            }
            .onEnded { _ in
                lastScale = scale
            }
    }

    private func pdfView(data: Data) -> some View {
        PDFKitView(data: data)
            .ignoresSafeArea(edges: .bottom)
    }

    private var unsupportedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.questionmark")
                .font(.largeTitle)
                .foregroundStyle(.gray)

            Text("This file type cannot be previewed")
                .foregroundStyle(.white)

            Text(viewModel.displayFileName)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - PDF View Wrapper

/// UIViewRepresentable wrapper for PDFKit's PDFView
private struct PDFKitView: UIViewRepresentable {
    let data: Data

    func makeUIView(context _: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = .black
        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context _: Context) {
        if let document = PDFDocument(data: data) {
            pdfView.document = document
        }
    }
}

// MARK: - Share Sheet

/// UIActivityViewController wrapper for SwiftUI
private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context _: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_: UIActivityViewController, context _: Context) {}
}

// MARK: - Preview Helpers

private enum ViewerPreviewHelpers {
    static func makeAttachment(fileName: String, mimeType: String) -> Attachment? {
        try? Attachment(
            id: UUID(),
            fileName: fileName,
            mimeType: mimeType,
            contentHMAC: Data(repeating: 0, count: 32),
            encryptedSize: 1_024,
            thumbnailData: nil,
            uploadedAt: Date()
        )
    }
}

#Preview("Image") {
    if let attachment = ViewerPreviewHelpers.makeAttachment(
        fileName: "test_image.jpg",
        mimeType: "image/jpeg"
    ) {
        let viewModel = AttachmentViewerViewModel(
            attachment: attachment,
            personId: UUID()
        )
        AttachmentViewerView(viewModel: viewModel)
    }
}

#Preview("PDF") {
    if let attachment = ViewerPreviewHelpers.makeAttachment(
        fileName: "document.pdf",
        mimeType: "application/pdf"
    ) {
        let viewModel = AttachmentViewerViewModel(
            attachment: attachment,
            personId: UUID()
        )
        AttachmentViewerView(viewModel: viewModel)
    }
}
