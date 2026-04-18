import CryptoKit
import Foundation
import Observation

/// ViewModel for displaying a list of medical records of a specific type
@MainActor
@Observable
final class MedicalRecordListViewModel {
    // MARK: - Types

    /// Strategy for handling attachments when deleting a parent record.
    enum DeletionStrategy {
        /// Record has no attachments; delete it directly.
        case noAttachments
        /// Delete the parent record and all its attachment records + orphan blobs.
        case cascadeDelete
        /// Detach attachments (set sourceRecordId to nil) then delete the parent.
        case keepStandalone
    }

    // MARK: - State

    let person: Person
    let recordType: RecordType
    var records: [DecryptedRecord] = []
    var isLoading = false
    var errorMessage: String?

    /// When non-nil, the view should present the cascade-delete dialog for this record.
    var pendingCascadeRecordId: UUID?

    /// Attachments discovered during `deleteRecord` when cascade is needed.
    var pendingCascadeAttachments: [PersistedDocumentReference] = []

    // MARK: - Dependencies

    private let medicalRecordRepository: MedicalRecordRepositoryProtocol
    private let recordContentService: RecordContentServiceProtocol
    private let primaryKeyProvider: PrimaryKeyProviderProtocol
    private let fmkService: FamilyMemberKeyServiceProtocol
    private let documentReferenceQueryService: DocumentReferenceQueryServiceProtocol
    private let blobService: DocumentBlobServiceProtocol
    private let logger = LoggingService.shared.logger(category: .storage)

    // MARK: - Initialization

    init(
        person: Person,
        recordType: RecordType,
        medicalRecordRepository: MedicalRecordRepositoryProtocol? = nil,
        recordContentService: RecordContentServiceProtocol? = nil,
        primaryKeyProvider: PrimaryKeyProviderProtocol? = nil,
        fmkService: FamilyMemberKeyServiceProtocol? = nil,
        documentReferenceQueryService: DocumentReferenceQueryServiceProtocol? = nil,
        blobService: DocumentBlobServiceProtocol? = nil
    ) {
        self.person = person
        self.recordType = recordType
        self.medicalRecordRepository = medicalRecordRepository ?? MedicalRecordRepository(
            coreDataStack: CoreDataStack.shared
        )
        self.recordContentService = recordContentService ?? RecordContentService(
            encryptionService: EncryptionService()
        )
        self.primaryKeyProvider = primaryKeyProvider ?? PrimaryKeyProvider()
        self.fmkService = fmkService ?? FamilyMemberKeyService()
        let resolvedRecordRepo = self.medicalRecordRepository
        let resolvedContentService = self.recordContentService
        let resolvedFmkService = self.fmkService
        self.documentReferenceQueryService = documentReferenceQueryService ?? DocumentReferenceQueryService(
            recordRepository: resolvedRecordRepo,
            recordContentService: resolvedContentService,
            fmkService: resolvedFmkService
        )
        self.blobService = blobService ?? DocumentBlobService.makeDefault()
    }

    // MARK: - Actions

    func loadRecords() async {
        isLoading = true
        errorMessage = nil

        do {
            let primaryKey = try primaryKeyProvider.getPrimaryKey()
            let fmk = try fmkService.retrieveFMK(
                familyMemberID: person.id.uuidString,
                primaryKey: primaryKey
            )

            let allRecords = try await medicalRecordRepository.fetchForPerson(personId: person.id)

            var decryptedRecords: [DecryptedRecord] = []
            for record in allRecords {
                do {
                    let envelope = try recordContentService.decrypt(record.encryptedContent, using: fmk)
                    if envelope.recordType == recordType {
                        decryptedRecords.append(DecryptedRecord(record: record, envelope: envelope))
                    }
                } catch {
                    logger.logError(error, context: "MedicalRecordListViewModel.loadRecords - decrypt")
                }
            }

            records = decryptedRecords.sorted { $0.record.createdAt > $1.record.createdAt }
        } catch {
            errorMessage = "Unable to load records. Please try again."
            logger.logError(error, context: "MedicalRecordListViewModel.loadRecords")
        }

        isLoading = false
    }

