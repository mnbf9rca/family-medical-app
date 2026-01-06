import CryptoKit
import Foundation
import Testing
import UIKit
@testable import FamilyMedicalApp

@MainActor
struct AttachmentPickerViewModelTests {
    // MARK: - Test Fixtures

    struct TestFixtures {
        let viewModel: AttachmentPickerViewModel
        let attachmentService: MockAttachmentService
        let primaryKeyProvider: MockPrimaryKeyProvider
        let personId: UUID
        let recordId: UUID
        let primaryKey: SymmetricKey
    }

    func makeFixtures(recordId: UUID? = nil, existingAttachments: [FamilyMedicalApp.Attachment] = []) -> TestFixtures {
        let attachmentService = MockAttachmentService()
        let primaryKey = SymmetricKey(size: .bits256)
        let primaryKeyProvider = MockPrimaryKeyProvider(primaryKey: primaryKey)
        let personId = UUID()
        let recordIdToUse = recordId ?? UUID()

        let viewModel = AttachmentPickerViewModel(
            personId: personId,
            recordId: recordIdToUse,
            existingAttachments: existingAttachments,
            attachmentService: attachmentService,
            primaryKeyProvider: primaryKeyProvider
        )

        return TestFixtures(
            viewModel: viewModel,
            attachmentService: attachmentService,
            primaryKeyProvider: primaryKeyProvider,
            personId: personId,
            recordId: recordIdToUse,
            primaryKey: primaryKey
        )
    }

    func makeTestImage(size: CGSize = CGSize(width: 100, height: 100)) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor.blue.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
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

    // MARK: - Initialization Tests

    @Test
    func init_noExistingAttachments_startsEmpty() {
        let fixtures = makeFixtures()

        #expect(fixtures.viewModel.attachments.isEmpty)
        #expect(!fixtures.viewModel.isLoading)
        #expect(fixtures.viewModel.errorMessage == nil)
    }

    @Test
    func init_withExistingAttachments_loadsAttachments() throws {
        let attachment1 = try makeTestAttachment(fileName: "file1.jpg")
        let attachment2 = try makeTestAttachment(fileName: "file2.jpg")

        let fixtures = makeFixtures(existingAttachments: [attachment1, attachment2])

        #expect(fixtures.viewModel.attachments.count == 2)
    }

    // MARK: - Computed Properties Tests

    @Test
    func canAddMore_belowLimit_returnsTrue() {
        let fixtures = makeFixtures()

        #expect(fixtures.viewModel.canAddMore)
    }

    @Test
    func canAddMore_atLimit_returnsFalse() throws {
        var attachments: [FamilyMedicalApp.Attachment] = []
        for index in 0 ..< AttachmentPickerViewModel.maxAttachments {
            try attachments.append(makeTestAttachment(fileName: "file\(index).jpg"))
        }

        let fixtures = makeFixtures(existingAttachments: attachments)

        #expect(!fixtures.viewModel.canAddMore)
    }

    @Test
    func remainingSlots_empty_returnsMax() {
        let fixtures = makeFixtures()

        #expect(fixtures.viewModel.remainingSlots == AttachmentPickerViewModel.maxAttachments)
    }

    @Test
    func remainingSlots_partiallyFilled_returnsCorrect() throws {
        let attachments = try [
            makeTestAttachment(fileName: "file1.jpg"),
            makeTestAttachment(fileName: "file2.jpg")
        ]

        let fixtures = makeFixtures(existingAttachments: attachments)

        #expect(fixtures.viewModel.remainingSlots == AttachmentPickerViewModel.maxAttachments - 2)
    }

    @Test
    func countSummary_formatsCorrectly() throws {
        let attachments = try [
            makeTestAttachment(fileName: "file1.jpg"),
            makeTestAttachment(fileName: "file2.jpg")
        ]

        let fixtures = makeFixtures(existingAttachments: attachments)

        #expect(fixtures.viewModel.countSummary == "2 of \(AttachmentPickerViewModel.maxAttachments) attachments")
    }

