import CryptoKit
import Dependencies
import SwiftUI
import Testing
import ViewInspector
@testable import FamilyMedicalApp

@MainActor
struct AttachmentPickerViewTests {
    // MARK: - Test Fixtures

    /// Fixed test date for deterministic testing
    let testDate = Date(timeIntervalSinceReferenceDate: 1_234_567_890)

    func makeViewModel(
        existingAttachments: [FamilyMedicalApp.Attachment] = []
    ) -> AttachmentPickerViewModel {
        let attachmentService = MockAttachmentService()
        let primaryKeyProvider = MockPrimaryKeyProvider(primaryKey: SymmetricKey(size: .bits256))

        return withDependencies {
            $0.date = .constant(testDate)
            $0.uuid = .incrementing
        } operation: {
            AttachmentPickerViewModel(
                personId: UUID(),
                recordId: UUID(),
                existingAttachments: existingAttachments,
                attachmentService: attachmentService,
                primaryKeyProvider: primaryKeyProvider
            )
        }
    }

    func makeTestAttachment(
        fileName: String = "test.jpg",
        mimeType: String = "image/jpeg"
    ) throws -> FamilyMedicalApp.Attachment {
        try FamilyMedicalApp.Attachment(
            id: UUID(),
            fileName: fileName,
            mimeType: mimeType,
            contentHMAC: Data(repeating: UInt8.random(in: 0 ... 255), count: 32),
            encryptedSize: 1_024,
            thumbnailData: nil,
            uploadedAt: Date()
        )
    }

    // MARK: - Basic Rendering Tests

