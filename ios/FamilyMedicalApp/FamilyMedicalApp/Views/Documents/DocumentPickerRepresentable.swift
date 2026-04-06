import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// SwiftUI wrapper for UIDocumentPickerViewController
///
/// Allows users to select PDF files from the Files app.
struct DocumentPickerRepresentable: UIViewControllerRepresentable {
    /// Content types to allow (defaults to PDF only)
    let allowedContentTypes: [UTType]

    /// Callback when documents are selected
    let onDocumentsPicked: ([URL]) -> Void

    /// Callback when picker is cancelled
    let onCancel: () -> Void

    init(
        allowedContentTypes: [UTType] = [.pdf],
        onDocumentsPicked: @escaping ([URL]) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.allowedContentTypes = allowedContentTypes
        self.onDocumentsPicked = onDocumentsPicked
        self.onCancel = onCancel
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: allowedContentTypes)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = true
        return picker
    }

    func updateUIViewController(_: UIDocumentPickerViewController, context _: Context) {
        // No updates needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onDocumentsPicked: onDocumentsPicked, onCancel: onCancel)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onDocumentsPicked: ([URL]) -> Void
        let onCancel: () -> Void

        init(onDocumentsPicked: @escaping ([URL]) -> Void, onCancel: @escaping () -> Void) {
            self.onDocumentsPicked = onDocumentsPicked
            self.onCancel = onCancel
        }

        func documentPicker(_: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onDocumentsPicked(urls)
        }

        func documentPickerWasCancelled(_: UIDocumentPickerViewController) {
            onCancel()
        }
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var showingPicker = true

    Button("Show Picker") {
        showingPicker = true
    }
    .sheet(isPresented: $showingPicker) {
        DocumentPickerRepresentable(
            onDocumentsPicked: { _ in
                showingPicker = false
            },
            onCancel: {
                showingPicker = false
            }
        )
    }
}
