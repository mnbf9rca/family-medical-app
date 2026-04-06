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
        let mimeType: String
        let personId: UUID
    }

    var storeCalls: [StoreCall] = []
    var retrieveCalls: [Data] = []
    var deleteCalls: [Data] = []

    var storeResult: DocumentBlobService.StoredBlob?
    var storeError: Error?
    var retrieveResult: Data?
    var retrieveError: Error?
    var deleteError: Error?

    func store(
        plaintext: Data,
        mimeType: String,
        personId: UUID,
        primaryKey _: SymmetricKey
    ) async throws -> DocumentBlobService.StoredBlob {
        storeCalls.append(StoreCall(plaintext: plaintext, mimeType: mimeType, personId: personId))
        if let storeError {
            throw storeError
        }
        if let storeResult {
            return storeResult
        }
        let hmac = Data(SHA256.hash(data: plaintext))
        let thumbnail: Data? = mimeType.lowercased().hasPrefix("image/") ? Data([0xAA, 0xBB]) : nil
        return DocumentBlobService.StoredBlob(
            contentHMAC: hmac,
            encryptedSize: plaintext.count,
            thumbnailData: thumbnail
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

    func deleteIfUnreferenced(contentHMAC: Data, isReferencedElsewhere: Bool) async throws {
        guard !isReferencedElsewhere else { return }
        deleteCalls.append(contentHMAC)
        if let deleteError {
            throw deleteError
        }
    }
}
