import Foundation
@testable import FamilyMedicalApp

/// Mock implementation of AttachmentFileStorageService for testing
final class MockAttachmentFileStorageService: AttachmentFileStorageServiceProtocol, @unchecked Sendable {
    // MARK: - State

    /// In-memory storage keyed by HMAC hex string
    private var storage: [String: Data] = [:]

    // MARK: - Configuration

    var shouldFailStore = false
    var shouldFailRetrieve = false
    var shouldFailDelete = false

    // MARK: - Call Tracking

    var storeCalls: [(encryptedData: Data, contentHMAC: Data)] = []
    var retrieveCalls: [Data] = []
    var deleteCalls: [Data] = []
    var existsCalls: [Data] = []

    // MARK: - AttachmentFileStorageServiceProtocol

    func store(encryptedData: Data, contentHMAC: Data) throws -> URL {
        storeCalls.append((encryptedData, contentHMAC))

        if shouldFailStore {
            throw ModelError.attachmentStorageFailed(reason: "Mock store failure")
        }

        let key = hmacKey(contentHMAC)
        storage[key] = encryptedData
        return URL(fileURLWithPath: "/mock/attachments/\(key).enc")
    }

    func retrieve(contentHMAC: Data) throws -> Data {
        retrieveCalls.append(contentHMAC)

        if shouldFailRetrieve {
            throw ModelError.attachmentContentCorrupted
        }

        let key = hmacKey(contentHMAC)
        guard let data = storage[key] else {
            throw ModelError.attachmentNotFound(attachmentId: UUID())
        }

        return data
    }

    func delete(contentHMAC: Data) throws {
        deleteCalls.append(contentHMAC)

        if shouldFailDelete {
            throw ModelError.attachmentStorageFailed(reason: "Mock delete failure")
        }

        let key = hmacKey(contentHMAC)
        storage.removeValue(forKey: key)
    }

    func exists(contentHMAC: Data) -> Bool {
        existsCalls.append(contentHMAC)
        let key = hmacKey(contentHMAC)
        return storage[key] != nil
    }

    // MARK: - Test Helpers

    func reset() {
        storage.removeAll()
        storeCalls.removeAll()
        retrieveCalls.removeAll()
        deleteCalls.removeAll()
        existsCalls.removeAll()
        shouldFailStore = false
        shouldFailRetrieve = false
        shouldFailDelete = false
    }

    /// Pre-populate storage for testing retrieval
    func addTestData(_ data: Data, forHMAC hmac: Data) {
        let key = hmacKey(hmac)
        storage[key] = data
    }

    private func hmacKey(_ hmac: Data) -> String {
        hmac.map { String(format: "%02x", $0) }.joined()
    }
}
