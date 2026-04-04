import CryptoKit
import Foundation
import Observation

/// ViewModel for the medical record detail screen.
///
/// Decodes the `DecryptedRecord`'s envelope into native field values and, if present,
/// resolves any `providerId` to a human-readable display string via `ProviderRepository`.
@MainActor
@Observable
final class MedicalRecordDetailViewModel {
    // MARK: - State

    let person: Person
    private(set) var decryptedRecord: DecryptedRecord
    private(set) var knownFieldValues: [String: Any] = [:]
    private(set) var unknownFields: [String: Any] = [:]
    private(set) var providerDisplayString: String?

    // MARK: - Dependencies

    private let providerRepository: ProviderRepositoryProtocol
    private let primaryKeyProvider: PrimaryKeyProviderProtocol
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
        fmkService: FamilyMemberKeyServiceProtocol? = nil
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
        decodeContent()
    }

    // MARK: - Actions

    /// Refresh after an edit (call from the edit form's onSaveComplete if the same view stays alive).
    func refresh(with record: DecryptedRecord) {
        decryptedRecord = record
        providerDisplayString = nil
        decodeContent()
        Task { await loadProviderDisplayIfNeeded() }
    }

    /// Resolve the provider reference to a display string. Safe to call even when no
    /// providerId is present (it just no-ops).
    func loadProviderDisplayIfNeeded() async {
        guard let providerId = knownFieldValues["providerId"] as? UUID else {
            providerDisplayString = nil
            return
        }
        do {
            let primaryKey = try primaryKeyProvider.getPrimaryKey()
            let provider = try await providerRepository.fetch(
                byId: providerId,
                personId: person.id,
                primaryKey: primaryKey
            )
            providerDisplayString = provider?.displayString
        } catch {
            logger.logError(error, context: "MedicalRecordDetailViewModel.loadProviderDisplayIfNeeded")
            providerDisplayString = nil
        }
    }

    // MARK: - Private

    private func decodeContent() {
        do {
            let decoded = try decryptedRecord.envelope.decodedFieldValues()
            knownFieldValues = decoded.known
            unknownFields = decoded.unknown
        } catch {
            logger.logError(error, context: "MedicalRecordDetailViewModel.decodeContent")
            knownFieldValues = [:]
            unknownFields = [:]
        }
    }
}
