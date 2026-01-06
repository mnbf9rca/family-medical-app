import SwiftUI

/// Displays a thumbnail for an attachment
///
/// Shows the encrypted thumbnail image if available, or a file type icon
/// for PDFs and files without thumbnails.
struct AttachmentThumbnailView: View {
    /// The attachment to display
    let attachment: Attachment

    /// Called when thumbnail is tapped
    let onTap: () -> Void

    /// Called when remove button is tapped (nil to hide button)
    let onRemove: (() -> Void)?

    /// Size of the thumbnail
    var size: CGFloat = 80

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                // Thumbnail content
                thumbnailContent
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                // Remove button
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
                    .accessibilityLabel("Remove \(attachment.fileName)")
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(attachment.fileName)
        .accessibilityHint("Tap to view full size")
    }

    @ViewBuilder private var thumbnailContent: some View {
        if let thumbnailData = attachment.thumbnailData,
           let uiImage = UIImage(data: thumbnailData) {
            // Show actual thumbnail
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else if attachment.isPDF {
            // PDF icon
            fileIconView(systemName: "doc.fill", color: .red)
        } else if attachment.isImage {
            // Image placeholder (thumbnail not generated)
            fileIconView(systemName: "photo.fill", color: .blue)
        } else {
            // Generic file icon
            fileIconView(systemName: "doc.fill", color: .gray)
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

                Text((attachment.fileExtension ?? "").uppercased())
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(color)
            }
        }
    }
}

// MARK: - Preview Helpers

private enum PreviewHelpers {
    static func makeAttachment(
        fileName: String,
        mimeType: String,
        thumbnailData: Data? = nil,
        hmacByte: UInt8 = 0
    ) -> Attachment? {
        try? Attachment(
            id: UUID(),
            fileName: fileName,
            mimeType: mimeType,
            contentHMAC: Data(repeating: hmacByte, count: 32),
            encryptedSize: 1_024,
            thumbnailData: thumbnailData,
            uploadedAt: Date()
        )
    }
}

#Preview("With Thumbnail") {
    let sampleImage = UIImage(systemName: "photo")
    let thumbnailData = sampleImage?.jpegData(compressionQuality: 0.7)

    if let attachment = PreviewHelpers.makeAttachment(
        fileName: "vaccine_card.jpg",
        mimeType: "image/jpeg",
        thumbnailData: thumbnailData
    ) {
        AttachmentThumbnailView(
            attachment: attachment,
            onTap: {},
            onRemove: {}
        )
        .padding()
    }
}

#Preview("PDF") {
    if let attachment = PreviewHelpers.makeAttachment(
        fileName: "prescription.pdf",
        mimeType: "application/pdf"
    ) {
        AttachmentThumbnailView(
            attachment: attachment,
            onTap: {},
            onRemove: nil
        )
        .padding()
    }
}

#Preview("Grid") {
    let attachments: [Attachment] = [
        PreviewHelpers.makeAttachment(fileName: "photo1.jpg", mimeType: "image/jpeg", hmacByte: 1),
        PreviewHelpers.makeAttachment(fileName: "document.pdf", mimeType: "application/pdf", hmacByte: 2),
        PreviewHelpers.makeAttachment(fileName: "scan.png", mimeType: "image/png", hmacByte: 3)
    ].compactMap(\.self)

    LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 12) {
        ForEach(attachments) { attachment in
            AttachmentThumbnailView(
                attachment: attachment,
                onTap: {},
                onRemove: {}
            )
        }
    }
    .padding()
}
