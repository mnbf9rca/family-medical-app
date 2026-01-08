import Foundation
import Testing
@testable import FamilyMedicalApp

/// Tests for AttachmentService delete, fetch, and count operations
struct AttachmentServiceDeleteFetchTests {
    // MARK: - Delete Attachment Tests

    @Test
    func deleteAttachment_unlinksFromRecord() async throws {
        let fixtures = AttachmentServiceTestFixtures.make()
        let imageData = AttachmentServiceTestFixtures.makeTestJPEGData()

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
        let fixtures = AttachmentServiceTestFixtures.make()
        let imageData = AttachmentServiceTestFixtures.makeTestJPEGData()

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
        let fixtures = AttachmentServiceTestFixtures.make()
        let imageData = AttachmentServiceTestFixtures.makeTestJPEGData()

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
        let fixtures = AttachmentServiceTestFixtures.make()

        let attachments = try await fixtures.service.fetchAttachments(
            recordId: fixtures.recordId,
            personId: fixtures.personId,
            primaryKey: fixtures.primaryKey
        )

        #expect(attachments.isEmpty)
    }

    @Test
    func fetchAttachments_withAttachments_returnsAll() async throws {
        let fixtures = AttachmentServiceTestFixtures.make()

        let imageData = AttachmentServiceTestFixtures.makeTestJPEGData()
        _ = try await fixtures.service.addAttachment(
            fixtures.makeInput(data: imageData, fileName: "first.jpg", mimeType: "image/jpeg")
        )

        let pdfData = AttachmentServiceTestFixtures.makeTestPDFData()
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
        let fixtures = AttachmentServiceTestFixtures.make()

        let count = try await fixtures.service.attachmentCount(recordId: fixtures.recordId)

        #expect(count == 0)
    }

    @Test
    func attachmentCount_withAttachments_returnsCorrectCount() async throws {
        let fixtures = AttachmentServiceTestFixtures.make()

        for index in 0 ..< 3 {
            let imageData = AttachmentServiceTestFixtures.makeTestJPEGData(seed: index)
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
        let fixtures = AttachmentServiceTestFixtures.make()
        let imageData = AttachmentServiceTestFixtures.makeTestJPEGData()

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
        let fixtures = AttachmentServiceTestFixtures.make()
        let imageData = AttachmentServiceTestFixtures.makeTestJPEGData()

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
