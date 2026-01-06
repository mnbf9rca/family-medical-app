import CryptoKit
import Foundation
@testable import FamilyMedicalApp

/// Mock implementation of AttachmentService for testing
final class MockAttachmentService: AttachmentServiceProtocol, @unchecked Sendable {
    // MARK: - Call Record Types

    struct AddAttachmentCall {
        let data: Data
        let fileName: String
        let mimeType: String
        let recordId: UUID
        let personId: UUID
    }

    struct GetContentCall {
        let attachment: Attachment
        let personId: UUID
    }

    struct DeleteCall {
        let attachmentId: UUID
        let recordId: UUID
    }

    struct FetchCall {
        let recordId: UUID
        let personId: UUID
    }

    // MARK: - State

    /// Stored attachments by ID
    private var attachments: [UUID: Attachment] = [:]

    /// Record-attachment links (recordId -> [attachmentId])
    private var recordLinks: [UUID: [UUID]] = [:]

    /// Content storage (attachmentId -> Data)
    private var contentStorage: [UUID: Data] = [:]

    // MARK: - Configuration

    var shouldFailAddAttachment = false
    var shouldFailGetContent = false
    var shouldFailDeleteAttachment = false
    var shouldFailFetchAttachments = false

    // MARK: - Call Tracking

    var addAttachmentCalls: [AddAttachmentCall] = []
    var getContentCalls: [GetContentCall] = []
    var deleteAttachmentCalls: [DeleteCall] = []
    var fetchAttachmentsCalls: [FetchCall] = []
    var attachmentCountCalls: [UUID] = []

    // MARK: - AttachmentServiceProtocol

    func addAttachment(_ input: AddAttachmentInput) async throws -> Attachment {
        addAttachmentCalls.append(AddAttachmentCall(
            data: input.data,
            fileName: input.fileName,
            mimeType: input.mimeType,
            recordId: input.recordId,
            personId: input.personId
        ))

        if shouldFailAddAttachment {
            throw ModelError.attachmentStorageFailed(reason: "Mock add failure")
        }

        // Create a mock attachment
        let attachment = try Attachment(
            id: UUID(),
            fileName: input.fileName,
            mimeType: input.mimeType,
            contentHMAC: Data(repeating: UInt8.random(in: 0 ... 255), count: 32),
            encryptedSize: input.data.count,
            thumbnailData: input.mimeType.hasPrefix("image/") ? Data(repeating: 0, count: 100) : nil,
            uploadedAt: Date()
        )

        // Store
        attachments[attachment.id] = attachment
        contentStorage[attachment.id] = input.data

        // Link to record
        var links = recordLinks[input.recordId] ?? []
        links.append(attachment.id)
        recordLinks[input.recordId] = links

        return attachment
    }

    func getContent(
        attachment: Attachment,
        personId: UUID,
        primaryKey _: SymmetricKey
    ) async throws -> Data {
        getContentCalls.append(GetContentCall(attachment: attachment, personId: personId))

        if shouldFailGetContent {
            throw ModelError.attachmentContentCorrupted
        }

        guard let content = contentStorage[attachment.id] else {
            throw ModelError.attachmentNotFound(attachmentId: attachment.id)
        }

        return content
    }

    func deleteAttachment(
        attachmentId: UUID,
        recordId: UUID
    ) async throws {
        deleteAttachmentCalls.append(DeleteCall(attachmentId: attachmentId, recordId: recordId))

        if shouldFailDeleteAttachment {
            throw ModelError.attachmentStorageFailed(reason: "Mock delete failure")
        }

        // Remove link
        if var links = recordLinks[recordId] {
            links.removeAll { $0 == attachmentId }
            recordLinks[recordId] = links
        }

        // Check if orphaned
        let isLinked = recordLinks.values.contains { $0.contains(attachmentId) }
        if !isLinked {
            attachments.removeValue(forKey: attachmentId)
            contentStorage.removeValue(forKey: attachmentId)
        }
    }

    func fetchAttachments(
        recordId: UUID,
        personId: UUID,
        primaryKey _: SymmetricKey
    ) async throws -> [Attachment] {
        fetchAttachmentsCalls.append(FetchCall(recordId: recordId, personId: personId))

        if shouldFailFetchAttachments {
            throw ModelError.attachmentStorageFailed(reason: "Mock fetch failure")
        }

        let ids = recordLinks[recordId] ?? []
        return ids.compactMap { attachments[$0] }
    }

    func attachmentCount(recordId: UUID) async throws -> Int {
        attachmentCountCalls.append(recordId)
        return recordLinks[recordId]?.count ?? 0
    }

    // MARK: - Test Helpers

    func reset() {
        attachments.removeAll()
        recordLinks.removeAll()
        contentStorage.removeAll()
        addAttachmentCalls.removeAll()
        getContentCalls.removeAll()
        deleteAttachmentCalls.removeAll()
        fetchAttachmentsCalls.removeAll()
        attachmentCountCalls.removeAll()
        shouldFailAddAttachment = false
        shouldFailGetContent = false
        shouldFailDeleteAttachment = false
        shouldFailFetchAttachments = false
    }

    /// Add a pre-existing attachment for testing
    func addTestAttachment(_ attachment: Attachment, content: Data, linkedToRecord recordId: UUID) {
        attachments[attachment.id] = attachment
        contentStorage[attachment.id] = content
        var links = recordLinks[recordId] ?? []
        links.append(attachment.id)
        recordLinks[recordId] = links
    }
}
