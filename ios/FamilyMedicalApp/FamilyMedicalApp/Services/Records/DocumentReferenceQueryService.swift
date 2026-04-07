import CryptoKit
import Foundation

/// A decoded DocumentReferenceRecord paired with its enclosing MedicalRecord metadata.
struct PersistedDocumentReference: Identifiable {
    let recordId: UUID
    let content: DocumentReferenceRecord
    let createdAt: Date
    let updatedAt: Date

    var id: UUID {
        recordId
    }
}

/// Queries for DocumentReferenceRecords by their sourceRecordId or shared contentHMAC.
///
/// All queries scan every MedicalRecord for the given person, decrypt each envelope, and
/// filter in memory. This keeps record metadata (including which records are attached to
/// which parents) out of plaintext Core Data columns per ADR-0004.
protocol DocumentReferenceQueryServiceProtocol: Sendable {
    /// Returns all DocumentReferenceRecords whose `sourceRecordId` matches `sourceRecordId`.
    func attachmentsFor(
        sourceRecordId: UUID,
        personId: UUID,
        primaryKey: SymmetricKey
    ) async throws -> [PersistedDocumentReference]

    /// Returns every DocumentReferenceRecord for the person (both attached and standalone).
    func allDocuments(
        personId: UUID,
        primaryKey: SymmetricKey
    ) async throws -> [PersistedDocumentReference]

    /// Returns true if any other DocumentReferenceRecord references the same blob HMAC.
    /// Used before deleting a blob to honor HMAC deduplication from ADR-0004.
    func isHmacReferencedElsewhere(
        contentHMAC: Data,
        excludingRecordId: UUID,
        personId: UUID,
        primaryKey: SymmetricKey
    ) async throws -> Bool
}

final class DocumentReferenceQueryService: DocumentReferenceQueryServiceProtocol, @unchecked Sendable {
    private let recordRepository: MedicalRecordRepositoryProtocol
    private let recordContentService: RecordContentServiceProtocol
    private let fmkService: FamilyMemberKeyServiceProtocol
    private let logger: TracingCategoryLogger

    init(
        recordRepository: MedicalRecordRepositoryProtocol,
        recordContentService: RecordContentServiceProtocol,
        fmkService: FamilyMemberKeyServiceProtocol,
        logger: CategoryLoggerProtocol? = nil
    ) {
        self.recordRepository = recordRepository
        self.recordContentService = recordContentService
        self.fmkService = fmkService
        self.logger = TracingCategoryLogger(
            wrapping: logger ?? LoggingService.shared.logger(category: .storage)
        )
    }

    // MARK: - DocumentReferenceQueryServiceProtocol

    func attachmentsFor(
        sourceRecordId: UUID,
        personId: UUID,
        primaryKey: SymmetricKey
    ) async throws -> [PersistedDocumentReference] {
        let all = try await fetchAllDocumentReferences(personId: personId, primaryKey: primaryKey)
        return all.filter { $0.content.sourceRecordId == sourceRecordId }
    }

    func allDocuments(
        personId: UUID,
        primaryKey: SymmetricKey
    ) async throws -> [PersistedDocumentReference] {
        try await fetchAllDocumentReferences(personId: personId, primaryKey: primaryKey)
    }

    func isHmacReferencedElsewhere(
        contentHMAC: Data,
        excludingRecordId: UUID,
        personId: UUID,
        primaryKey: SymmetricKey
    ) async throws -> Bool {
        let all = try await fetchAllDocumentReferences(personId: personId, primaryKey: primaryKey)
        return all.contains { $0.recordId != excludingRecordId && $0.content.contentHMAC == contentHMAC }
    }

    // MARK: - Private

    private func fetchAllDocumentReferences(
        personId: UUID,
        primaryKey: SymmetricKey
    ) async throws -> [PersistedDocumentReference] {
        let start = ContinuousClock.now
        logger.entry("fetchAllDocumentReferences")
        do {
            let fmk = try fmkService.retrieveFMK(familyMemberID: personId.uuidString, primaryKey: primaryKey)
            let records = try await recordRepository.fetchForPerson(personId: personId)
            var results: [PersistedDocumentReference] = []
            for record in records {
                guard let envelope = try? recordContentService.decrypt(record.encryptedContent, using: fmk),
                      envelope.recordType == .documentReference,
                      let doc = try? envelope.decode(DocumentReferenceRecord.self)
                else {
                    continue
                }
                results.append(
                    PersistedDocumentReference(
                        recordId: record.id,
                        content: doc,
                        createdAt: record.createdAt,
                        updatedAt: record.updatedAt
                    )
                )
            }
            logger.exit("fetchAllDocumentReferences", duration: ContinuousClock.now - start)
            return results
        } catch {
            logger.exitWithError("fetchAllDocumentReferences", error: error, duration: ContinuousClock.now - start)
            throw error
        }
    }
}
