import CryptoKit
import Foundation
import Observation

/// ViewModel for the medical record detail screen.
///
/// Decodes the `DecryptedRecord`'s envelope into native field values and, if present,
/// resolves provider reference fields to human-readable display strings via `ProviderRepository`.
@MainActor
@Observable
final class MedicalRecordDetailViewModel {
    // MARK: - State

    let person: Person
    let decryptedRecord: DecryptedRecord
    private(set) var knownFieldValues: [String: Any] = [:]
    private(set) var unknownFields: [String: Any] = [:]
    private(set) var providerDisplayStrings: [String: String] = [:]
    /// Non-nil when the record's encrypted content could not be decoded. Shown to the user
    /// instead of the normal field list so they are not left staring at a blank screen.
    private(set) var decodeErrorMessage: String?

    /// Attached DocumentReferenceRecords for this record.
    var attachments: [PersistedDocumentReference] = []
    /// Whether attachments are currently being loaded.
    var isLoadingAttachments = false

    // MARK: - Dependencies

    private let providerRepository: ProviderRepositoryProtocol
    private let primaryKeyProvider: PrimaryKeyProviderProtocol
    private let documentReferenceQueryService: DocumentReferenceQueryServiceProtocol
    private let logger = LoggingService.shared.logger(category: .storage)

    // MARK: - Derived

    var recordType: RecordType {
        decryptedRecord.recordType
    }

    var orderedFieldMetadata: [FieldMetadata] {
        recordType.fieldMetadata.sorted { $0.displayOrder < $1.displayOrder }
    }

    // MARK: - Initialization

    init(
        person: Person,
        decryptedRecord: DecryptedRecord,
        providerRepository: ProviderRepositoryProtocol? = nil,
        primaryKeyProvider: PrimaryKeyProviderProtocol? = nil,
        fmkService: FamilyMemberKeyServiceProtocol? = nil,
        documentReferenceQueryService: DocumentReferenceQueryServiceProtocol? = nil
    ) {
        self.person = person
        self.decryptedRecord = decryptedRecord
        let resolvedFmkService = fmkService ?? FamilyMemberKeyService()
        self.providerRepository = providerRepository ?? ProviderRepository(
            coreDataStack: CoreDataStack.shared,
            encryptionService: EncryptionService(),
            fmkService: resolvedFmkService
        )
        self.primaryKeyProvider = primaryKeyProvider ?? PrimaryKeyProvider()
        self.documentReferenceQueryService = documentReferenceQueryService ?? DocumentReferenceQueryService(
            recordRepository: MedicalRecordRepository(coreDataStack: CoreDataStack.shared),
            recordContentService: RecordContentService(encryptionService: EncryptionService()),
            fmkService: resolvedFmkService
        )
        decodeContent()
    }

    // MARK: - Actions

    /// Resolve all provider reference fields to display strings. Safe to call even when no
    /// provider references are present (it just no-ops).
    func loadProviderDisplayIfNeeded() async {
        let providerFields = recordType.fieldMetadata.filter(\.isProviderReference)
        guard !providerFields.isEmpty else { return }

        var resolved: [String: String] = [:]
        do {
            let primaryKey = try primaryKeyProvider.getPrimaryKey()
            for field in providerFields {
                guard let providerId = knownFieldValues[field.keyPath] as? UUID else { continue }
                if let provider = try await providerRepository.fetch(
                    byId: providerId,
                    personId: person.id,
                    primaryKey: primaryKey
                ) {
                    resolved[field.keyPath] = provider.displayString
                }
            }
        } catch {
            logger.logError(error, context: "MedicalRecordDetailViewModel.loadProviderDisplayIfNeeded")
        }
        providerDisplayStrings = resolved
    }

    /// Load DocumentReferenceRecords attached to this record.
    /// No-op for `.documentReference` records (they are documents themselves).
    func loadAttachments() async {
        guard recordType != .documentReference else { return }

        isLoadingAttachments = true
        do {
            let primaryKey = try primaryKeyProvider.getPrimaryKey()
            attachments = try await documentReferenceQueryService.attachmentsFor(
                sourceRecordId: decryptedRecord.record.id,
                personId: person.id,
                primaryKey: primaryKey
            )
        } catch {
            logger.logError(error, context: "MedicalRecordDetailViewModel.loadAttachments")
            attachments = []
        }
        isLoadingAttachments = false
    }

    /// Creates a viewer ViewModel for the given attachment, using this VM's existing
    /// primaryKeyProvider. Returns nil if the primary key cannot be retrieved.
    func makeViewerViewModel(for attachment: PersistedDocumentReference) -> DocumentViewerViewModel? {
        guard let primaryKey = try? primaryKeyProvider.getPrimaryKey() else { return nil }
        return DocumentViewerViewModel(
            document: attachment.content,
            personId: person.id,
            primaryKey: primaryKey
        )
    }

    // MARK: - Private

    private func decodeContent() {
        do {
            let decoded = try decryptedRecord.envelope.decodedFieldValues()
            knownFieldValues = decoded.known
            unknownFields = decoded.unknown
            decodeErrorMessage = nil
        } catch {
            logger.logError(error, context: "MedicalRecordDetailViewModel.decodeContent")
            knownFieldValues = [:]
            unknownFields = [:]
            decodeErrorMessage = "Unable to read this record. It may be corrupted or saved in an unsupported format."
        }
    }
}
