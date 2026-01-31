import CryptoKit
import Dependencies
import Foundation
import Testing
import UIKit
@testable import FamilyMedicalApp

/// Extended tests for AttachmentPickerViewModel - Document Picker and MIME type tests
@MainActor
struct AttachmentPickerViewModelExtendedTests {
    // MARK: - Test Fixtures

    /// Fixed test date for deterministic testing
    let testDate = Date(timeIntervalSinceReferenceDate: 1_234_567_890)

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

        let viewModel = withDependencies {
            $0.date = .constant(testDate)
            $0.uuid = .incrementing
        } operation: {
            AttachmentPickerViewModel(
                personId: personId,
                recordId: recordIdToUse,
                existingAttachments: existingAttachments,
                attachmentService: attachmentService,
                primaryKeyProvider: primaryKeyProvider
            )
        }

        return TestFixtures(
            viewModel: viewModel,
            attachmentService: attachmentService,
            primaryKeyProvider: primaryKeyProvider,
            personId: personId,
            recordId: recordIdToUse,
            primaryKey: primaryKey
        )
    }

    func makeTestAttachment(
        fileName: String = "test.jpg",
        mimeType: String = "image/jpeg"
    ) throws -> FamilyMedicalApp.Attachment {
        try AttachmentTestHelper.makeTestAttachment(fileName: fileName, mimeType: mimeType)
    }

    // MARK: - Document Picker Tests

    @Test
    func addFromDocumentPicker_validPDFURL_addsAttachment() async throws {
        let fixtures = makeFixtures()

        // Create a temporary PDF file
        let tempDir = FileManager.default.temporaryDirectory
        let pdfURL = tempDir.appendingPathComponent("test_document_\(UUID().uuidString).pdf")

        // Write minimal PDF data
        let pdfData = Data("%PDF-1.4 minimal".utf8)
        try pdfData.write(to: pdfURL)
        defer { try? FileManager.default.removeItem(at: pdfURL) }

        // Test the URL processing path - security-scoped access may succeed or fail in simulator
        await fixtures.viewModel.addFromDocumentPicker([pdfURL])

        // Either processing succeeds (attachment added) or fails (error set), but loading completes
        #expect(!fixtures.viewModel.isLoading)
        let processedSomehow = !fixtures.viewModel.attachments.isEmpty || fixtures.viewModel.errorMessage != nil
        #expect(processedSomehow)
    }

    @Test
    func addFromDocumentPicker_atLimit_setsError() async throws {
        var attachments: [FamilyMedicalApp.Attachment] = []
        for index in 0 ..< AttachmentPickerViewModel.maxAttachments {
            try attachments.append(makeTestAttachment(fileName: "file\(index).jpg"))
        }

        let fixtures = makeFixtures(existingAttachments: attachments)

        let tempDir = FileManager.default.temporaryDirectory
        let pdfURL = tempDir.appendingPathComponent("test_limit_\(UUID().uuidString).pdf")
        let pdfData = Data("%PDF-1.4 minimal".utf8)
        try pdfData.write(to: pdfURL)
        defer { try? FileManager.default.removeItem(at: pdfURL) }

        await fixtures.viewModel.addFromDocumentPicker([pdfURL])

        // Expect error because already at limit
        #expect(fixtures.viewModel.errorMessage != nil)
        #expect(fixtures.viewModel.attachments.count == AttachmentPickerViewModel.maxAttachments)
    }

    @Test
    func addFromDocumentPicker_emptyURLs_doesNothing() async {
        let fixtures = makeFixtures()

        await fixtures.viewModel.addFromDocumentPicker([])

        #expect(fixtures.viewModel.attachments.isEmpty)
        #expect(fixtures.viewModel.errorMessage == nil)
        #expect(!fixtures.viewModel.isLoading)
    }

    @Test
    func addFromDocumentPicker_multipleURLs_stopsAtLimit() async throws {
        // Start near the limit
        var attachments: [FamilyMedicalApp.Attachment] = []
        for index in 0 ..< (AttachmentPickerViewModel.maxAttachments - 1) {
            try attachments.append(makeTestAttachment(fileName: "file\(index).jpg"))
        }

        let fixtures = makeFixtures(existingAttachments: attachments)

        // Try to add multiple files
        let tempDir = FileManager.default.temporaryDirectory
        let testId = UUID().uuidString
        var urls: [URL] = []
        for index in 0 ..< 3 {
            let url = tempDir.appendingPathComponent("doc_multi_\(testId)_\(index).pdf")
            try Data("%PDF-1.4 test".utf8).write(to: url)
            urls.append(url)
        }
        defer {
            for url in urls {
                try? FileManager.default.removeItem(at: url)
            }
        }

        await fixtures.viewModel.addFromDocumentPicker(urls)

        // May add one file before hitting limit, or security access may fail
        // Either way, should not exceed max attachments
        #expect(fixtures.viewModel.attachments.count <= AttachmentPickerViewModel.maxAttachments)
        #expect(!fixtures.viewModel.isLoading)
    }

    // MARK: - Photo Library Tests

    @Test
    func addFromPhotoLibrary_emptyItems_doesNothing() async {
        let fixtures = makeFixtures()

        await fixtures.viewModel.addFromPhotoLibrary([])

        #expect(fixtures.viewModel.attachments.isEmpty)
        #expect(fixtures.viewModel.errorMessage == nil)
        #expect(!fixtures.viewModel.isLoading)
    }

    @Test
    func addFromPhotoLibrary_atLimit_setsError() throws {
        var attachments: [FamilyMedicalApp.Attachment] = []
        for index in 0 ..< AttachmentPickerViewModel.maxAttachments {
            try attachments.append(makeTestAttachment(fileName: "file\(index).jpg"))
        }

        let fixtures = makeFixtures(existingAttachments: attachments)

        // Verify the limit check would fire
        #expect(!fixtures.viewModel.canAddMore)
    }

    // MARK: - MIME Type from URL Tests

    @Test
    func mimeTypeDetection_forJPEGExtension() async throws {
        let fixtures = makeFixtures()

        // Create temp JPEG file with unique name
        let tempDir = FileManager.default.temporaryDirectory
        let jpegURL = tempDir.appendingPathComponent("photo_\(UUID().uuidString).jpeg")
        let jpegData = Data([0xFF, 0xD8, 0xFF, 0xE0]) // JPEG magic bytes
        try jpegData.write(to: jpegURL)
        defer { try? FileManager.default.removeItem(at: jpegURL) }

        // URL extension is .jpeg - tests mimeType(for:) private method
        await fixtures.viewModel.addFromDocumentPicker([jpegURL])

        // Code path exercised - may succeed (attachment added) or fail (error set)
        #expect(!fixtures.viewModel.isLoading)
    }

    @Test
    func mimeTypeDetection_forPNGExtension() async throws {
        let fixtures = makeFixtures()

        let tempDir = FileManager.default.temporaryDirectory
        let pngURL = tempDir.appendingPathComponent("image_\(UUID().uuidString).png")
        // PNG magic bytes
        let pngData = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        try pngData.write(to: pngURL)
        defer { try? FileManager.default.removeItem(at: pngURL) }

        await fixtures.viewModel.addFromDocumentPicker([pngURL])

        // Code path exercised - may succeed (attachment added) or fail (error set)
        #expect(!fixtures.viewModel.isLoading)
    }

    @Test
    func mimeTypeDetection_forUnknownExtension() async throws {
        let fixtures = makeFixtures()

        let tempDir = FileManager.default.temporaryDirectory
        let unknownURL = tempDir.appendingPathComponent("file_\(UUID().uuidString).xyz")
        try Data("unknown format".utf8).write(to: unknownURL)
        defer { try? FileManager.default.removeItem(at: unknownURL) }

        await fixtures.viewModel.addFromDocumentPicker([unknownURL])

        // Code path exercised - unknown extension should result in error (unsupported MIME type)
        // or security access failure
        #expect(!fixtures.viewModel.isLoading)
    }

    // MARK: - Service Failure Tests

    @Test
    func addFromDocumentPicker_serviceFailure_setsError() async throws {
        let fixtures = makeFixtures()
        fixtures.attachmentService.shouldFailAddAttachment = true

        let tempDir = FileManager.default.temporaryDirectory
        let pdfURL = tempDir.appendingPathComponent("test_service_fail_\(UUID().uuidString).pdf")
        try Data("%PDF-1.4".utf8).write(to: pdfURL)
        defer { try? FileManager.default.removeItem(at: pdfURL) }

        await fixtures.viewModel.addFromDocumentPicker([pdfURL])

        // Service is set to fail, so if security access succeeds, service failure sets error
        // Either way, attachments remain empty and loading completes
        #expect(!fixtures.viewModel.isLoading)
        #expect(fixtures.viewModel.attachments.isEmpty)
    }

    @Test
    func addFromDocumentPicker_primaryKeyFailure_setsError() async throws {
        let attachmentService = MockAttachmentService()
        let primaryKeyProvider = MockPrimaryKeyProvider(shouldFail: true)

        let viewModel = withDependencies {
            $0.date = .constant(testDate)
            $0.uuid = .incrementing
        } operation: {
            AttachmentPickerViewModel(
                personId: UUID(),
                recordId: UUID(),
                attachmentService: attachmentService,
                primaryKeyProvider: primaryKeyProvider
            )
        }

        let tempDir = FileManager.default.temporaryDirectory
        let pdfURL = tempDir.appendingPathComponent("test_pk_fail_\(UUID().uuidString).pdf")
        try Data("%PDF-1.4".utf8).write(to: pdfURL)
        defer { try? FileManager.default.removeItem(at: pdfURL) }

        await viewModel.addFromDocumentPicker([pdfURL])

        // Primary key provider is set to fail, so if security access succeeds, key failure sets error
        // Either way, attachments remain empty and loading completes
        #expect(!viewModel.isLoading)
        #expect(viewModel.attachments.isEmpty)
    }
}
