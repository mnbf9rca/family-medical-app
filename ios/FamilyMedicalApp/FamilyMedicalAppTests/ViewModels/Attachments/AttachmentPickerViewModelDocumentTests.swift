import CryptoKit
import Foundation
import Testing
import UIKit
@testable import FamilyMedicalApp

/// Document picker and constants tests for AttachmentPickerViewModel
/// Split from main test file to satisfy type_body_length limit
@MainActor
struct AttachmentPickerViewModelDocumentTests {
    // MARK: - Test Fixtures

    struct TestFixtures {
        let viewModel: AttachmentPickerViewModel
        let attachmentService: MockAttachmentService
        let primaryKeyProvider: MockPrimaryKeyProvider
        let personId: UUID
        let recordId: UUID
        let primaryKey: SymmetricKey
    }

    func makeFixtures(
        recordId: UUID? = nil,
        existingAttachments: [FamilyMedicalApp.Attachment] = []
    ) -> TestFixtures {
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

    // MARK: - Add from Document Picker Tests

    @Test
    func addFromDocumentPicker_validURL_addsAttachment() async throws {
        let fixtures = makeFixtures()

        // Create a temporary test file
        let tempDir = FileManager.default.temporaryDirectory
        let testFileURL = tempDir.appendingPathComponent("test_doc.pdf")
        let testData = Data("%PDF-1.4 test".utf8)
        try testData.write(to: testFileURL)
        defer { try? FileManager.default.removeItem(at: testFileURL) }

        await fixtures.viewModel.addFromDocumentPicker([testFileURL])

        #expect(fixtures.viewModel.attachments.count == 1)
        #expect(fixtures.attachmentService.addAttachmentCalls.count == 1)
    }

    @Test
    func addFromDocumentPicker_atLimit_setsError() async throws {
        var attachments: [FamilyMedicalApp.Attachment] = []
        for index in 0 ..< AttachmentPickerViewModel.maxAttachments {
            try attachments.append(makeTestAttachment(fileName: "file\(index).jpg"))
        }

        let fixtures = makeFixtures(existingAttachments: attachments)

        let tempDir = FileManager.default.temporaryDirectory
        let testFileURL = tempDir.appendingPathComponent("test_doc.pdf")
        let testData = Data("%PDF-1.4 test".utf8)
        try testData.write(to: testFileURL)
        defer { try? FileManager.default.removeItem(at: testFileURL) }

        await fixtures.viewModel.addFromDocumentPicker([testFileURL])

        #expect(fixtures.viewModel.errorMessage != nil)
        #expect(fixtures.attachmentService.addAttachmentCalls.isEmpty)
    }

    @Test
    func addFromDocumentPicker_serviceFailure_setsError() async throws {
        let fixtures = makeFixtures()
        fixtures.attachmentService.shouldFailAddAttachment = true

        let tempDir = FileManager.default.temporaryDirectory
        let testFileURL = tempDir.appendingPathComponent("test_doc.pdf")
        let testData = Data("%PDF-1.4 test".utf8)
        try testData.write(to: testFileURL)
        defer { try? FileManager.default.removeItem(at: testFileURL) }

        await fixtures.viewModel.addFromDocumentPicker([testFileURL])

        #expect(fixtures.viewModel.errorMessage != nil)
    }

    @Test
    func addFromDocumentPicker_multipleFiles_addsAll() async throws {
        let fixtures = makeFixtures()

        let tempDir = FileManager.default.temporaryDirectory
        var urls: [URL] = []

        for index in 0 ..< 3 {
            let testFileURL = tempDir.appendingPathComponent("test_doc_\(index).pdf")
            let testData = Data("%PDF-1.4 test \(index)".utf8)
            try testData.write(to: testFileURL)
            urls.append(testFileURL)
        }
        defer {
            urls.forEach { try? FileManager.default.removeItem(at: $0) }
        }

        await fixtures.viewModel.addFromDocumentPicker(urls)

        #expect(fixtures.viewModel.attachments.count == 3)
    }

    // MARK: - Constants Tests

    @Test
    func maxAttachments_matchesServiceConstant() {
        #expect(AttachmentPickerViewModel.maxAttachments == AttachmentService.maxAttachmentsPerRecord)
    }

    @Test
    func maxFileSizeBytes_matchesServiceConstant() {
        #expect(AttachmentPickerViewModel.maxFileSizeBytes == AttachmentService.maxFileSizeBytes)
    }

    // MARK: - New Record Tests (no recordId)

    @Test
    func init_withoutRecordId_canAddAttachments() async {
        let attachmentService = MockAttachmentService()
        let primaryKeyProvider = MockPrimaryKeyProvider(primaryKey: SymmetricKey(size: .bits256))

        let viewModel = AttachmentPickerViewModel(
            personId: UUID(),
            recordId: nil,
            attachmentService: attachmentService,
            primaryKeyProvider: primaryKeyProvider
        )

        let image = makeTestImage()
        await viewModel.addFromCamera(image)

        #expect(viewModel.attachments.count == 1)
        // Should use a temporary record ID
        #expect(attachmentService.addAttachmentCalls.count == 1)
    }

    // MARK: - MIME Type Detection Tests

    @Test
    func addFromDocumentPicker_detectsMimeTypeFromExtension_jpeg() async throws {
        let fixtures = makeFixtures()

        let tempDir = FileManager.default.temporaryDirectory
        let testFileURL = tempDir.appendingPathComponent("photo.jpeg")
        // JPEG magic bytes
        let jpegData = Data([0xFF, 0xD8, 0xFF, 0xE0]) + Data("test content".utf8)
        try jpegData.write(to: testFileURL)
        defer { try? FileManager.default.removeItem(at: testFileURL) }

        await fixtures.viewModel.addFromDocumentPicker([testFileURL])

        #expect(fixtures.attachmentService.addAttachmentCalls.count == 1)
        #expect(fixtures.attachmentService.addAttachmentCalls[0].mimeType == "image/jpeg")
    }

    @Test
    func addFromDocumentPicker_detectsMimeTypeFromExtension_jpg() async throws {
        let fixtures = makeFixtures()

        let tempDir = FileManager.default.temporaryDirectory
        let testFileURL = tempDir.appendingPathComponent("photo.jpg")
        let jpegData = Data([0xFF, 0xD8, 0xFF, 0xE0]) + Data("test".utf8)
        try jpegData.write(to: testFileURL)
        defer { try? FileManager.default.removeItem(at: testFileURL) }

        await fixtures.viewModel.addFromDocumentPicker([testFileURL])

        #expect(fixtures.attachmentService.addAttachmentCalls.count == 1)
        #expect(fixtures.attachmentService.addAttachmentCalls[0].mimeType == "image/jpeg")
    }

    @Test
    func addFromDocumentPicker_detectsMimeTypeFromExtension_png() async throws {
        let fixtures = makeFixtures()

        let tempDir = FileManager.default.temporaryDirectory
        let testFileURL = tempDir.appendingPathComponent("image.png")
        // PNG magic bytes
        let pngData = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) + Data("test".utf8)
        try pngData.write(to: testFileURL)
        defer { try? FileManager.default.removeItem(at: testFileURL) }

        await fixtures.viewModel.addFromDocumentPicker([testFileURL])

        #expect(fixtures.attachmentService.addAttachmentCalls.count == 1)
        #expect(fixtures.attachmentService.addAttachmentCalls[0].mimeType == "image/png")
    }

