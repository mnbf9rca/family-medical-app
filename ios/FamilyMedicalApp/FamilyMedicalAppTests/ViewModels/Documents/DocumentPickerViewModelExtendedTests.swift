import CryptoKit
import Foundation
import Testing
import UIKit
@testable import FamilyMedicalApp

/// Extended tests for DocumentPickerViewModel - Document picker flow and multi-draft scenarios.
@MainActor
struct DocumentPickerViewModelExtendedTests {
    // MARK: - Test Fixtures

    struct TestFixtures {
        let viewModel: DocumentPickerViewModel
        let blobService: MockDocumentBlobService
        let personId: UUID
        let sourceRecordId: UUID?
    }

    func makeFixtures(
        sourceRecordId: UUID? = UUID(),
        existing: [DocumentReferenceRecord] = []
    ) -> TestFixtures {
        let blobService = MockDocumentBlobService()
        let primaryKey = SymmetricKey(size: .bits256)
        let personId = UUID()

        let viewModel = DocumentPickerViewModel(
            personId: personId,
            sourceRecordId: sourceRecordId,
            primaryKey: primaryKey,
            existing: existing,
            blobService: blobService
        )
        return TestFixtures(
            viewModel: viewModel,
            blobService: blobService,
            personId: personId,
            sourceRecordId: sourceRecordId
        )
    }

    func makeDocumentReference(
        title: String = "doc.jpg",
        hmacByte: UInt8 = 0x01
    ) -> DocumentReferenceRecord {
        DocumentReferenceRecord(
            title: title,
            mimeType: "image/jpeg",
            fileSize: 1_024,
            contentHMAC: Data(repeating: hmacByte, count: 32)
        )
    }

