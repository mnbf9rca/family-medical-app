import Foundation
import Testing
import UIKit
@testable import FamilyMedicalApp

/// Tests for AttachmentService content retrieval, deduplication, and MIME type validation
struct AttachmentServiceContentTests {
    // MARK: - Deduplication Tests

    @Test
    func addAttachment_duplicateContent_reusesExisting() async throws {
        let fixtures = AttachmentServiceTestFixtures.make()
        let imageData = AttachmentServiceTestFixtures.makeTestJPEGData()

        let first = try await fixtures.service.addAttachment(
            fixtures.makeInput(data: imageData, fileName: "first.jpg", mimeType: "image/jpeg")
        )

        let secondRecordId = UUID()
        let second = try await fixtures.service.addAttachment(
            fixtures.makeInput(
                data: imageData,
                fileName: "second.jpg",
                mimeType: "image/jpeg",
                recordId: secondRecordId
            )
        )

        #expect(first.id == second.id)
        #expect(first.contentHMAC == second.contentHMAC)
        #expect(fixtures.repository.linkToRecordCalls.count == 2)
    }

    // MARK: - Get Content Tests

    @Test
    func getContent_validAttachment_returnsDecryptedData() async throws {
        let fixtures = AttachmentServiceTestFixtures.make()
        let originalData = AttachmentServiceTestFixtures.makeTestJPEGData()

        let attachment = try await fixtures.service.addAttachment(
            fixtures.makeInput(data: originalData, fileName: "test.jpg", mimeType: "image/jpeg")
        )

        let content = try await fixtures.service.getContent(
            attachment: attachment,
            personId: fixtures.personId,
            primaryKey: fixtures.primaryKey
        )

        #expect(!content.isEmpty)
    }

    @Test
    func getContent_nonExistentContent_throwsError() async throws {
        let fixtures = AttachmentServiceTestFixtures.make()
        fixtures.fileStorage.shouldFailRetrieve = true

        let attachment = try Attachment(
            id: UUID(),
            fileName: "missing.jpg",
            mimeType: "image/jpeg",
            contentHMAC: Data(repeating: 0, count: 32),
            encryptedSize: 1_024,
            thumbnailData: nil,
            uploadedAt: Date()
        )

        await #expect(throws: ModelError.self) {
            try await fixtures.service.getContent(
                attachment: attachment,
                personId: fixtures.personId,
                primaryKey: fixtures.primaryKey
            )
        }
    }

    // MARK: - MIME Type Validation Tests

    @Test
    func addAttachment_jpegUppercase_accepted() async throws {
        let fixtures = AttachmentServiceTestFixtures.make()
        let imageData = AttachmentServiceTestFixtures.makeTestJPEGData()

        let attachment = try await fixtures.service.addAttachment(
            fixtures.makeInput(data: imageData, fileName: "test.jpg", mimeType: "IMAGE/JPEG")
        )

        #expect(attachment.mimeType == "IMAGE/JPEG")
    }

    @Test
    func addAttachment_pngSupported() async throws {
        let fixtures = AttachmentServiceTestFixtures.make()

        let size = CGSize(width: 10, height: 10)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            UIColor.green.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
        let pngData = try #require(image.pngData())

        let attachment = try await fixtures.service.addAttachment(
            fixtures.makeInput(data: pngData, fileName: "test.png", mimeType: "image/png")
        )

        #expect(attachment.mimeType == "image/png")
    }
}
