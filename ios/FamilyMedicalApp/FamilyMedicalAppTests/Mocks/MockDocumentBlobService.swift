import CryptoKit
import Foundation
@testable import FamilyMedicalApp

/// Test mock for DocumentBlobServiceProtocol.
///
/// Records all calls and returns deterministic results. Use `storeResult`, `retrieveResult`,
/// `storeError`, etc. to control outputs per-test. If no explicit `storeResult` is set the
/// mock synthesizes a StoredBlob using SHA256 of the plaintext as the HMAC.
final class MockDocumentBlobService: DocumentBlobServiceProtocol, @unchecked Sendable {
    struct StoreCall {
        let plaintext: Data
        let personId: UUID
    }

    /// Records each call to `deleteIfUnreferenced`. Named struct (not a tuple) to
    /// satisfy SwiftLint `large_tuple` and to give assertions readable field names.
    struct DeleteIfUnreferencedCall: Equatable {
        let contentHMAC: Data
        let personId: UUID
        let isReferencedElsewhere: Bool
    }

    /// Shared shape for the cleanup-path lookups (blobSize / deleteDirect).
    struct BlobLookup: Equatable {
        let contentHMAC: Data
        let personId: UUID
    }

    // MARK: - Call Tracking

    var storeCalls: [StoreCall] = []
    var retrieveCalls: [Data] = []
    var deleteCalls: [DeleteIfUnreferencedCall] = []
    var deleteDirectCalls: [BlobLookup] = []
    var listBlobsCalls: [UUID] = []
    var blobSizeCalls: [BlobLookup] = []
    var markInFlightCalls: [Data] = []
    var clearInFlightCalls: [Data] = []
    var isInFlightCalls: [Data] = []

    // MARK: - Result / Error Stubs

    var storeResult: DocumentBlobService.StoredBlob?
    var storeError: Error?
    var retrieveResult: Data?
    var retrieveError: Error?
    var deleteError: Error?
    var deleteDirectError: Error?

    /// HMACs for which deleteDirect should throw. Overrides deleteDirectError
    /// when set. Used to simulate partial failures in cleanup tests (Task 4).
    var deleteDirectFailForHMACs: Set<Data> = []

    // MARK: - In-Flight State for Tests

    var inFlightHMACs: Set<Data> = []

    // MARK: - Cleanup Test State

    /// Blobs on disk per person, consulted by `listBlobs`.
    var blobsOnDisk: [UUID: Set<Data>] = [:]

    /// Blob sizes returned by `blobSize`. Unknown HMACs fall back to 1024.
    var blobSizes: [Data: UInt64] = [:]

    /// MIME the mock reports as `detectedMimeType` in the synthesized StoredBlob when
    /// no explicit `storeResult` is set. Defaults to `image/jpeg` so existing fixtures
    /// that just check "was store called" still get a plausible result.
    var detectedMimeStub: String = "image/jpeg"

    // MARK: - DocumentBlobServiceProtocol

    func store(
        plaintext: Data,
        personId: UUID,
        primaryKey _: SymmetricKey
    ) async throws -> DocumentBlobService.StoredBlob {
        storeCalls.append(StoreCall(plaintext: plaintext, personId: personId))
        if let storeError {
            throw storeError
        }
        if let storeResult {
            return storeResult
        }
        let hmac = Data(SHA256.hash(data: plaintext))
        let thumbnail: Data? = detectedMimeStub.lowercased().hasPrefix("image/") ? Data([0xAA, 0xBB]) : nil
        return DocumentBlobService.StoredBlob(
            contentHMAC: hmac,
            encryptedSize: plaintext.count,
            thumbnailData: thumbnail,
            detectedMimeType: detectedMimeStub
        )
    }

    func retrieve(
        contentHMAC: Data,
        personId _: UUID,
        primaryKey _: SymmetricKey
    ) async throws -> Data {
        retrieveCalls.append(contentHMAC)
        if let retrieveError {
            throw retrieveError
        }
        return retrieveResult ?? Data()
    }

    func deleteIfUnreferenced(
        contentHMAC: Data,
        personId: UUID,
        isReferencedElsewhere: Bool
    ) async throws {
        // Record the call regardless of the guard so tests can assert on
        // intended-preserve paths with the same instrumentation as delete paths.
        deleteCalls.append(
            DeleteIfUnreferencedCall(
                contentHMAC: contentHMAC,
                personId: personId,
                isReferencedElsewhere: isReferencedElsewhere
            )
        )
        guard !isReferencedElsewhere else { return }
        if let deleteError {
            throw deleteError
        }
    }

    // MARK: - Cleanup Support

    func listBlobs(personId: UUID) async -> Set<Data> {
        listBlobsCalls.append(personId)
        return blobsOnDisk[personId] ?? []
    }

    func blobSize(contentHMAC: Data, personId: UUID) async -> UInt64 {
        blobSizeCalls.append(BlobLookup(contentHMAC: contentHMAC, personId: personId))
        return blobSizes[contentHMAC] ?? 1_024
    }

    func deleteDirect(contentHMAC: Data, personId: UUID) async throws {
        deleteDirectCalls.append(BlobLookup(contentHMAC: contentHMAC, personId: personId))
        if deleteDirectFailForHMACs.contains(contentHMAC) {
            throw ModelError.documentStorageFailed(reason: "Mock per-hmac failure")
        }
        if let deleteDirectError {
            throw deleteDirectError
        }
        blobsOnDisk[personId]?.remove(contentHMAC)
    }

    // MARK: - In-Flight Tracking

    func markInFlight(contentHMAC: Data) async {
        markInFlightCalls.append(contentHMAC)
        inFlightHMACs.insert(contentHMAC)
    }

    func clearInFlight(contentHMAC: Data) async {
        clearInFlightCalls.append(contentHMAC)
        inFlightHMACs.remove(contentHMAC)
    }

    func isInFlight(contentHMAC: Data) async -> Bool {
        isInFlightCalls.append(contentHMAC)
        return inFlightHMACs.contains(contentHMAC)
    }

    // MARK: - Test Helpers

    /// Reset every recorded call, stubbed result, and mutable state field so a
    /// single mock instance can be shared across tests without leakage.
    func reset() {
        storeCalls.removeAll()
        retrieveCalls.removeAll()
        deleteCalls.removeAll()
        deleteDirectCalls.removeAll()
        listBlobsCalls.removeAll()
        blobSizeCalls.removeAll()
        markInFlightCalls.removeAll()
        clearInFlightCalls.removeAll()
        isInFlightCalls.removeAll()

        storeResult = nil
        storeError = nil
        retrieveResult = nil
        retrieveError = nil
        deleteError = nil
        deleteDirectError = nil
        deleteDirectFailForHMACs.removeAll()

        inFlightHMACs.removeAll()
        blobsOnDisk.removeAll()
        blobSizes.removeAll()
        detectedMimeStub = "image/jpeg"
    }
}
