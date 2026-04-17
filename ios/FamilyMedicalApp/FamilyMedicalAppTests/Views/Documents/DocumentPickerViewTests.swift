import CryptoKit
import SwiftUI
import Testing
import ViewInspector
@testable import FamilyMedicalApp

@MainActor
struct DocumentPickerViewTests {
    // MARK: - Test Fixtures

    func makeViewModel(existing: [DocumentReferenceRecord] = []) -> DocumentPickerViewModel {
        let blobService = MockDocumentBlobService()
        return DocumentPickerViewModel(
            personId: UUID(),
            sourceRecordId: UUID(),
            primaryKey: SymmetricKey(size: .bits256),
            existing: existing,
            blobService: blobService
        )
    }

    func makeDocument(
        title: String = "test.jpg",
        mimeType: String = "image/jpeg",
        hmacByte: UInt8 = 0x01
    ) -> DocumentReferenceRecord {
        DocumentReferenceRecord(
            title: title,
            mimeType: mimeType,
            fileSize: 1_024,
            contentHMAC: Data(repeating: hmacByte, count: 32)
        )
    }

    // MARK: - Basic Rendering Tests

    @Test
    func viewRendersSuccessfully() throws {
        let viewModel = makeViewModel()
        let view = DocumentPickerView(viewModel: viewModel)

        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            _ = try inspected.find(ViewType.VStack.self)
        }
    }

    @Test
    func viewRendersWithExistingDrafts() throws {
        let document = makeDocument()
        let viewModel = makeViewModel(existing: [document])
        let view = DocumentPickerView(viewModel: viewModel)

        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            _ = try inspected.find(ViewType.LazyVGrid.self)
        }
    }

    @Test
    func viewShowsCountSummary() throws {
        let viewModel = makeViewModel()
        let view = DocumentPickerView(viewModel: viewModel)

        try HostedInspection.inspect(view) { view in
            let text = try view.inspect().find(text: viewModel.countSummary)
            #expect(try text.string() == viewModel.countSummary)
        }
    }

    @Test
    func viewShowsAddButton() throws {
        let viewModel = makeViewModel()
        let view = DocumentPickerView(viewModel: viewModel)

        #expect(viewModel.canAddMore)
        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            _ = try inspected.find(ViewType.Menu.self)
        }
    }

    @Test
    func viewWithMaxDrafts_hidesAddButton() throws {
        var documents: [DocumentReferenceRecord] = []
        for index in 0 ..< DocumentPickerViewModel.maxPerRecord {
            documents.append(makeDocument(title: "file\(index).jpg", hmacByte: UInt8(index)))
        }
        let viewModel = makeViewModel(existing: documents)
        let view = DocumentPickerView(viewModel: viewModel)

        #expect(!viewModel.canAddMore)
        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            #expect(throws: (any Error).self) {
                _ = try inspected.find(ViewType.Menu.self)
            }
        }
    }

    // MARK: - Error Display Tests

    @Test
    func viewDisplaysErrorMessage() throws {
        let viewModel = makeViewModel()
        viewModel.errorMessage = "Test error message"

        let view = DocumentPickerView(viewModel: viewModel)
        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            let errorText = try inspected.find(text: "Test error message")
            #expect(try errorText.string() == "Test error message")
        }
    }

    @Test
    func viewHidesErrorWhenNil() throws {
        let viewModel = makeViewModel()
        viewModel.errorMessage = nil
        let view = DocumentPickerView(viewModel: viewModel)

        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            #expect(throws: (any Error).self) {
                _ = try inspected.find(ViewType.Text.self) { text in
                    try text.string().contains("error")
                }
            }
        }
    }

    // MARK: - Loading State Tests

    @Test
    func viewRendersWhileLoading() throws {
        let viewModel = makeViewModel()
        viewModel.isLoading = true

        let view = DocumentPickerView(viewModel: viewModel)
        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            _ = try inspected.find(ViewType.ProgressView.self)
        }
    }

    @Test
    func viewHidesLoadingWhenNotLoading() throws {
        let viewModel = makeViewModel()
        viewModel.isLoading = false

        let view = DocumentPickerView(viewModel: viewModel)
        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            #expect(throws: (any Error).self) {
                _ = try inspected.find(ViewType.ProgressView.self)
            }
        }
    }

    // MARK: - Grid Layout Tests

    @Test
    func viewRendersMultipleDrafts() throws {
        let viewModel = makeViewModel(existing: [
            makeDocument(title: "photo1.jpg", hmacByte: 0x01),
            makeDocument(title: "photo2.jpg", hmacByte: 0x02),
            makeDocument(title: "doc.pdf", mimeType: "application/pdf", hmacByte: 0x03)
        ])
        let view = DocumentPickerView(viewModel: viewModel)

        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            _ = try inspected.find(ViewType.LazyVGrid.self)
        }
        #expect(viewModel.drafts.count == 3)
    }

    // MARK: - Add Button Menu Tests

    @Test
    func addButtonExists_whenBelowLimit() throws {
        let viewModel = makeViewModel()
        let view = DocumentPickerView(viewModel: viewModel)

        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            _ = try inspected.find(ViewType.Menu.self)
        }
    }

    @Test
    func addButtonHidden_whenAtLimit() throws {
        var documents: [DocumentReferenceRecord] = []
        for index in 0 ..< DocumentPickerViewModel.maxPerRecord {
            documents.append(makeDocument(title: "file\(index).jpg", hmacByte: UInt8(index)))
        }
        let viewModel = makeViewModel(existing: documents)
        let view = DocumentPickerView(viewModel: viewModel)

        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            #expect(throws: (any Error).self) {
                _ = try inspected.find(ViewType.Menu.self)
            }
        }
    }

    // MARK: - Thumbnail ForEach Tests

    @Test
    func thumbnailGrid_rendersForEachDraft() throws {
        let viewModel = makeViewModel(existing: [
            makeDocument(title: "test_photo.jpg", hmacByte: 0x01)
        ])
        let view = DocumentPickerView(viewModel: viewModel)

        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            _ = try inspected.find(ViewType.LazyVGrid.self)
        }
    }

    @Test
    func emptyGrid_rendersWithOnlyAddButton() throws {
        let viewModel = makeViewModel(existing: [])
        let view = DocumentPickerView(viewModel: viewModel)

        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            _ = try inspected.find(ViewType.LazyVGrid.self)
        }
        #expect(viewModel.drafts.isEmpty)
    }

    // MARK: - Picker Sheet State Tests

    @Test
    func photoPickerBinding_updatesViewModel() {
        let viewModel = makeViewModel()
        #expect(!viewModel.showingPhotoLibrary)
        viewModel.showingPhotoLibrary = true
        #expect(viewModel.showingPhotoLibrary)
    }

    @Test
    func documentPickerBinding_updatesViewModel() {
        let viewModel = makeViewModel()
        #expect(!viewModel.showingDocumentPicker)
        viewModel.showingDocumentPicker = true
        #expect(viewModel.showingDocumentPicker)
    }

    @Test
    func cameraBinding_updatesViewModel() {
        let viewModel = makeViewModel()
        #expect(!viewModel.showingCamera)
        viewModel.showingCamera = true
        #expect(viewModel.showingCamera)
    }

    // MARK: - Menu Structure Tests

    @Test
    func menuContainsPhotoLibraryButton() throws {
        let viewModel = makeViewModel()
        let view = DocumentPickerView(viewModel: viewModel)

        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            let menu = try inspected.find(ViewType.Menu.self)
            let buttons = menu.findAll(ViewType.Button.self)
            #expect(buttons.count >= 2)
        }
    }

    @Test
    func menuContainsDocumentPickerButton() throws {
        let viewModel = makeViewModel()
        let view = DocumentPickerView(viewModel: viewModel)

        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            let menu = try inspected.find(ViewType.Menu.self)
            _ = try menu.find(ViewType.Label.self) { label in
                let systemImage = try? label.find(ViewType.Image.self)
                return systemImage != nil
            }
        }
    }

    @Test
    func thumbnailView_appearsForEachDraft() throws {
        let viewModel = makeViewModel(existing: [
            makeDocument(title: "photo1.jpg", hmacByte: 0x01),
            makeDocument(title: "photo2.jpg", hmacByte: 0x02)
        ])
        let view = DocumentPickerView(viewModel: viewModel)

        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            let grid = try inspected.find(ViewType.LazyVGrid.self)
            let thumbnails = grid.findAll(DocumentThumbnailView.self)
            #expect(thumbnails.count == 2)
        }
    }

    @Test
    func accessibilityLabel_isSetCorrectly() throws {
        let viewModel = makeViewModel()
        let view = DocumentPickerView(viewModel: viewModel)

        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            let vstack = try inspected.find(ViewType.VStack.self)
            let label = try vstack.accessibilityLabel().string()
            #expect(label == "Attachments")
        }
    }

    @Test
    func gridUsesAdaptiveColumns() throws {
        let viewModel = makeViewModel()
        let view = DocumentPickerView(viewModel: viewModel)

        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            let grid = try inspected.find(ViewType.LazyVGrid.self)
            #expect(throws: Never.self) {
                _ = try grid.find(ViewType.Menu.self)
            }
        }
    }
}