    @Test
    func attachmentIds_returnsAllIds() throws {
        let attachment1 = try makeTestAttachment(fileName: "file1.jpg")
        let attachment2 = try makeTestAttachment(fileName: "file2.jpg")

        let fixtures = makeFixtures(existingAttachments: [attachment1, attachment2])

        let ids = fixtures.viewModel.attachmentIds
        #expect(ids.contains(attachment1.id))
        #expect(ids.contains(attachment2.id))
    }

    // MARK: - Add from Camera Tests

    @Test
    func addFromCamera_validImage_addsAttachment() async {
        let fixtures = makeFixtures()
        let image = makeTestImage()

        await fixtures.viewModel.addFromCamera(image)

        #expect(fixtures.viewModel.attachments.count == 1)
        #expect(fixtures.viewModel.errorMessage == nil)
        #expect(!fixtures.viewModel.isLoading)
    }

    @Test
    func addFromCamera_callsService() async {
        let fixtures = makeFixtures()
        let image = makeTestImage()

        await fixtures.viewModel.addFromCamera(image)

        #expect(fixtures.attachmentService.addAttachmentCalls.count == 1)
        let call = fixtures.attachmentService.addAttachmentCalls[0]
        #expect(call.mimeType == "image/jpeg")
        #expect(call.fileName.hasPrefix("Photo_"))
        #expect(call.fileName.hasSuffix(".jpg"))
    }

    @Test
    func addFromCamera_serviceFailure_setsError() async {
        let fixtures = makeFixtures()
        fixtures.attachmentService.shouldFailAddAttachment = true
        let image = makeTestImage()

        await fixtures.viewModel.addFromCamera(image)

        #expect(fixtures.viewModel.attachments.isEmpty)
        #expect(fixtures.viewModel.errorMessage != nil)
    }

    @Test
    func addFromCamera_atLimit_setsError() async throws {
        var attachments: [FamilyMedicalApp.Attachment] = []
        for index in 0 ..< AttachmentPickerViewModel.maxAttachments {
            try attachments.append(makeTestAttachment(fileName: "file\(index).jpg"))
        }

        let fixtures = makeFixtures(existingAttachments: attachments)
        let image = makeTestImage()

        await fixtures.viewModel.addFromCamera(image)

        #expect(fixtures.viewModel.errorMessage != nil)
        #expect(fixtures.attachmentService.addAttachmentCalls.isEmpty)
    }

    @Test
    func addFromCamera_setsLoadingState() async {
        let fixtures = makeFixtures()
        let image = makeTestImage()

        // Cannot directly test loading state during async, but verify it's false after
        await fixtures.viewModel.addFromCamera(image)

        #expect(!fixtures.viewModel.isLoading)
    }

    // MARK: - Remove Attachment Tests

    @Test
    func removeAttachment_existingAttachment_removesFromList() async throws {
        let attachment = try makeTestAttachment()
        let fixtures = makeFixtures(existingAttachments: [attachment])

        await fixtures.viewModel.removeAttachment(attachment)

        #expect(fixtures.viewModel.attachments.isEmpty)
        #expect(fixtures.viewModel.errorMessage == nil)
    }

    @Test
    func removeAttachment_withRecordId_callsDeleteService() async throws {
        let attachment = try makeTestAttachment()
        let recordId = UUID()
        let fixtures = makeFixtures(recordId: recordId, existingAttachments: [attachment])

        await fixtures.viewModel.removeAttachment(attachment)

        #expect(fixtures.attachmentService.deleteAttachmentCalls.count == 1)
        #expect(fixtures.attachmentService.deleteAttachmentCalls[0].attachmentId == attachment.id)
        #expect(fixtures.attachmentService.deleteAttachmentCalls[0].recordId == recordId)
    }

