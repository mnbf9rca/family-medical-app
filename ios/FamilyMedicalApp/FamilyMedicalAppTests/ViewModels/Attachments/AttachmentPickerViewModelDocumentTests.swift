import CryptoKit
import Foundation
import Testing
import UIKit
@testable import FamilyMedicalApp

/// Document-picker focused tests, separated from the main test file to keep types under the
/// type_body_length lint limit.
@MainActor
struct AttachmentPickerViewModelDocumentTests {
    // MARK: - Test Fixtures

    struct TestFixtures {
        let viewModel: AttachmentPickerViewModel
        let blobService: MockAttachmentBlobService
        let personId: UUID
    }

    func makeFixtures(
        sourceRecordId: UUID? = UUID(),
        existing: [DocumentReferenceRecord] = []
    ) -> TestFixtures {
        let blobService = MockAttachmentBlobService()
        let primaryKey = SymmetricKey(size: .bits256)
        let personId = UUID()

        let viewModel = AttachmentPickerViewModel(
            personId: personId,
            sourceRecordId: sourceRecordId,
            primaryKey: primaryKey,
            existing: existing,
            blobService: blobService
        )

        return TestFixtures(viewModel: viewModel, blobService: blobService, personId: personId)
    }

    func makeDocumentReference(title: String, hmacByte: UInt8) -> DocumentReferenceRecord {
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

    // MARK: - Basic Document Picker Tests

    @Test
    func addFromDocumentPicker_validURL_addsDraft() async throws {
        let fixtures = makeFixtures()
        let data = Data("%PDF-1.4 test".utf8)
        let url = try writeTempFile(name: "valid_\(UUID().uuidString).pdf", contents: data)
        defer { try? FileManager.default.removeItem(at: url) }

        await fixtures.viewModel.addFromDocumentPicker([url])

        #expect(fixtures.viewModel.drafts.count == 1)
        #expect(fixtures.blobService.storeCalls.count == 1)
    }

    @Test
    func addFromDocumentPicker_atLimit_setsError() async throws {
        var existing: [DocumentReferenceRecord] = []
        for index in 0 ..< AttachmentPickerViewModel.maxPerRecord {
            existing.append(makeDocumentReference(title: "f\(index).jpg", hmacByte: UInt8(index)))
        }
        let fixtures = makeFixtures(existing: existing)

        let data = Data("%PDF-1.4".utf8)
        let url = try writeTempFile(name: "over_\(UUID().uuidString).pdf", contents: data)
        defer { try? FileManager.default.removeItem(at: url) }

        await fixtures.viewModel.addFromDocumentPicker([url])

        #expect(fixtures.viewModel.errorMessage != nil)
        #expect(fixtures.blobService.storeCalls.isEmpty)
    }

    @Test
    func addFromDocumentPicker_serviceFailure_setsError() async throws {
        let fixtures = makeFixtures()
        fixtures.blobService.storeError = ModelError.attachmentStorageFailed(reason: "disk full")
        let data = Data("%PDF-1.4".utf8)
        let url = try writeTempFile(name: "svcfail_\(UUID().uuidString).pdf", contents: data)
        defer { try? FileManager.default.removeItem(at: url) }

        await fixtures.viewModel.addFromDocumentPicker([url])

        #expect(fixtures.viewModel.errorMessage != nil)
        #expect(fixtures.viewModel.drafts.isEmpty)
    }

    @Test
    func addFromDocumentPicker_multipleFiles_addsAll() async throws {
        let fixtures = makeFixtures()
        let testId = UUID().uuidString
        var urls: [URL] = []
        for index in 0 ..< 3 {
            let data = Data("%PDF-1.4 content \(index)".utf8)
            let url = try writeTempFile(name: "multi_\(testId)_\(index).pdf", contents: data)
            urls.append(url)
        }
        defer { for url in urls {
            try? FileManager.default.removeItem(at: url)
        } }

        await fixtures.viewModel.addFromDocumentPicker(urls)

        #expect(fixtures.viewModel.drafts.count == 3)
    }

    // MARK: - Constants Tests

    @Test
    func maxPerRecord_isFive() {
        #expect(AttachmentPickerViewModel.maxPerRecord == 5)
    }

    // MARK: - Nil Source Record Tests

    @Test
    func init_withoutSourceRecordId_canStillAddDrafts() async throws {
        let fixtures = makeFixtures(sourceRecordId: nil)
        let data = Data("%PDF-1.4".utf8)
        let url = try writeTempFile(name: "nil_source_\(UUID().uuidString).pdf", contents: data)
        defer { try? FileManager.default.removeItem(at: url) }

        await fixtures.viewModel.addFromDocumentPicker([url])

        #expect(fixtures.viewModel.drafts.count == 1)
        #expect(fixtures.viewModel.drafts[0].content.sourceRecordId == nil)
    }

    // MARK: - File Name Preservation

    @Test
    func addFromDocumentPicker_preservesOriginalFileName() async throws {
        let fixtures = makeFixtures()
        let data = Data("%PDF-1.4 test".utf8)
        let url = try writeTempFile(name: "unique_file_name.pdf", contents: data)
        defer { try? FileManager.default.removeItem(at: url) }

        await fixtures.viewModel.addFromDocumentPicker([url])

        #expect(fixtures.viewModel.drafts.first?.content.title == "unique_file_name.pdf")
    }

    // MARK: - Limit Partial Fill Test

    @Test
    func addFromDocumentPicker_stopsAtLimit() async throws {
        var existing: [DocumentReferenceRecord] = []
        for index in 0 ..< (AttachmentPickerViewModel.maxPerRecord - 1) {
            existing.append(makeDocumentReference(title: "f\(index).jpg", hmacByte: UInt8(index)))
        }
        let fixtures = makeFixtures(existing: existing)

        let testId = UUID().uuidString
        var urls: [URL] = []
        for index in 0 ..< 3 {
            let data = Data("%PDF-1.4 \(index)".utf8)
            let url = try writeTempFile(name: "partial_\(testId)_\(index).pdf", contents: data)
            urls.append(url)
        }
        defer { for url in urls {
            try? FileManager.default.removeItem(at: url)
        } }

        await fixtures.viewModel.addFromDocumentPicker(urls)

        #expect(fixtures.viewModel.drafts.count == AttachmentPickerViewModel.maxPerRecord)
        #expect(fixtures.viewModel.errorMessage != nil)
    }
}
