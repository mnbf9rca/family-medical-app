import PhotosUI
import SwiftUI

/// Main attachment picker component for medical record forms
///
/// Displays existing attachments as thumbnails with an "Add" button that opens
/// a menu with camera, photo library, and document picker options.
struct AttachmentPickerView: View {
    /// ViewModel managing attachment state
    @Bindable var viewModel: AttachmentPickerViewModel

    /// Callback when attachments change
    var onAttachmentsChanged: (([UUID]) -> Void)?

    /// Columns for adaptive grid layout
    private let gridColumns = [
        GridItem(.adaptive(minimum: 70, maximum: 90), spacing: 8)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Thumbnails grid with add button
            LazyVGrid(columns: gridColumns, alignment: .leading, spacing: 8) {
                // Existing attachments
                ForEach(viewModel.attachments) { attachment in
                    AttachmentThumbnailView(
                        attachment: attachment,
                        onTap: {
                            // TODO: Navigate to full-screen viewer
                        },
                        onRemove: {
                            Task {
                                await viewModel.removeAttachment(attachment)
                                onAttachmentsChanged?(viewModel.attachmentIds)
                            }
                        },
                        size: 70
                    )
                }

                // Add button
                if viewModel.canAddMore {
                    addButton
                }
            }

            // Count summary
            Text(viewModel.countSummary)
                .font(.caption)
                .foregroundStyle(.secondary)

            // Error message
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        // Photo library picker
        .photosPicker(
            isPresented: $viewModel.showingPhotoLibrary,
            selection: Binding(
                get: { [] },
                set: { items in
                    Task {
                        await viewModel.addFromPhotoLibrary(items)
                        onAttachmentsChanged?(viewModel.attachmentIds)
                    }
                }
            ),
            maxSelectionCount: viewModel.remainingSlots,
            matching: .images
        )
        // Document picker
        .sheet(isPresented: $viewModel.showingDocumentPicker) {
            DocumentPickerRepresentable(
                onDocumentsPicked: { urls in
                    viewModel.showingDocumentPicker = false
                    Task {
                        await viewModel.addFromDocumentPicker(urls)
                        onAttachmentsChanged?(viewModel.attachmentIds)
                    }
                },
                onCancel: {
                    viewModel.showingDocumentPicker = false
                }
            )
        }
        // Camera
        .fullScreenCover(isPresented: $viewModel.showingCamera) {
            CameraRepresentable(
                onImageCaptured: { image in
                    viewModel.showingCamera = false
                    Task {
                        await viewModel.addFromCamera(image)
                        onAttachmentsChanged?(viewModel.attachmentIds)
                    }
                },
                onCancel: {
                    viewModel.showingCamera = false
                }
            )
            .ignoresSafeArea()
        }
        // Loading overlay
        .overlay {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Attachments")
    }

    // MARK: - Add Button

    private var addButton: some View {
        Menu {
            if CameraRepresentable.isCameraAvailable {
                Button {
                    viewModel.showingCamera = true
                } label: {
                    Label("Take Photo", systemImage: "camera")
                }
            }

            Button {
                viewModel.showingPhotoLibrary = true
            } label: {
                Label("Choose from Library", systemImage: "photo.on.rectangle")
            }

            Button {
                viewModel.showingDocumentPicker = true
            } label: {
                Label("Choose File", systemImage: "doc")
            }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [5]))
                    .foregroundStyle(.secondary)

                Image(systemName: "plus")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 70, height: 70)
            // Accessibility on label content for XCTest discoverability
            .accessibilityElement(children: .ignore)
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("addAttachmentButton")
            .accessibilityLabel("Add attachment")
            .accessibilityHint("Opens menu to add photo or document")
        }
    }
}

// MARK: - Preview Helpers

private enum PickerPreviewHelpers {
    static func makeAttachment(fileName: String, mimeType: String, hmacByte: UInt8) -> Attachment? {
        try? Attachment(
            id: UUID(),
            fileName: fileName,
            mimeType: mimeType,
            contentHMAC: Data(repeating: hmacByte, count: 32),
            encryptedSize: 1_024,
            thumbnailData: nil,
            uploadedAt: Date()
        )
    }

    static func makeSampleAttachments(count: Int) -> [Attachment] {
        (0 ..< count).compactMap { index in
            try? Attachment(
                id: UUID(),
                fileName: "file\(index).jpg",
                mimeType: "image/jpeg",
                contentHMAC: Data(repeating: UInt8(index), count: 32),
                encryptedSize: 1_024,
                thumbnailData: nil,
                uploadedAt: Date()
            )
        }
    }
}

#Preview("Empty") {
    Form {
        Section("Attachments") {
            AttachmentPickerView(
                viewModel: AttachmentPickerViewModel(
                    personId: UUID(),
                    existingAttachments: []
                )
            )
        }
    }
}

#Preview("With Attachments") {
    let attachments: [Attachment] = [
        PickerPreviewHelpers.makeAttachment(fileName: "vaccine_card.jpg", mimeType: "image/jpeg", hmacByte: 1),
        PickerPreviewHelpers.makeAttachment(fileName: "prescription.pdf", mimeType: "application/pdf", hmacByte: 2)
    ].compactMap(\.self)

    Form {
        Section("Attachments") {
            AttachmentPickerView(
                viewModel: AttachmentPickerViewModel(
                    personId: UUID(),
                    existingAttachments: attachments
                )
            )
        }
    }
}

#Preview("At Limit") {
    let attachments = PickerPreviewHelpers.makeSampleAttachments(count: 5)

    Form {
        Section("Attachments") {
            AttachmentPickerView(
                viewModel: AttachmentPickerViewModel(
                    personId: UUID(),
                    existingAttachments: attachments
                )
            )
        }
    }
}
