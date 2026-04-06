import SwiftUI

/// Displays a thumbnail for a DocumentReferenceRecord attachment.
///
/// Shows the inline thumbnail image if available, or a file-type icon for PDFs and files
/// without thumbnails. Uses `ThumbnailDisplayMode` so the display logic remains testable.
struct DocumentThumbnailView: View {
    /// The document to display
    let document: DocumentReferenceRecord

    /// Called when thumbnail is tapped
    let onTap: () -> Void

    /// Called when remove button is tapped (nil to hide button)
    let onRemove: (() -> Void)?

    /// Size of the thumbnail
    var size: CGFloat = 80

    private var displayMode: ThumbnailDisplayMode {
        ThumbnailDisplayMode.from(document: document)
    }

    private var displayExtension: String {
        guard let dotIndex = document.title.lastIndex(of: ".") else { return "" }
        let extensionStartIndex = document.title.index(after: dotIndex)
        return String(document.title[extensionStartIndex...])
    }

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                thumbnailContent
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                if let onRemove {
                    Button(action: onRemove) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.white)
                            .background(
                                Circle()
                                    .fill(.black.opacity(0.6))
                                    .frame(width: 22, height: 22)
                            )
                    }
                    .offset(x: 8, y: -8)
                    .accessibilityLabel("Remove \(document.title)")
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(document.title)
        .accessibilityHint("Tap to view full size")
    }

    @ViewBuilder private var thumbnailContent: some View {
        switch displayMode {
        case let .thumbnail(thumbnailData):
            if let uiImage = UIImage(data: thumbnailData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                fileIconView(systemName: "photo.fill", color: .blue)
            }

        case .pdfIcon:
            fileIconView(systemName: displayMode.systemImageName, color: .red)

        case .imageIcon:
            fileIconView(systemName: displayMode.systemImageName, color: .blue)

        case .genericFileIcon:
            fileIconView(systemName: displayMode.systemImageName, color: .gray)
        }
    }

    private func fileIconView(systemName: String, color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.15))

            VStack(spacing: 4) {
                Image(systemName: systemName)
                    .font(.system(size: size * 0.35))
                    .foregroundStyle(color)

                Text(displayExtension.uppercased())
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(color)
            }
        }
    }
}

// MARK: - Preview Helpers

private enum PreviewHelpers {
    static func makeDocument(
        title: String,
        mimeType: String,
        thumbnailData: Data? = nil,
        hmacByte: UInt8 = 0
    ) -> DocumentReferenceRecord {
        DocumentReferenceRecord(
            title: title,
            mimeType: mimeType,
            fileSize: 1_024,
            contentHMAC: Data(repeating: hmacByte, count: 32),
            thumbnailData: thumbnailData
        )
    }
}

#Preview("With Thumbnail") {
    let sampleImage = UIImage(systemName: "photo")
    let thumbnailData = sampleImage?.jpegData(compressionQuality: 0.7)

    DocumentThumbnailView(
        document: PreviewHelpers.makeDocument(
            title: "vaccine_card.jpg",
            mimeType: "image/jpeg",
            thumbnailData: thumbnailData
        ),
        onTap: {},
        onRemove: {}
    )
    .padding()
}

#Preview("PDF") {
    DocumentThumbnailView(
        document: PreviewHelpers.makeDocument(
            title: "prescription.pdf",
            mimeType: "application/pdf"
        ),
        onTap: {},
        onRemove: nil
    )
    .padding()
}

#Preview("Grid") {
    let documents: [DocumentReferenceRecord] = [
        PreviewHelpers.makeDocument(title: "photo1.jpg", mimeType: "image/jpeg", hmacByte: 1),
        PreviewHelpers.makeDocument(title: "document.pdf", mimeType: "application/pdf", hmacByte: 2),
        PreviewHelpers.makeDocument(title: "scan.png", mimeType: "image/png", hmacByte: 3)
    ]

    LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 12) {
        ForEach(Array(documents.enumerated()), id: \.offset) { _, doc in
            DocumentThumbnailView(
                document: doc,
                onTap: {},
                onRemove: {}
            )
        }
    }
    .padding()
}