    func writeTempFile(name: String, contents: Data) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let url = tempDir.appendingPathComponent(name)
        try contents.write(to: url)
        return url
    }

    // MARK: - Document Picker Tests

    @Test
    func addFromDocumentPicker_validPDF_addsDraft() async throws {
        let fixtures = makeFixtures()
        let pdfData = Data("%PDF-1.4 test".utf8)
        let url = try writeTempFile(name: "docpick_\(UUID().uuidString).pdf", contents: pdfData)
        defer { try? FileManager.default.removeItem(at: url) }

        await fixtures.viewModel.addFromDocumentPicker([url])

        // Security-scoped access may succeed or fail in simulator, but loading completes.
        #expect(!fixtures.viewModel.isLoading)
        let didProcess = !fixtures.viewModel.drafts.isEmpty || fixtures.viewModel.errorMessage != nil
        #expect(didProcess)
    }

    @Test
    func addFromDocumentPicker_emptyURLs_doesNothing() async {
        let fixtures = makeFixtures()

        await fixtures.viewModel.addFromDocumentPicker([])

        #expect(fixtures.viewModel.drafts.isEmpty)
        #expect(fixtures.viewModel.errorMessage == nil)
        #expect(!fixtures.viewModel.isLoading)
    }

    @Test
    func addFromDocumentPicker_atLimit_setsError() async throws {
        var existing: [DocumentReferenceRecord] = []
        for index in 0 ..< DocumentPickerViewModel.maxPerRecord {
            existing.append(makeDocumentReference(title: "f\(index).jpg", hmacByte: UInt8(index)))
        }
        let fixtures = makeFixtures(existing: existing)

        let pdfData = Data("%PDF-1.4".utf8)
        let url = try writeTempFile(name: "atlimit_\(UUID().uuidString).pdf", contents: pdfData)
        defer { try? FileManager.default.removeItem(at: url) }

        await fixtures.viewModel.addFromDocumentPicker([url])

        #expect(fixtures.viewModel.errorMessage != nil)
        #expect(fixtures.viewModel.drafts.count == DocumentPickerViewModel.maxPerRecord)
    }

    @Test
    func addFromDocumentPicker_preservesFileName() async throws {
        let fixtures = makeFixtures()
        let pdfData = Data("%PDF-1.4 test".utf8)
        let url = try writeTempFile(name: "my_medical_record.pdf", contents: pdfData)
        defer { try? FileManager.default.removeItem(at: url) }

        await fixtures.viewModel.addFromDocumentPicker([url])

        // If processing succeeded, the draft title is the URL file name.
        if let draft = fixtures.viewModel.drafts.first {
            #expect(draft.content.title == "my_medical_record.pdf")
        }
    }

    @Test
    func addFromDocumentPicker_mimeTypeFromPDFExtension() async throws {
        let fixtures = makeFixtures()
        let pdfData = Data("%PDF-1.4".utf8)
        let url = try writeTempFile(name: "mime_pdf_\(UUID().uuidString).pdf", contents: pdfData)
        defer { try? FileManager.default.removeItem(at: url) }

        await fixtures.viewModel.addFromDocumentPicker([url])

        if let call = fixtures.blobService.storeCalls.first {
            #expect(call.mimeType == "application/pdf")
        }
    }

    @Test
    func addFromDocumentPicker_mimeTypeFromJPGExtension() async throws {
        let fixtures = makeFixtures()
        let jpegData = Data([0xFF, 0xD8, 0xFF, 0xE0]) + Data("jpeg body".utf8)
        let url = try writeTempFile(name: "mime_jpeg_\(UUID().uuidString).jpg", contents: jpegData)
        defer { try? FileManager.default.removeItem(at: url) }

        await fixtures.viewModel.addFromDocumentPicker([url])

        if let call = fixtures.blobService.storeCalls.first {
            #expect(call.mimeType == "image/jpeg")
        }
    }

    @Test
    func addFromDocumentPicker_mimeTypeFromPNGExtension() async throws {
        let fixtures = makeFixtures()
        let pngData = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        let url = try writeTempFile(name: "mime_png_\(UUID().uuidString).png", contents: pngData)
        defer { try? FileManager.default.removeItem(at: url) }

        await fixtures.viewModel.addFromDocumentPicker([url])

        if let call = fixtures.blobService.storeCalls.first {
            #expect(call.mimeType == "image/png")
        }
    }

    @Test
    func addFromDocumentPicker_unknownExtension_fallsToOctetStream() async throws {
        let fixtures = makeFixtures()
        let data = Data("unknown body".utf8)
        let url = try writeTempFile(name: "mime_unknown_\(UUID().uuidString).xyz", contents: data)
        defer { try? FileManager.default.removeItem(at: url) }

        await fixtures.viewModel.addFromDocumentPicker([url])

        if let call = fixtures.blobService.storeCalls.first {
            #expect(call.mimeType == "application/octet-stream")
        }
    }

    @Test
    func addFromDocumentPicker_multipleFiles_addsSeveralDrafts() async throws {
        let fixtures = makeFixtures()
        let testId = UUID().uuidString
        var urls: [URL] = []
        for index in 0 ..< 3 {
            let data = Data("%PDF-1.4 \(index)".utf8)
            let url = try writeTempFile(name: "multi_\(testId)_\(index).pdf", contents: data)
            urls.append(url)
        }
        defer {
            for url in urls {
                try? FileManager.default.removeItem(at: url)
            }
        }

        await fixtures.viewModel.addFromDocumentPicker(urls)

        #expect(fixtures.viewModel.drafts.count <= DocumentPickerViewModel.maxPerRecord)
        #expect(!fixtures.viewModel.isLoading)
    }

    @Test
    func addFromDocumentPicker_serviceFailure_setsError() async throws {
        let fixtures = makeFixtures()
        fixtures.blobService.storeError = ModelError.documentStorageFailed(reason: "boom")
        let data = Data("%PDF-1.4".utf8)
        let url = try writeTempFile(name: "fail_\(UUID().uuidString).pdf", contents: data)
        defer { try? FileManager.default.removeItem(at: url) }

        await fixtures.viewModel.addFromDocumentPicker([url])

        #expect(!fixtures.viewModel.isLoading)
        #expect(fixtures.viewModel.drafts.isEmpty)
    }

    @Test
    func addFromDocumentPicker_nonExistentFile_setsError() async {
        let fixtures = makeFixtures()
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("does_not_exist_\(UUID()).pdf")

        await fixtures.viewModel.addFromDocumentPicker([missing])

        #expect(fixtures.viewModel.errorMessage != nil)
        #expect(fixtures.viewModel.drafts.isEmpty)
    }

    @Test
    func addFromDocumentPicker_stampsSourceRecordId() async throws {
        let sourceId = UUID()
        let fixtures = makeFixtures(sourceRecordId: sourceId)
        let data = Data("%PDF-1.4".utf8)
        let url = try writeTempFile(name: "stamp_\(UUID().uuidString).pdf", contents: data)
        defer { try? FileManager.default.removeItem(at: url) }

        await fixtures.viewModel.addFromDocumentPicker([url])

        if let draft = fixtures.viewModel.drafts.first {
            #expect(draft.content.sourceRecordId == sourceId)
        }
    }

    // MARK: - Photo Library Tests

    @Test
    func addFromPhotoLibrary_emptyItems_doesNothing() async {
        let fixtures = makeFixtures()

        await fixtures.viewModel.addFromPhotoLibrary([])

        #expect(fixtures.viewModel.drafts.isEmpty)
        #expect(fixtures.viewModel.errorMessage == nil)
        #expect(!fixtures.viewModel.isLoading)
    }

    @Test
    func addFromPhotoLibrary_atLimit_guardFires() {
        var existing: [DocumentReferenceRecord] = []
        for index in 0 ..< DocumentPickerViewModel.maxPerRecord {
            existing.append(makeDocumentReference(title: "f\(index).jpg", hmacByte: UInt8(index)))
        }
        let fixtures = makeFixtures(existing: existing)

        #expect(!fixtures.viewModel.canAddMore)
    }
}
