import CryptoKit
import PhotosUI
import SwiftUI

/// Main attachment picker component for medical record forms.
///
/// Displays drafts as thumbnails with an "Add" button that opens a menu with camera,
/// photo library, and document picker options. The parent form reads
/// `viewModel.allDocumentReferences` at save time to persist the drafts.
struct DocumentPickerView: View {
    @Bindable var viewModel: DocumentPickerViewModel

    private let gridColumns = [
        GridItem(.adaptive(minimum: 70, maximum: 90), spacing: 8)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            LazyVGrid(columns: gridColumns, alignment: .leading, spacing: 8) {
                ForEach(viewModel.drafts) { draft in
                    DocumentThumbnailView(
                        document: draft.content,
                        onTap: {
                            // Tapping is handled at the parent-form level later.
                        },
                        onRemove: {
                            viewModel.removeDraft(id: draft.id)
                        },
                        size: 70
                    )
                }

                if viewModel.canAddMore {
                    addButton
                }
            }

            Text(viewModel.countSummary)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .photosPicker(
            isPresented: $viewModel.showingPhotoLibrary,
            selection: Binding(
                get: { [] },
                set: { items in
                    Task {
                        await viewModel.addFromPhotoLibrary(items)
                    }
                }
            ),
            maxSelectionCount: viewModel.remainingSlots,
            matching: .images
        )
        .sheet(isPresented: $viewModel.showingDocumentPicker) {
            DocumentPickerRepresentable(
                onDocumentsPicked: { urls in
                    viewModel.showingDocumentPicker = false
                    Task {
                        await viewModel.addFromDocumentPicker(urls)
                    }
                },
                onCancel: {
                    viewModel.showingDocumentPicker = false
                }
            )
        }
        .fullScreenCover(isPresented: $viewModel.showingCamera) {
            CameraRepresentable(
                onImageCaptured: { image in
                    viewModel.showingCamera = false
                    Task {
                        await viewModel.addFromCamera(image)
                    }
                },
                onCancel: {
                    viewModel.showingCamera = false
                }
            )
            .ignoresSafeArea()
        }
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
    static func makeDocument(title: String, mimeType: String, hmacByte: UInt8) -> DocumentReferenceRecord {
        DocumentReferenceRecord(
            title: title,
            mimeType: mimeType,
            fileSize: 1_024,
            contentHMAC: Data(repeating: hmacByte, count: 32)
        )
    }

    static func makeSampleDocuments(count: Int) -> [DocumentReferenceRecord] {
        (0 ..< count).map { index in
            DocumentReferenceRecord(
                title: "file\(index).jpg",
                mimeType: "image/jpeg",
                fileSize: 1_024,
                contentHMAC: Data(repeating: UInt8(index), count: 32)
            )
        }
    }
}

#Preview("Empty") {
    Form {
        Section("Attachments") {
            DocumentPickerView(
                viewModel: DocumentPickerViewModel(
                    personId: UUID(),
                    sourceRecordId: UUID(),
                    primaryKey: SymmetricKey(size: .bits256),
                    existing: []
                )
            )
        }
    }
}

#Preview("With Attachments") {
    let documents: [DocumentReferenceRecord] = [
        PickerPreviewHelpers.makeDocument(title: "vaccine_card.jpg", mimeType: "image/jpeg", hmacByte: 1),
        PickerPreviewHelpers.makeDocument(title: "prescription.pdf", mimeType: "application/pdf", hmacByte: 2)
    ]

    Form {
        Section("Attachments") {
            DocumentPickerView(
                viewModel: DocumentPickerViewModel(
                    personId: UUID(),
                    sourceRecordId: UUID(),
                    primaryKey: SymmetricKey(size: .bits256),
                    existing: documents
                )
            )
        }
    }
}

#Preview("At Limit") {
    let documents = PickerPreviewHelpers.makeSampleDocuments(count: 5)

    Form {
        Section("Attachments") {
            DocumentPickerView(
                viewModel: DocumentPickerViewModel(
                    personId: UUID(),
                    sourceRecordId: UUID(),
                    primaryKey: SymmetricKey(size: .bits256),
                    existing: documents
                )
            )
        }
    }
}