    @Test
    func removeAttachment_serviceFailure_setsError() async throws {
        let attachment = try makeTestAttachment()
        let fixtures = makeFixtures(recordId: UUID(), existingAttachments: [attachment])
        fixtures.attachmentService.shouldFailDeleteAttachment = true

        await fixtures.viewModel.removeAttachment(attachment)

        #expect(fixtures.viewModel.errorMessage != nil)
        // Attachment stays in list on failure
        #expect(fixtures.viewModel.attachments.count == 1)
    }

    @Test
    func removeAttachment_noRecordId_stillRemovesFromList() async throws {
        // For new records without recordId
        let attachment = try makeTestAttachment()
        let attachmentService = MockAttachmentService()
        let primaryKeyProvider = MockPrimaryKeyProvider(primaryKey: SymmetricKey(size: .bits256))

        let viewModel = AttachmentPickerViewModel(
            personId: UUID(),
            recordId: nil, // No record ID
            existingAttachments: [attachment],
            attachmentService: attachmentService,
            primaryKeyProvider: primaryKeyProvider
        )

        await viewModel.removeAttachment(attachment)

        // Should remove locally without calling service delete
        #expect(viewModel.attachments.isEmpty)
    }

    // MARK: - Sheet State Tests

    @Test
    func showingCamera_initiallyFalse() {
        let fixtures = makeFixtures()

        #expect(!fixtures.viewModel.showingCamera)
    }

    @Test
    func showingPhotoLibrary_initiallyFalse() {
        let fixtures = makeFixtures()

        #expect(!fixtures.viewModel.showingPhotoLibrary)
    }

    @Test
    func showingDocumentPicker_initiallyFalse() {
        let fixtures = makeFixtures()

        #expect(!fixtures.viewModel.showingDocumentPicker)
    }

    // MARK: - Error Handling Tests

    @Test
    func addFromCamera_primaryKeyFailure_setsError() async {
        let attachmentService = MockAttachmentService()
        let primaryKeyProvider = MockPrimaryKeyProvider(shouldFail: true)

        let viewModel = AttachmentPickerViewModel(
            personId: UUID(),
            recordId: UUID(),
            attachmentService: attachmentService,
            primaryKeyProvider: primaryKeyProvider
        )

        let image = makeTestImage()
        await viewModel.addFromCamera(image)

        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.attachments.isEmpty)
    }

    // MARK: - Multiple Additions Tests

    @Test
    func addFromCamera_multiple_addsAll() async {
        let fixtures = makeFixtures()

        await fixtures.viewModel.addFromCamera(makeTestImage())
        await fixtures.viewModel.addFromCamera(makeTestImage())
        await fixtures.viewModel.addFromCamera(makeTestImage())

        #expect(fixtures.viewModel.attachments.count == 3)
    }

    @Test
    func addFromCamera_stopAtLimit() async throws {
        // Start with some attachments
        var attachments: [FamilyMedicalApp.Attachment] = []
        for index in 0 ..< (AttachmentPickerViewModel.maxAttachments - 1) {
            try attachments.append(makeTestAttachment(fileName: "file\(index).jpg"))
        }

        let fixtures = makeFixtures(existingAttachments: attachments)

        // Add one more (should work)
        await fixtures.viewModel.addFromCamera(makeTestImage())
        #expect(fixtures.viewModel.attachments.count == AttachmentPickerViewModel.maxAttachments)

        // Try to add another (should fail)
        await fixtures.viewModel.addFromCamera(makeTestImage())
        #expect(fixtures.viewModel.attachments.count == AttachmentPickerViewModel.maxAttachments)
        #expect(fixtures.viewModel.errorMessage != nil)
    }

    // MARK: - MIME Type Detection Tests

    @Test
    func addFromCamera_generatesJPEGFileName() async {
        let fixtures = makeFixtures()
        let image = makeTestImage()

        await fixtures.viewModel.addFromCamera(image)

        let call = fixtures.attachmentService.addAttachmentCalls[0]
        #expect(call.mimeType == "image/jpeg")
        #expect(call.fileName.hasSuffix(".jpg"))
    }
}
