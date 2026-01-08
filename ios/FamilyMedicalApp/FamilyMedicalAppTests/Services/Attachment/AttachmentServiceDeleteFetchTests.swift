import CryptoKit
import Foundation
import Testing
import UIKit
@testable import FamilyMedicalApp

/// Tests for AttachmentService delete, fetch, and count operations
struct AttachmentServiceDeleteFetchTests {
    // MARK: - Test Fixtures

    struct TestFixtures {
        let service: AttachmentService
        let repository: MockAttachmentRepository
        let fileStorage: MockAttachmentFileStorageService
        let imageProcessor: MockImageProcessingService
        let encryptionService: MockEncryptionService
        let fmkService: MockFamilyMemberKeyService
        let primaryKey: SymmetricKey
        let fmk: SymmetricKey
        let personId: UUID
        let recordId: UUID

        func makeInput(
            data: Data,
            fileName: String,
            mimeType: String,
            recordId: UUID? = nil
        ) -> AddAttachmentInput {
            AddAttachmentInput(
                data: data,
                fileName: fileName,
                mimeType: mimeType,
                recordId: recordId ?? self.recordId,
                personId: personId,
                primaryKey: primaryKey
            )
        }
    }

    func makeFixtures() -> TestFixtures {
        let repository = MockAttachmentRepository()
        let fileStorage = MockAttachmentFileStorageService()
        let imageProcessor = MockImageProcessingService()
        let encryptionService = MockEncryptionService()
        let fmkService = MockFamilyMemberKeyService()

        let primaryKey = SymmetricKey(size: .bits256)
        let fmk = SymmetricKey(size: .bits256)
        let personId = UUID()

        fmkService.storedFMKs[personId.uuidString] = fmk

        let service = AttachmentService(
            attachmentRepository: repository,
            fileStorage: fileStorage,
            imageProcessor: imageProcessor,
            encryptionService: encryptionService,
            fmkService: fmkService
        )

        return TestFixtures(
            service: service,
            repository: repository,
            fileStorage: fileStorage,
            imageProcessor: imageProcessor,
            encryptionService: encryptionService,
            fmkService: fmkService,
            primaryKey: primaryKey,
            fmk: fmk,
            personId: personId,
            recordId: UUID()
        )
    }