    @Test
    func addFromDocumentPicker_unknownExtension_fallsToOctetStream() async throws {
        let fixtures = makeFixtures()

        let tempDir = FileManager.default.temporaryDirectory
        let testFileURL = tempDir.appendingPathComponent("file.xyz")
        let data = Data("unknown file type".utf8)
        try data.write(to: testFileURL)
        defer { try? FileManager.default.removeItem(at: testFileURL) }

        await fixtures.viewModel.addFromDocumentPicker([testFileURL])

        #expect(fixtures.attachmentService.addAttachmentCalls.count == 1)
        #expect(fixtures.attachmentService.addAttachmentCalls[0].mimeType == "application/octet-stream")
    }

    @Test
    func addFromDocumentPicker_preservesOriginalFileName() async throws {
        let fixtures = makeFixtures()

        let tempDir = FileManager.default.temporaryDirectory
        let testFileURL = tempDir.appendingPathComponent("my_medical_document.pdf")
        let pdfData = Data("%PDF-1.4 test".utf8)
        try pdfData.write(to: testFileURL)
        defer { try? FileManager.default.removeItem(at: testFileURL) }

        await fixtures.viewModel.addFromDocumentPicker([testFileURL])

        #expect(fixtures.attachmentService.addAttachmentCalls.count == 1)
        #expect(fixtures.attachmentService.addAttachmentCalls[0].fileName == "my_medical_document.pdf")
    }

    // MARK: - Primary Key Failure Tests

    @Test
    func addFromDocumentPicker_primaryKeyFailure_setsError() async throws {
        let attachmentService = MockAttachmentService()
        let primaryKeyProvider = MockPrimaryKeyProvider(shouldFail: true)

        let viewModel = AttachmentPickerViewModel(
            personId: UUID(),
            recordId: UUID(),
            attachmentService: attachmentService,
            primaryKeyProvider: primaryKeyProvider
        )

        let tempDir = FileManager.default.temporaryDirectory
        let testFileURL = tempDir.appendingPathComponent("test.pdf")
        let pdfData = Data("%PDF-1.4 test".utf8)
        try pdfData.write(to: testFileURL)
        defer { try? FileManager.default.removeItem(at: testFileURL) }

        await viewModel.addFromDocumentPicker([testFileURL])

        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.attachments.isEmpty)
    }

    // MARK: - Non-Existent File Tests

    @Test
    func addFromDocumentPicker_nonExistentFile_setsError() async throws {
        let fixtures = makeFixtures()

        // URL to a file that doesn't exist - won't be able to access it
        let nonExistentURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("does_not_exist_\(UUID()).pdf")

        await fixtures.viewModel.addFromDocumentPicker([nonExistentURL])

        // Should fail gracefully with error message
        #expect(fixtures.viewModel.errorMessage != nil)
    }

    // MARK: - Multiple Files with Limit Tests

    @Test
    func addFromDocumentPicker_stopsAtLimit_setsError() async throws {
        // Start with some attachments
        var attachments: [FamilyMedicalApp.Attachment] = []
        for index in 0 ..< (AttachmentPickerViewModel.maxAttachments - 1) {
            try attachments.append(makeTestAttachment(fileName: "file\(index).jpg"))
        }

        let fixtures = makeFixtures(existingAttachments: attachments)

        let tempDir = FileManager.default.temporaryDirectory
        var urls: [URL] = []

        // Create 3 files (only 1 slot available)
        for index in 0 ..< 3 {
            let testFileURL = tempDir.appendingPathComponent("test_\(index).pdf")
            let pdfData = Data("%PDF-1.4 test \(index)".utf8)
            try pdfData.write(to: testFileURL)
            urls.append(testFileURL)
        }
        defer {
            urls.forEach { try? FileManager.default.removeItem(at: $0) }
        }

        await fixtures.viewModel.addFromDocumentPicker(urls)

        // Should add only one and set error for the rest
        #expect(fixtures.viewModel.attachments.count == AttachmentPickerViewModel.maxAttachments)
        #expect(fixtures.viewModel.errorMessage != nil)
    }
}