    /// Fetch attachments for a record before deletion, so the view can offer a cascade dialog.
    func prepareDelete(recordId: UUID) async -> [PersistedDocumentReference] {
        do {
            let primaryKey = try primaryKeyProvider.getPrimaryKey()
            return try await documentReferenceQueryService.attachmentsFor(
                sourceRecordId: recordId,
                personId: person.id,
                primaryKey: primaryKey
            )
        } catch {
            logger.logError(error, context: "MedicalRecordListViewModel.prepareDelete")
            return []
        }
    }

    func deleteRecord(
        id: UUID,
        strategy: DeletionStrategy = .noAttachments,
        attachments: [PersistedDocumentReference] = []
    ) async {
        isLoading = true
        errorMessage = nil

        do {
            switch strategy {
            case .noAttachments:
                // Always check for attachments before deleting, regardless of UI path.
                let found = await prepareDelete(recordId: id)
                if !found.isEmpty {
                    pendingCascadeRecordId = id
                    pendingCascadeAttachments = found
                    isLoading = false
                    return
                }
                try await medicalRecordRepository.delete(id: id)

            case .cascadeDelete:
                try await medicalRecordRepository.delete(id: id)
                await cascadeDeleteAttachments(attachments)

            case .keepStandalone:
                await detachAttachments(attachments)
                try await medicalRecordRepository.delete(id: id)
            }
            records.removeAll { $0.id == id }
        } catch {
            errorMessage = "Unable to delete record. Please try again."
            logger.logError(error, context: "MedicalRecordListViewModel.deleteRecord")
        }

        isLoading = false
    }

    // MARK: - Private Deletion Helpers

    private func cascadeDeleteAttachments(_ attachments: [PersistedDocumentReference]) async {
        // Fetch all DocumentReferences once up-front so HMAC dedup checks are O(1) per
        // attachment instead of O(N) per attachment (avoids N*M decrypt-and-scan).
        let allDocs: [PersistedDocumentReference]?
        do {
            let primaryKey = try primaryKeyProvider.getPrimaryKey()
            allDocs = try await documentReferenceQueryService.allDocuments(
                personId: person.id,
                primaryKey: primaryKey
            )
        } catch {
            logger.logError(error, context: "MedicalRecordListViewModel.cascadeDeleteAttachments.prefetch")
            allDocs = nil // signal: couldn't verify, skip blob deletion
        }
        let deletingIds = Set(attachments.map(\.recordId))

        for attachment in attachments {
            do {
                try await medicalRecordRepository.delete(id: attachment.recordId)
                if let allDocs {
                    let isReferencedElsewhere = allDocs.contains {
                        $0.recordId != attachment.recordId &&
                            !deletingIds.contains($0.recordId) &&
                            $0.content.contentHMAC == attachment.content.contentHMAC
                    }
                    try await blobService.deleteIfUnreferenced(
                        contentHMAC: attachment.content.contentHMAC,
                        personId: person.id,
                        isReferencedElsewhere: isReferencedElsewhere
                    )
                } else {
                    // Prefetch failed — don't delete blobs, orphan cleanup (#151) will handle them later
                    logger.debug("Skipping blob deletion: unable to verify HMAC references")
                }
            } catch {
                logger.logError(error, context: "MedicalRecordListViewModel.cascadeDeleteAttachments")
            }
        }
    }

    private func detachAttachments(_ attachments: [PersistedDocumentReference]) async {
        do {
            let primaryKey = try primaryKeyProvider.getPrimaryKey()
            let fmk = try fmkService.retrieveFMK(
                familyMemberID: person.id.uuidString,
                primaryKey: primaryKey
            )
            for attachment in attachments {
                do {
                    guard let existing = try await medicalRecordRepository.fetch(
                        id: attachment.recordId
                    ) else {
                        continue
                    }
                    var updatedDoc = attachment.content
                    updatedDoc.sourceRecordId = nil
                    let envelope = try RecordContentEnvelope(updatedDoc)
                    let encrypted = try recordContentService.encrypt(envelope, using: fmk)
                    let updatedRecord = MedicalRecord(
                        id: existing.id,
                        personId: existing.personId,
                        encryptedContent: encrypted,
                        createdAt: existing.createdAt,
                        updatedAt: Date(),
                        version: existing.version + 1,
                        previousVersionId: existing.previousVersionId
                    )
                    try await medicalRecordRepository.save(updatedRecord)
                } catch {
                    logger.logError(error, context: "MedicalRecordListViewModel.detachAttachments")
                }
            }
        } catch {
            logger.logError(error, context: "MedicalRecordListViewModel.detachAttachments.keys")
        }
    }
}