    func makeTestJPEGData(seed: Int = 0) -> Data {
        let size = CGSize(width: 10, height: 10)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let colors: [UIColor] = [.blue, .red, .green, .yellow, .orange, .purple]
        let color = colors[seed % colors.count]
        let image = renderer.image { ctx in
            color.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
        // swiftlint:disable:next force_unwrapping
        return image.jpegData(compressionQuality: 0.5)!
    }

    func makeTestPDFData() -> Data {
        var data = Data("%PDF-1.4\n".utf8)
        data.append(Data(repeating: 0, count: 100))
        return data
    }

    // MARK: - Delete Attachment Tests

    @Test
    func deleteAttachment_unlinksFromRecord() async throws {
        let fixtures = makeFixtures()
        let imageData = makeTestJPEGData()

        let attachment = try await fixtures.service.addAttachment(
            fixtures.makeInput(data: imageData, fileName: "test.jpg", mimeType: "image/jpeg")
        )

        try await fixtures.service.deleteAttachment(
            attachmentId: attachment.id,
            recordId: fixtures.recordId
        )

        #expect(fixtures.repository.unlinkFromRecordCalls.count == 1)
        #expect(fixtures.repository.unlinkFromRecordCalls[0].attachmentId == attachment.id)
        #expect(fixtures.repository.unlinkFromRecordCalls[0].recordId == fixtures.recordId)
    }

    @Test
    func deleteAttachment_orphaned_deletesMetadata() async throws {
        let fixtures = makeFixtures()
        let imageData = makeTestJPEGData()

        let attachment = try await fixtures.service.addAttachment(
            fixtures.makeInput(data: imageData, fileName: "test.jpg", mimeType: "image/jpeg")
        )

        try await fixtures.service.deleteAttachment(
            attachmentId: attachment.id,
            recordId: fixtures.recordId
        )

        #expect(fixtures.repository.deleteCalls.count == 1)
        #expect(fixtures.repository.deleteCalls[0] == attachment.id)
    }

    @Test
    func deleteAttachment_sharedContent_keepsMetadata() async throws {
        let fixtures = makeFixtures()
        let imageData = makeTestJPEGData()

        let attachment = try await fixtures.service.addAttachment(
            fixtures.makeInput(data: imageData, fileName: "test.jpg", mimeType: "image/jpeg")
        )

        let secondRecordId = UUID()
        try await fixtures.repository.linkToRecord(
            attachmentId: attachment.id,
            recordId: secondRecordId
        )

        try await fixtures.service.deleteAttachment(
            attachmentId: attachment.id,
            recordId: fixtures.recordId
        )

        #expect(fixtures.repository.unlinkFromRecordCalls.count == 1)
        #expect(fixtures.repository.deleteCalls.isEmpty)
    }

    // MARK: - Fetch Attachments Tests

    @Test
    func fetchAttachments_emptyRecord_returnsEmptyArray() async throws {
        let fixtures = makeFixtures()

        let attachments = try await fixtures.service.fetchAttachments(
            recordId: fixtures.recordId,
            personId: fixtures.personId,
            primaryKey: fixtures.primaryKey
        )

        #expect(attachments.isEmpty)
    }

    @Test
    func fetchAttachments_withAttachments_returnsAll() async throws {
        let fixtures = makeFixtures()

        let imageData = makeTestJPEGData()
        _ = try await fixtures.service.addAttachment(
            fixtures.makeInput(data: imageData, fileName: "first.jpg", mimeType: "image/jpeg")
        )

        let pdfData = makeTestPDFData()
        _ = try await fixtures.service.addAttachment(
            fixtures.makeInput(data: pdfData, fileName: "second.pdf", mimeType: "application/pdf")
        )

        let attachments = try await fixtures.service.fetchAttachments(
            recordId: fixtures.recordId,
            personId: fixtures.personId,
            primaryKey: fixtures.primaryKey
        )

        #expect(attachments.count == 2)
    }

    // MARK: - Attachment Count Tests

    @Test
    func attachmentCount_emptyRecord_returnsZero() async throws {
        let fixtures = makeFixtures()

        let count = try await fixtures.service.attachmentCount(recordId: fixtures.recordId)

        #expect(count == 0)
    }

    @Test
    func attachmentCount_withAttachments_returnsCorrectCount() async throws {
        let fixtures = makeFixtures()

        for index in 0 ..< 3 {
            let imageData = makeTestJPEGData(seed: index)
            _ = try await fixtures.service.addAttachment(
                fixtures.makeInput(data: imageData, fileName: "test\(index).jpg", mimeType: "image/jpeg")
            )
        }

        let count = try await fixtures.service.attachmentCount(recordId: fixtures.recordId)

        #expect(count == 3)
    }

    // MARK: - Delete With Cleanup Tests

    @Test
    func deleteAttachmentWithCleanup_orphaned_deletesFile() async throws {
        let fixtures = makeFixtures()
        let imageData = makeTestJPEGData()

        let attachment = try await fixtures.service.addAttachment(
            fixtures.makeInput(data: imageData, fileName: "test.jpg", mimeType: "image/jpeg")
        )

        try await fixtures.service.deleteAttachmentWithCleanup(
            attachmentId: attachment.id,
            recordId: fixtures.recordId,
            personId: fixtures.personId,
            primaryKey: fixtures.primaryKey
        )

        #expect(fixtures.fileStorage.deleteCalls.count == 1)
        #expect(fixtures.repository.deleteCalls.count == 1)
    }

    @Test
    func deleteAttachmentWithCleanup_shared_keepsFile() async throws {
        let fixtures = makeFixtures()
        let imageData = makeTestJPEGData()

        let attachment = try await fixtures.service.addAttachment(
            fixtures.makeInput(data: imageData, fileName: "test.jpg", mimeType: "image/jpeg")
        )

        let secondRecordId = UUID()
        try await fixtures.repository.linkToRecord(
            attachmentId: attachment.id,
            recordId: secondRecordId
        )

        try await fixtures.service.deleteAttachmentWithCleanup(
            attachmentId: attachment.id,
            recordId: fixtures.recordId,
            personId: fixtures.personId,
            primaryKey: fixtures.primaryKey
        )

        #expect(fixtures.fileStorage.deleteCalls.isEmpty)
        #expect(fixtures.repository.deleteCalls.isEmpty)
    }
}
