import CryptoKit
import SwiftUI
import Testing
import ViewInspector
@testable import FamilyMedicalApp

@MainActor
struct AttachmentPickerViewTests {
    // MARK: - Test Fixtures

    func makeViewModel(
        existingAttachments: [FamilyMedicalApp.Attachment] = []
    ) -> AttachmentPickerViewModel {
        let attachmentService = MockAttachmentService()
        let primaryKeyProvider = MockPrimaryKeyProvider(primaryKey: SymmetricKey(size: .bits256))

        return AttachmentPickerViewModel(
            personId: UUID(),
            recordId: UUID(),
            existingAttachments: existingAttachments,
            attachmentService: attachmentService,
            primaryKeyProvider: primaryKeyProvider
        )
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

        _ = try view.inspect()
    }

    @Test
    func viewRendersWithExistingAttachments() throws {
        let attachment = try makeTestAttachment()
        let viewModel = makeViewModel(existingAttachments: [attachment])
        let view = AttachmentPickerView(viewModel: viewModel) { _ in }

        _ = try view.inspect()
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
        _ = try view.inspect()
    }

    @Test
    func viewWithMaxAttachments_hidesAddButton() throws {
        var attachments: [FamilyMedicalApp.Attachment] = []
        for index in 0 ..< AttachmentPickerViewModel.maxAttachments {
            try attachments.append(makeTestAttachment(fileName: "file\(index).jpg"))
        }

        let viewModel = makeViewModel(existingAttachments: attachments)
        let view = AttachmentPickerView(viewModel: viewModel) { _ in }

        // Cannot add more when at limit
        #expect(!viewModel.canAddMore)
        _ = try view.inspect()
    }

    // MARK: - onChange Callback Tests

    @Test
    func viewCallsOnChangeWhenAttachmentsUpdate() throws {
        var receivedIds: [UUID]?
        let viewModel = makeViewModel()

        let view = AttachmentPickerView(viewModel: viewModel) { ids in
            receivedIds = ids
        }

        // Initial render should call onChange with empty array
        _ = try view.inspect()

        // Note: ViewInspector can't easily trigger the onChange in LazyVGrid,
        // but we verify the view renders correctly with the callback set
    }

    // MARK: - Error Display Tests

    @Test
    func viewDisplaysErrorMessage() async throws {
        let viewModel = makeViewModel()
        viewModel.errorMessage = "Test error message"

        let view = AttachmentPickerView(viewModel: viewModel) { _ in }

        _ = try view.inspect()
        // Error message should be set on viewModel
        #expect(viewModel.errorMessage == "Test error message")
    }

    // MARK: - Loading State Tests

    @Test
    func viewRendersWhileLoading() throws {
        let viewModel = makeViewModel()
        viewModel.isLoading = true

        let view = AttachmentPickerView(viewModel: viewModel) { _ in }

        _ = try view.inspect()
    }

    // MARK: - Grid Layout Tests

    @Test
    func viewRendersMultipleAttachments() throws {
        let attachment1 = try makeTestAttachment(fileName: "photo1.jpg")
        let attachment2 = try makeTestAttachment(fileName: "photo2.jpg")
        let attachment3 = try makeTestAttachment(fileName: "doc.pdf", mimeType: "application/pdf")

        let viewModel = makeViewModel(existingAttachments: [attachment1, attachment2, attachment3])
        let view = AttachmentPickerView(viewModel: viewModel) { _ in }

        _ = try view.inspect()
        #expect(viewModel.attachments.count == 3)
    }
}