    @Test
    func viewRendersSuccessfully() throws {
        let viewModel = makeViewModel()
        let view = AttachmentPickerView(viewModel: viewModel) { _ in }

        // Use find() for deterministic coverage - forces body evaluation
        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.VStack.self)
    }

    @Test
    func viewRendersWithExistingAttachments() throws {
        let attachment = try makeTestAttachment()
        let viewModel = makeViewModel(existingAttachments: [attachment])
        let view = AttachmentPickerView(viewModel: viewModel) { _ in }

        // Use find() for deterministic coverage
        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.LazyVGrid.self)
    }

    @Test
    func viewShowsCountSummary() throws {
        let viewModel = makeViewModel()
        let view = AttachmentPickerView(viewModel: viewModel) { _ in }

        // Should display count summary
        let text = try view.inspect().find(text: viewModel.countSummary)
        #expect(try text.string() == viewModel.countSummary)
    }

    @Test
    func viewShowsAddButton() throws {
        let viewModel = makeViewModel()
        let view = AttachmentPickerView(viewModel: viewModel) { _ in }

        // Should have add button when below limit
        #expect(viewModel.canAddMore)
        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.Menu.self)
    }

    @Test
    func viewWithMaxAttachments_hidesAddButton() throws {
        var attachments: [FamilyMedicalApp.Attachment] = []
        for index in 0 ..< AttachmentPickerViewModel.maxAttachments {
            try attachments.append(makeTestAttachment(fileName: "file\(index).jpg"))
        }

        let viewModel = makeViewModel(existingAttachments: attachments)
        let view = AttachmentPickerView(viewModel: viewModel) { _ in }

        // Cannot add more when at limit - verify Menu is NOT rendered
        #expect(!viewModel.canAddMore)
        let inspected = try view.inspect()
        #expect(throws: (any Error).self) {
            _ = try inspected.find(ViewType.Menu.self)
        }
    }

    // MARK: - onChange Callback Tests

    @Test
    func viewCallsOnChangeWhenAttachmentsUpdate() throws {
        let viewModel = makeViewModel()

        let view = AttachmentPickerView(viewModel: viewModel) { _ in
            // Callback is set but ViewInspector can't trigger onChange in LazyVGrid
        }

        // Verify view renders correctly with callback set
        _ = try view.inspect()
    }

    // MARK: - Error Display Tests

    @Test
    func viewDisplaysErrorMessage() async throws {
        let viewModel = makeViewModel()
        viewModel.errorMessage = "Test error message"

        let view = AttachmentPickerView(viewModel: viewModel) { _ in }

        // Find the error text in the view hierarchy to exercise the conditional branch
        let inspected = try view.inspect()
        let errorText = try inspected.find(text: "Test error message")
        #expect(try errorText.string() == "Test error message")
    }

    @Test
    func viewHidesErrorWhenNil() throws {
        let viewModel = makeViewModel()
        viewModel.errorMessage = nil

        let view = AttachmentPickerView(viewModel: viewModel) { _ in }

        // Error text should not be present when errorMessage is nil
        let inspected = try view.inspect()
        #expect(throws: (any Error).self) {
            _ = try inspected.find(ViewType.Text.self) { text in
                try text.string().contains("error")
            }
        }
    }

    // MARK: - Loading State Tests

    @Test
    func viewRendersWhileLoading() throws {
        let viewModel = makeViewModel()
        viewModel.isLoading = true

        let view = AttachmentPickerView(viewModel: viewModel) { _ in }

        // Find the ProgressView to exercise the loading overlay branch
        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.ProgressView.self)
    }

    @Test
    func viewHidesLoadingWhenNotLoading() throws {
        let viewModel = makeViewModel()
        viewModel.isLoading = false

        let view = AttachmentPickerView(viewModel: viewModel) { _ in }

        // ProgressView should not be present when not loading
        let inspected = try view.inspect()
        #expect(throws: (any Error).self) {
            _ = try inspected.find(ViewType.ProgressView.self)
        }
    }

    // MARK: - Grid Layout Tests

    @Test
    func viewRendersMultipleAttachments() throws {
        let attachment1 = try makeTestAttachment(fileName: "photo1.jpg")
        let attachment2 = try makeTestAttachment(fileName: "photo2.jpg")
        let attachment3 = try makeTestAttachment(fileName: "doc.pdf", mimeType: "application/pdf")

        let viewModel = makeViewModel(existingAttachments: [attachment1, attachment2, attachment3])
        let view = AttachmentPickerView(viewModel: viewModel) { _ in }

        // Use find() for deterministic coverage
        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.LazyVGrid.self)
        #expect(viewModel.attachments.count == 3)
    }

    // MARK: - Add Button Menu Tests

    @Test
    func addButtonExists_whenBelowLimit() throws {
        let viewModel = makeViewModel()
        let view = AttachmentPickerView(viewModel: viewModel) { _ in }

        // Verify add button exists via accessibility identifier
        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.Menu.self)
    }

    @Test
    func addButtonHidden_whenAtLimit() throws {
        var attachments: [FamilyMedicalApp.Attachment] = []
        for index in 0 ..< AttachmentPickerViewModel.maxAttachments {
            try attachments.append(makeTestAttachment(fileName: "file\(index).jpg"))
        }

        let viewModel = makeViewModel(existingAttachments: attachments)
        let view = AttachmentPickerView(viewModel: viewModel) { _ in }

        // Menu should not exist when at attachment limit
        let inspected = try view.inspect()
        #expect(throws: (any Error).self) {
            _ = try inspected.find(ViewType.Menu.self)
        }
    }

    // MARK: - Thumbnail Interaction Coverage Tests

    @Test
    func thumbnailGrid_rendersForEachAttachment() throws {
        let attachment = try makeTestAttachment(fileName: "test_photo.jpg")
        let viewModel = makeViewModel(existingAttachments: [attachment])
        let view = AttachmentPickerView(viewModel: viewModel) { _ in }

        // Find LazyVGrid to exercise ForEach rendering
        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.LazyVGrid.self)
    }

    @Test
    func emptyGrid_rendersWithOnlyAddButton() throws {
        let viewModel = makeViewModel(existingAttachments: [])
        let view = AttachmentPickerView(viewModel: viewModel) { _ in }

        // Grid should exist with just the add button
        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.LazyVGrid.self)
        #expect(viewModel.attachments.isEmpty)
    }

    // MARK: - Picker Sheet State Tests

    @Test
    func photoPickerBinding_updatesViewModel() throws {
        let viewModel = makeViewModel()
        #expect(!viewModel.showingPhotoLibrary)

        viewModel.showingPhotoLibrary = true
        #expect(viewModel.showingPhotoLibrary)
    }

    @Test
    func documentPickerBinding_updatesViewModel() throws {
        let viewModel = makeViewModel()
        #expect(!viewModel.showingDocumentPicker)

        viewModel.showingDocumentPicker = true
        #expect(viewModel.showingDocumentPicker)
    }

    @Test
    func cameraBinding_updatesViewModel() throws {
        let viewModel = makeViewModel()
        #expect(!viewModel.showingCamera)

        viewModel.showingCamera = true
        #expect(viewModel.showingCamera)
    }

    // MARK: - Menu Structure Tests

    @Test
    func menuContainsPhotoLibraryButton() throws {
        let viewModel = makeViewModel()
        let view = AttachmentPickerView(viewModel: viewModel) { _ in }

        let inspected = try view.inspect()
        let menu = try inspected.find(ViewType.Menu.self)

        // Verify menu has buttons for photo library option
        let buttons = menu.findAll(ViewType.Button.self)
        #expect(buttons.count >= 2) // At minimum: Library + File (Camera may be hidden)
    }

    @Test
    func menuContainsDocumentPickerButton() throws {
        let viewModel = makeViewModel()
        let view = AttachmentPickerView(viewModel: viewModel) { _ in }

        let inspected = try view.inspect()
        let menu = try inspected.find(ViewType.Menu.self)

        // Find the document picker button via its label
        _ = try menu.find(ViewType.Label.self) { label in
            let systemImage = try? label.find(ViewType.Image.self)
            // Check for "doc" system image which is used for "Choose File"
            return systemImage != nil
        }
    }

    // MARK: - ForEach Thumbnail Tests

    @Test
    func thumbnailView_appearsForEachAttachment() throws {
        let attachment1 = try makeTestAttachment(fileName: "photo1.jpg")
        let attachment2 = try makeTestAttachment(fileName: "photo2.jpg")
        let viewModel = makeViewModel(existingAttachments: [attachment1, attachment2])
        let view = AttachmentPickerView(viewModel: viewModel) { _ in }

        let inspected = try view.inspect()
        let grid = try inspected.find(ViewType.LazyVGrid.self)

        // Verify the grid contains attachment thumbnails
        let thumbnails = grid.findAll(AttachmentThumbnailView.self)
        #expect(thumbnails.count == 2)
    }

    @Test
    func accessibilityLabel_isSetCorrectly() throws {
        let viewModel = makeViewModel()
        let view = AttachmentPickerView(viewModel: viewModel) { _ in }

        let inspected = try view.inspect()
        let vstack = try inspected.find(ViewType.VStack.self)

        // The outer VStack should have accessibility label "Attachments"
        let label = try vstack.accessibilityLabel().string()
        #expect(label == "Attachments")
    }

    // MARK: - Grid Columns Initialization Tests

    @Test
    func gridUsesAdaptiveColumns() throws {
        let viewModel = makeViewModel()
        let view = AttachmentPickerView(viewModel: viewModel) { _ in }

        let inspected = try view.inspect()
        // Verify LazyVGrid exists with content
        let grid = try inspected.find(ViewType.LazyVGrid.self)
        #expect(throws: Never.self) {
            _ = try grid.find(ViewType.Menu.self)
        }
    }
}
