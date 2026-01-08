import Foundation
import Testing
@testable import FamilyMedicalApp

/// Tests for AttachmentService add attachment operations
struct AttachmentServiceTests {
    // MARK: - Add Attachment Tests

    @Test
    func addAttachment_validJPEG_createsAttachment() async throws {
        let fixtures = AttachmentServiceTestFixtures.make()
        let imageData = AttachmentServiceTestFixtures.makeTestJPEGData()

        let attachment = try await fixtures.service.addAttachment(
            fixtures.makeInput(data: imageData, fileName: "test.jpg", mimeType: "image/jpeg")
        )

        #expect(attachment.fileName == "test.jpg")
        #expect(attachment.mimeType == "image/jpeg")
        #expect(!attachment.contentHMAC.isEmpty)
    }

    @Test
    func addAttachment_validJPEG_processesImage() async throws {
        let fixtures = AttachmentServiceTestFixtures.make()
        let imageData = AttachmentServiceTestFixtures.makeTestJPEGData()

        _ = try await fixtures.service.addAttachment(
            fixtures.makeInput(data: imageData, fileName: "test.jpg", mimeType: "image/jpeg")
        )

        #expect(fixtures.imageProcessor.compressCalls.count == 1)
        #expect(fixtures.imageProcessor.thumbnailCalls.count == 1)
    }

    @Test
    func addAttachment_validPDF_skipsImageProcessing() async throws {
        let fixtures = AttachmentServiceTestFixtures.make()
        let pdfData = AttachmentServiceTestFixtures.makeTestPDFData()

        _ = try await fixtures.service.addAttachment(
            fixtures.makeInput(data: pdfData, fileName: "test.pdf", mimeType: "application/pdf")
        )

        #expect(fixtures.imageProcessor.compressCalls.isEmpty)
        #expect(fixtures.imageProcessor.thumbnailCalls.isEmpty)
    }

    @Test
    func addAttachment_validPDF_hasNoThumbnail() async throws {
        let fixtures = AttachmentServiceTestFixtures.make()
        let pdfData = AttachmentServiceTestFixtures.makeTestPDFData()

        let attachment = try await fixtures.service.addAttachment(
            fixtures.makeInput(data: pdfData, fileName: "test.pdf", mimeType: "application/pdf")
        )

        #expect(attachment.thumbnailData == nil)
    }

    @Test
    func addAttachment_encryptsAndStoresContent() async throws {
        let fixtures = AttachmentServiceTestFixtures.make()
        let imageData = AttachmentServiceTestFixtures.makeTestJPEGData()

        _ = try await fixtures.service.addAttachment(
            fixtures.makeInput(data: imageData, fileName: "test.jpg", mimeType: "image/jpeg")
        )

        #expect(fixtures.encryptionService.encryptCalls.count == 1)
        #expect(fixtures.fileStorage.storeCalls.count == 1)
    }

    @Test
    func addAttachment_savesMetadataAndLinksToRecord() async throws {
        let fixtures = AttachmentServiceTestFixtures.make()
        let imageData = AttachmentServiceTestFixtures.makeTestJPEGData()

        _ = try await fixtures.service.addAttachment(
            fixtures.makeInput(data: imageData, fileName: "test.jpg", mimeType: "image/jpeg")
        )

        #expect(fixtures.repository.saveCalls.count == 1)
        #expect(fixtures.repository.linkToRecordCalls.count == 1)
        #expect(fixtures.repository.linkToRecordCalls[0].recordId == fixtures.recordId)
    }

    @Test
    func addAttachment_unsupportedMimeType_throwsError() async throws {
        let fixtures = AttachmentServiceTestFixtures.make()
        let data = Data("test".utf8)

        await #expect(throws: ModelError.self) {
            try await fixtures.service.addAttachment(
                fixtures.makeInput(data: data, fileName: "test.txt", mimeType: "text/plain")
            )
        }
    }

    @Test
    func addAttachment_pdfTooLarge_throwsError() async throws {
        let fixtures = AttachmentServiceTestFixtures.make()
        let largeData = Data(repeating: 0x25, count: 11 * 1_024 * 1_024)

        await #expect(throws: ModelError.self) {
            try await fixtures.service.addAttachment(
                fixtures.makeInput(data: largeData, fileName: "large.pdf", mimeType: "application/pdf")
            )
        }
    }

    @Test
    func addAttachment_exceedsLimit_throwsError() async throws {
        let fixtures = AttachmentServiceTestFixtures.make()
        let imageData = AttachmentServiceTestFixtures.makeTestJPEGData()

        for index in 0 ..< AttachmentService.maxAttachmentsPerRecord {
            let attachment = try Attachment(
                id: UUID(),
                fileName: "existing\(index).jpg",
                mimeType: "image/jpeg",
                contentHMAC: Data(repeating: UInt8(index), count: 32),
                encryptedSize: 1_024,
                thumbnailData: nil,
                uploadedAt: Date()
            )
            fixtures.repository.addTestAttachment(attachment, linkedToRecord: fixtures.recordId)
        }

        await #expect(throws: ModelError.self) {
            try await fixtures.service.addAttachment(
                fixtures.makeInput(data: imageData, fileName: "test.jpg", mimeType: "image/jpeg")
            )
        }
    }
}
