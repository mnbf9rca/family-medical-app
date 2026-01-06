import CryptoKit
import Foundation
import Testing
import UIKit
@testable import FamilyMedicalApp

/// Tests for AttachmentService add attachment operations
struct AttachmentServiceTests {
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

    // MARK: - Add Attachment Tests

    @Test
    func addAttachment_validJPEG_createsAttachment() async throws {
        let fixtures = makeFixtures()
        let imageData = makeTestJPEGData()

        let attachment = try await fixtures.service.addAttachment(
            fixtures.makeInput(data: imageData, fileName: "test.jpg", mimeType: "image/jpeg")
        )

        #expect(attachment.fileName == "test.jpg")
        #expect(attachment.mimeType == "image/jpeg")
        #expect(!attachment.contentHMAC.isEmpty)
    }

    @Test
    func addAttachment_validJPEG_processesImage() async throws {
        let fixtures = makeFixtures()
        let imageData = makeTestJPEGData()

        _ = try await fixtures.service.addAttachment(
            fixtures.makeInput(data: imageData, fileName: "test.jpg", mimeType: "image/jpeg")
        )

        #expect(fixtures.imageProcessor.compressCalls.count == 1)
        #expect(fixtures.imageProcessor.thumbnailCalls.count == 1)
    }

    @Test
    func addAttachment_validPDF_skipsImageProcessing() async throws {
        let fixtures = makeFixtures()
        let pdfData = makeTestPDFData()

        _ = try await fixtures.service.addAttachment(
            fixtures.makeInput(data: pdfData, fileName: "test.pdf", mimeType: "application/pdf")
        )

        #expect(fixtures.imageProcessor.compressCalls.isEmpty)
        #expect(fixtures.imageProcessor.thumbnailCalls.isEmpty)
    }

    @Test
    func addAttachment_validPDF_hasNoThumbnail() async throws {
        let fixtures = makeFixtures()
        let pdfData = makeTestPDFData()

        let attachment = try await fixtures.service.addAttachment(
            fixtures.makeInput(data: pdfData, fileName: "test.pdf", mimeType: "application/pdf")
        )

        #expect(attachment.thumbnailData == nil)
    }

    @Test
    func addAttachment_encryptsAndStoresContent() async throws {
        let fixtures = makeFixtures()
        let imageData = makeTestJPEGData()

        _ = try await fixtures.service.addAttachment(
            fixtures.makeInput(data: imageData, fileName: "test.jpg", mimeType: "image/jpeg")
        )

        #expect(fixtures.encryptionService.encryptCalls.count == 1)
        #expect(fixtures.fileStorage.storeCalls.count == 1)
    }

    @Test
    func addAttachment_savesMetadataAndLinksToRecord() async throws {
        let fixtures = makeFixtures()
        let imageData = makeTestJPEGData()

        _ = try await fixtures.service.addAttachment(
            fixtures.makeInput(data: imageData, fileName: "test.jpg", mimeType: "image/jpeg")
        )

        #expect(fixtures.repository.saveCalls.count == 1)
        #expect(fixtures.repository.linkToRecordCalls.count == 1)
        #expect(fixtures.repository.linkToRecordCalls[0].recordId == fixtures.recordId)
    }

    @Test
    func addAttachment_unsupportedMimeType_throwsError() async throws {
        let fixtures = makeFixtures()
        let data = Data("test".utf8)

        await #expect(throws: ModelError.self) {
            try await fixtures.service.addAttachment(
                fixtures.makeInput(data: data, fileName: "test.txt", mimeType: "text/plain")
            )
        }
    }

    @Test
    func addAttachment_pdfTooLarge_throwsError() async throws {
        let fixtures = makeFixtures()
        let largeData = Data(repeating: 0x25, count: 11 * 1_024 * 1_024)

        await #expect(throws: ModelError.self) {
            try await fixtures.service.addAttachment(
                fixtures.makeInput(data: largeData, fileName: "large.pdf", mimeType: "application/pdf")
            )
        }
    }

    @Test
    func addAttachment_exceedsLimit_throwsError() async throws {
        let fixtures = makeFixtures()
        let imageData = makeTestJPEGData()

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
