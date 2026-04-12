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

    var storeCalls: [StoreCall] = []
    var retrieveCalls: [Data] = []
    var deleteCalls: [DeleteIfUnreferencedCall] = []

    var storeResult: DocumentBlobService.StoredBlob?
    var storeError: Error?
    var retrieveResult: Data?
    var retrieveError: Error?
    var deleteError: Error?

    /// MIME the mock reports as `detectedMimeType` in the synthesized StoredBlob when
    /// no explicit `storeResult` is set. Defaults to `image/jpeg` so existing fixtures
    /// that just check "was store called" still get a plausible result.
    var detectedMimeStub: String = "image/jpeg"

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
        guard !isReferencedElsewhere else { return }
        deleteCalls.append(
            DeleteIfUnreferencedCall(
                contentHMAC: contentHMAC,
                personId: personId,
                isReferencedElsewhere: isReferencedElsewhere
            )
        )
        if let deleteError {
            throw deleteError
        }
    }
}
