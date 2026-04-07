import CryptoKit
import Foundation
@testable import FamilyMedicalApp

/// Test mock for DocumentReferenceQueryServiceProtocol.
///
/// Returns pre-configured results and tracks calls for assertion.
final class MockDocumentReferenceQueryService: DocumentReferenceQueryServiceProtocol, @unchecked Sendable {
    // MARK: - Call Tracking

    var attachmentsForCalls: [UUID] = []
    var allDocumentsCalls: [UUID] = []
    var isHmacReferencedCalls: [(contentHMAC: Data, excludingRecordId: UUID)] = []

    // MARK: - Configurable Results

    var attachmentsResult: [PersistedDocumentReference] = []
    var allDocumentsResult: [PersistedDocumentReference] = []
    var isHmacReferencedResult = false

    var attachmentsError: Error?
    var allDocumentsError: Error?
    var isHmacReferencedError: Error?

    // MARK: - DocumentReferenceQueryServiceProtocol

    func attachmentsFor(
        sourceRecordId: UUID,
        personId: UUID,
        primaryKey: SymmetricKey
    ) async throws -> [PersistedDocumentReference] {
        attachmentsForCalls.append(sourceRecordId)
        if let attachmentsError {
            throw attachmentsError
        }
        return attachmentsResult
    }

    func allDocuments(
        personId: UUID,
        primaryKey: SymmetricKey
    ) async throws -> [PersistedDocumentReference] {
        allDocumentsCalls.append(personId)
        if let allDocumentsError {
            throw allDocumentsError
        }
        return allDocumentsResult
    }

    func isHmacReferencedElsewhere(
        contentHMAC: Data,
        excludingRecordId: UUID,
        personId: UUID,
        primaryKey: SymmetricKey
    ) async throws -> Bool {
        isHmacReferencedCalls.append((contentHMAC, excludingRecordId))
        if let isHmacReferencedError {
            throw isHmacReferencedError
        }
        return isHmacReferencedResult
    }
}
