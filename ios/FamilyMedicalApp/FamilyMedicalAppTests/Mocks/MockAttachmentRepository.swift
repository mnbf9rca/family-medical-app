import CryptoKit
import Foundation
@testable import FamilyMedicalApp

/// Mock implementation of AttachmentRepository for testing
final class MockAttachmentRepository: AttachmentRepositoryProtocol, @unchecked Sendable {
    // MARK: - State

    /// Stored attachments by ID
    private var attachments: [UUID: Attachment] = [:]

    /// Record-attachment links (recordId -> [attachmentId])
    private var recordLinks: [UUID: [UUID]] = [:]

    /// Content HMAC to attachment ID mapping (for deduplication)
    private var hmacIndex: [Data: UUID] = [:]

    // MARK: - Configuration

    var shouldFailSave = false
    var shouldFailFetch = false
    var shouldFailDelete = false
    var shouldFailFetchForRecord = false

    // MARK: - Call Tracking

    var saveCalls: [(attachment: Attachment, personId: UUID)] = []
    var fetchCalls: [(id: UUID, personId: UUID)] = []
    var findByContentHMACCalls: [Data] = []
    var linkToRecordCalls: [(attachmentId: UUID, recordId: UUID)] = []
    var deleteCalls: [UUID] = []
    var existsCalls: [UUID] = []
    var fetchForRecordCalls: [(recordId: UUID, personId: UUID)] = []
    var unlinkFromRecordCalls: [(attachmentId: UUID, recordId: UUID)] = []
    var linkCountCalls: [UUID] = []
    var attachmentCountForRecordCalls: [UUID] = []

    // MARK: - AttachmentRepositoryProtocol

    func save(_ attachment: Attachment, personId: UUID, primaryKey _: SymmetricKey) async throws {
        saveCalls.append((attachment, personId))

        if shouldFailSave {
            throw RepositoryError.saveFailed("Mock save failure")
        }

        attachments[attachment.id] = attachment
        hmacIndex[attachment.contentHMAC] = attachment.id
    }

    func fetch(id: UUID, personId: UUID, primaryKey _: SymmetricKey) async throws -> Attachment? {
        fetchCalls.append((id, personId))

        if shouldFailFetch {
            throw RepositoryError.fetchFailed("Mock fetch failure")
        }

        return attachments[id]
    }

    func findByContentHMAC(_ hmac: Data) async throws -> UUID? {
        findByContentHMACCalls.append(hmac)
        return hmacIndex[hmac]
    }

    func linkToRecord(attachmentId: UUID, recordId: UUID) async throws {
        linkToRecordCalls.append((attachmentId, recordId))

        var links = recordLinks[recordId] ?? []
        if !links.contains(attachmentId) {
            links.append(attachmentId)
            recordLinks[recordId] = links
        }
    }

    func delete(id: UUID) async throws {
        deleteCalls.append(id)

        if shouldFailDelete {
            throw RepositoryError.deleteFailed("Mock delete failure")
        }

        guard let attachment = attachments[id] else {
            throw RepositoryError.entityNotFound("Attachment with ID \(id)")
        }

        // Remove from HMAC index
        hmacIndex.removeValue(forKey: attachment.contentHMAC)

        // Remove from attachments
        attachments.removeValue(forKey: id)

        // Remove from all record links
        for (recordId, var links) in recordLinks {
            links.removeAll { $0 == id }
            recordLinks[recordId] = links
        }
    }

    func exists(id: UUID) async throws -> Bool {
        existsCalls.append(id)
        return attachments[id] != nil
    }

    func fetchForRecord(recordId: UUID, personId: UUID, primaryKey _: SymmetricKey) async throws -> [Attachment] {
        fetchForRecordCalls.append((recordId, personId))

        if shouldFailFetchForRecord {
            throw RepositoryError.fetchFailed("Mock fetch for record failure")
        }

        let ids = recordLinks[recordId] ?? []
        return ids.compactMap { attachments[$0] }
    }

    func unlinkFromRecord(attachmentId: UUID, recordId: UUID) async throws {
        unlinkFromRecordCalls.append((attachmentId, recordId))

        if var links = recordLinks[recordId] {
            links.removeAll { $0 == attachmentId }
            recordLinks[recordId] = links
        }
    }

    func linkCount(attachmentId: UUID) async throws -> Int {
        linkCountCalls.append(attachmentId)

        var count = 0
        for links in recordLinks.values where links.contains(attachmentId) {
            count += 1
        }
        return count
    }

    func attachmentCountForRecord(recordId: UUID) async throws -> Int {
        attachmentCountForRecordCalls.append(recordId)
        return recordLinks[recordId]?.count ?? 0
    }

    // MARK: - Test Helpers

    func reset() {
        attachments.removeAll()
        recordLinks.removeAll()
        hmacIndex.removeAll()
        saveCalls.removeAll()
        fetchCalls.removeAll()
        findByContentHMACCalls.removeAll()
        linkToRecordCalls.removeAll()
        deleteCalls.removeAll()
        existsCalls.removeAll()
        fetchForRecordCalls.removeAll()
        unlinkFromRecordCalls.removeAll()
        linkCountCalls.removeAll()
        attachmentCountForRecordCalls.removeAll()
        shouldFailSave = false
        shouldFailFetch = false
        shouldFailDelete = false
        shouldFailFetchForRecord = false
    }

    /// Add a pre-existing attachment for testing
    func addTestAttachment(_ attachment: Attachment, linkedToRecord recordId: UUID? = nil) {
        attachments[attachment.id] = attachment
        hmacIndex[attachment.contentHMAC] = attachment.id

        if let recordId {
            var links = recordLinks[recordId] ?? []
            links.append(attachment.id)
            recordLinks[recordId] = links
        }
    }

    /// Get stored attachment for verification
    func getStoredAttachment(_ id: UUID) -> Attachment? {
        attachments[id]
    }
}
