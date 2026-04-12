import Foundation
@testable import FamilyMedicalApp

/// Mock implementation of DocumentFileStorageService for testing.
/// Storage is keyed by `"{personId}/{hmacHex}"` to mirror the per-person subdirectory layout.
final class MockDocumentFileStorageService: DocumentFileStorageServiceProtocol, @unchecked Sendable {
    // MARK: - Call Record Types

    struct StoreCall: Equatable {
        let encryptedData: Data
        let contentHMAC: Data
        let personId: UUID
    }

    struct BlobLookup: Equatable {
        let contentHMAC: Data
        let personId: UUID
    }

    // MARK: - State

    private var storage: [String: Data] = [:]

    // MARK: - Configuration

    var shouldFailStore = false
    var shouldFailRetrieve = false
    var shouldFailDelete = false
    var shouldFailListBlobs = false

    // MARK: - Call Tracking

    var storeCalls: [StoreCall] = []
    var retrieveCalls: [BlobLookup] = []
    var deleteCalls: [BlobLookup] = []
    var existsCalls: [BlobLookup] = []
    var listBlobsCalls: [UUID] = []
    var blobSizeCalls: [BlobLookup] = []

    // MARK: - DocumentFileStorageServiceProtocol

    func store(encryptedData: Data, contentHMAC: Data, personId: UUID) throws -> URL {
        storeCalls.append(StoreCall(encryptedData: encryptedData, contentHMAC: contentHMAC, personId: personId))
        if shouldFailStore {
            throw ModelError.documentStorageFailed(reason: "Mock store failure")
        }
        let key = storageKey(personId: personId, hmac: contentHMAC)
        storage[key] = encryptedData
        return URL(fileURLWithPath: "/mock/attachments/\(personId.uuidString)/\(hmacHex(contentHMAC)).enc")
    }

    func retrieve(contentHMAC: Data, personId: UUID) throws -> Data {
        retrieveCalls.append(BlobLookup(contentHMAC: contentHMAC, personId: personId))
        if shouldFailRetrieve {
            throw ModelError.documentContentCorrupted
        }
        let key = storageKey(personId: personId, hmac: contentHMAC)
        guard let data = storage[key] else {
            throw ModelError.documentNotFound()
        }
        return data
    }

    func delete(contentHMAC: Data, personId: UUID) throws {
        deleteCalls.append(BlobLookup(contentHMAC: contentHMAC, personId: personId))
        if shouldFailDelete {
            throw ModelError.documentStorageFailed(reason: "Mock delete failure")
        }
        let key = storageKey(personId: personId, hmac: contentHMAC)
        storage.removeValue(forKey: key)
    }

    func exists(contentHMAC: Data, personId: UUID) -> Bool {
        existsCalls.append(BlobLookup(contentHMAC: contentHMAC, personId: personId))
        let key = storageKey(personId: personId, hmac: contentHMAC)
        return storage[key] != nil
    }

    func listBlobs(personId: UUID) throws -> Set<Data> {
        listBlobsCalls.append(personId)
        if shouldFailListBlobs {
            throw ModelError.documentStorageFailed(reason: "Mock listBlobs failure")
        }
        let prefix = personId.uuidString + "/"
        var hmacs = Set<Data>()
        for key in storage.keys where key.hasPrefix(prefix) {
            let hexPart = String(key.dropFirst(prefix.count))
            if let hmac = dataFromHex(hexPart) {
                hmacs.insert(hmac)
            }
        }
        return hmacs
    }

    func blobSize(contentHMAC: Data, personId: UUID) throws -> UInt64 {
        blobSizeCalls.append(BlobLookup(contentHMAC: contentHMAC, personId: personId))
        let key = storageKey(personId: personId, hmac: contentHMAC)
        guard let data = storage[key] else {
            throw ModelError.documentNotFound()
        }
        return UInt64(data.count)
    }

    // MARK: - Test Helpers

    func reset() {
        storage.removeAll()
        storeCalls.removeAll()
        retrieveCalls.removeAll()
        deleteCalls.removeAll()
        existsCalls.removeAll()
        listBlobsCalls.removeAll()
        blobSizeCalls.removeAll()
        shouldFailStore = false
        shouldFailRetrieve = false
        shouldFailDelete = false
        shouldFailListBlobs = false
    }

    /// Pre-populate storage for testing retrieval
    func addTestData(_ data: Data, forHMAC hmac: Data, personId: UUID) {
        let key = storageKey(personId: personId, hmac: hmac)
        storage[key] = data
    }

    // MARK: - Private Helpers

    private func storageKey(personId: UUID, hmac: Data) -> String {
        "\(personId.uuidString)/\(hmacHex(hmac))"
    }

    private func hmacHex(_ hmac: Data) -> String {
        hmac.map { String(format: "%02x", $0) }.joined()
    }

    private func dataFromHex(_ hex: String) -> Data? {
        guard hex.count.isMultiple(of: 2) else { return nil }
        var data = Data(capacity: hex.count / 2)
        var index = hex.startIndex
        while index < hex.endIndex {
            let nextIndex = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index ..< nextIndex], radix: 16) else { return nil }
            data.append(byte)
            index = nextIndex
        }
        return data
    }
}
