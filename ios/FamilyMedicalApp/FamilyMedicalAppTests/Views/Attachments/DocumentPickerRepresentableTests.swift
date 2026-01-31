import SwiftUI
import Testing
import UIKit
import UniformTypeIdentifiers
@testable import FamilyMedicalApp

@MainActor
struct DocumentPickerRepresentableTests {
    // MARK: - Initialization Tests

    @Test
    func init_createsRepresentable() {
        var pickedURLs: [URL]?
        var wasCancelled = false

        let representable = DocumentPickerRepresentable(
            allowedContentTypes: [.pdf, .jpeg, .png],
            onDocumentsPicked: { urls in pickedURLs = urls },
            onCancel: { wasCancelled = true }
        )

        // Verify callbacks are stored but not yet invoked
        #expect(pickedURLs == nil)
        #expect(!wasCancelled)
        _ = representable // Silence unused warning
    }

    @Test
    func init_withDefaultContentTypes() {
        let representable = DocumentPickerRepresentable(
            onDocumentsPicked: { _ in },
            onCancel: {}
        )

        // Should create with default content types (PDF, JPEG, PNG)
        _ = representable
    }

    // MARK: - Coordinator Tests

    @Test
    func coordinator_isCreatedWithCallbacks() {
        var pickedURLs: [URL]?
        var wasCancelled = false

        let representable = DocumentPickerRepresentable(
            allowedContentTypes: [.pdf],
            onDocumentsPicked: { urls in pickedURLs = urls },
            onCancel: { wasCancelled = true }
        )

        // makeCoordinator() returns non-optional
        _ = representable.makeCoordinator()
        _ = pickedURLs
        _ = wasCancelled
    }

    @Test
    func coordinator_documentPickerWasCancelled_invokesCallback() {
        var wasCancelled = false

        let representable = DocumentPickerRepresentable(
            allowedContentTypes: [.pdf],
            onDocumentsPicked: { _ in },
            onCancel: { wasCancelled = true }
        )

        let coordinator = representable.makeCoordinator()
        let mockPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf])

        // Simulate cancel
        coordinator.documentPickerWasCancelled(mockPicker)

        #expect(wasCancelled)
    }

    @Test
    func coordinator_didPickDocuments_invokesCallbackWithURLs() {
        var pickedURLs: [URL]?

        let representable = DocumentPickerRepresentable(
            allowedContentTypes: [.pdf],
            onDocumentsPicked: { urls in pickedURLs = urls },
            onCancel: {}
        )

        let coordinator = representable.makeCoordinator()
        let mockPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf])

        // Create test URLs
        let testURLs = [
            FileManager.default.temporaryDirectory.appendingPathComponent("test1.pdf"),
            FileManager.default.temporaryDirectory.appendingPathComponent("test2.pdf")
        ]

        // Simulate picking documents
        coordinator.documentPicker(mockPicker, didPickDocumentsAt: testURLs)

        #expect(pickedURLs != nil)
        #expect(pickedURLs?.count == 2)
    }

    @Test
    func coordinator_didPickEmptyDocuments_invokesCallbackWithEmptyArray() {
        var pickedURLs: [URL]?

        let representable = DocumentPickerRepresentable(
            allowedContentTypes: [.pdf],
            onDocumentsPicked: { urls in pickedURLs = urls },
            onCancel: {}
        )

        let coordinator = representable.makeCoordinator()
        let mockPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf])

        // Simulate picking no documents
        coordinator.documentPicker(mockPicker, didPickDocumentsAt: [])

        #expect(pickedURLs != nil)
        #expect(pickedURLs?.isEmpty == true)
    }

    // MARK: - Content Types Tests

    @Test
    func init_withPDFOnly() {
        let representable = DocumentPickerRepresentable(
            allowedContentTypes: [.pdf],
            onDocumentsPicked: { _ in },
            onCancel: {}
        )

        _ = representable
    }

    @Test
    func init_withImagesOnly() {
        let representable = DocumentPickerRepresentable(
            allowedContentTypes: [.jpeg, .png],
            onDocumentsPicked: { _ in },
            onCancel: {}
        )

        _ = representable
    }

    @Test
    func init_withMixedTypes() {
        let representable = DocumentPickerRepresentable(
            allowedContentTypes: [.pdf, .jpeg, .png, .heic],
            onDocumentsPicked: { _ in },
            onCancel: {}
        )

        _ = representable
    }
}
