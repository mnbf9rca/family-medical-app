import CryptoKit
import Foundation
import Observation

/// ViewModel for the protocol-driven generic record form.
///
/// Holds field values in a `[String: Any]` dictionary keyed by `FieldMetadata.keyPath`.
/// On save, the dictionary is normalized to JSON-safe values and decoded into the concrete
/// typed record (via `JSONSerialization` → `JSONDecoder`), then wrapped in a
/// `RecordContentEnvelope`, encrypted with the Family Member Key, and persisted.
///
/// Supports two modes:
/// - Create: `existingRecord` is nil; `fieldValues` starts empty.
/// - Edit: `existingRecord` is provided; `fieldValues` is hydrated by decoding the envelope
///   and mapping each known field by keyPath. Unknown fields are preserved in
///   `unknownFieldsSnapshot` and re-emitted on save for forward compatibility.
@MainActor
@Observable
final class GenericRecordFormViewModel {
    // MARK: - Public State

    let person: Person
    let recordType: RecordType
    let existingRecord: DecryptedRecord?

    var fieldValues: [String: Any] = [:]
    var isSaving = false
    var errorMessage: String?
    /// keyPath → localized validation error (e.g., "Required").
    var validationErrors: [String: String] = [:]
    var providers: [Provider] = []
    /// Set if the existing record's `schemaVersion` exceeds the version this build knows.
    var forwardCompatibilityWarning: String?

    /// Attachment picker for adding DocumentReferenceRecords to this record.
    /// Nil for `.documentReference` record type (they ARE documents, not containers).
    var documentPickerViewModel: DocumentPickerViewModel?

    // MARK: - Dependencies (exposed to views)

    let providerRepository: ProviderRepositoryProtocol
    let autocompleteService: AutocompleteServiceProtocol

    // MARK: - Private Dependencies

    private let medicalRecordRepository: MedicalRecordRepositoryProtocol
    private let recordContentService: RecordContentServiceProtocol
    private let primaryKeyProvider: PrimaryKeyProviderProtocol
    private let fmkService: FamilyMemberKeyServiceProtocol
    private let blobService: DocumentBlobServiceProtocol?
    private let documentReferenceQueryService: DocumentReferenceQueryServiceProtocol
    private let logger = LoggingService.shared.logger(category: .storage)

    /// Snapshot of unknown fields from the existing record (preserved on save).
    private var unknownFieldsSnapshot: [String: Any] = [:]

    // MARK: - Derived State

    var isEditing: Bool {
        existingRecord != nil
    }

    var fieldMetadata: [FieldMetadata] {
        recordType.fieldMetadata.sorted { $0.displayOrder < $1.displayOrder }
    }

    var displayName: String {
        recordType.displayName
    }

    // MARK: - Initialization

    init(
        person: Person,
        recordType: RecordType,
        existingRecord: DecryptedRecord? = nil,
        medicalRecordRepository: MedicalRecordRepositoryProtocol? = nil,
        recordContentService: RecordContentServiceProtocol? = nil,
        primaryKeyProvider: PrimaryKeyProviderProtocol? = nil,
        fmkService: FamilyMemberKeyServiceProtocol? = nil,
        providerRepository: ProviderRepositoryProtocol? = nil,
        autocompleteService: AutocompleteServiceProtocol? = nil,
        blobService: DocumentBlobServiceProtocol? = nil,
        documentReferenceQueryService: DocumentReferenceQueryServiceProtocol? = nil
    ) {
        self.person = person
        self.recordType = recordType
        self.existingRecord = existingRecord
        let resolvedRecordRepo = medicalRecordRepository ?? MedicalRecordRepository(
            coreDataStack: CoreDataStack.shared
        )
        self.medicalRecordRepository = resolvedRecordRepo
        let resolvedContentService = recordContentService ?? RecordContentService(
            encryptionService: EncryptionService()
        )
        self.recordContentService = resolvedContentService
        self.primaryKeyProvider = primaryKeyProvider ?? PrimaryKeyProvider()
        let resolvedFmkService = fmkService ?? FamilyMemberKeyService()
        self.fmkService = resolvedFmkService
        self.blobService = blobService
        self.documentReferenceQueryService = documentReferenceQueryService ?? DocumentReferenceQueryService(
            recordRepository: resolvedRecordRepo,
            recordContentService: resolvedContentService,
            fmkService: resolvedFmkService
        )
        self.providerRepository = providerRepository ?? ProviderRepository(
            coreDataStack: CoreDataStack.shared,
            encryptionService: EncryptionService(),
            fmkService: resolvedFmkService
        )
        self.autocompleteService = autocompleteService ?? AutocompleteService()

        if let existingRecord {
            hydrateFromExisting(existingRecord)
        }
    }

    // MARK: - Field Value Access

    func value(for keyPath: String) -> Any? {
        fieldValues[keyPath]
    }

    func setValue(_ value: Any?, for keyPath: String) {
        if let value {
            fieldValues[keyPath] = value
        } else {
            fieldValues.removeValue(forKey: keyPath)
        }
        // Clear validation error when user edits the field
        validationErrors.removeValue(forKey: keyPath)
    }

    /// Typed accessor for string-like fields. Returns "" if unset.
    func stringValue(for keyPath: String) -> String {
        (fieldValues[keyPath] as? String) ?? ""
    }

    /// Typed accessor for Date fields. Returns caller-supplied default if unset.
    func dateValue(for keyPath: String, default defaultValue: Date) -> Date {
        (fieldValues[keyPath] as? Date) ?? defaultValue
    }

    /// Typed accessor for Int fields. Returns nil if unset or not convertible.
    func intValue(for keyPath: String) -> Int? {
        fieldValues[keyPath] as? Int
    }

    /// Typed accessor for Bool fields. Returns nil if unset.
    func boolValue(for keyPath: String) -> Bool? {
        fieldValues[keyPath] as? Bool
    }

    /// Typed accessor for UUID fields. Returns nil if unset.
    func uuidValue(for keyPath: String) -> UUID? {
        fieldValues[keyPath] as? UUID
    }

    /// Typed accessor for [ObservationComponent] fields. Returns empty if unset.
    func componentsValue(for keyPath: String) -> [ObservationComponent] {
        (fieldValues[keyPath] as? [ObservationComponent]) ?? []
    }

    // MARK: - Attachment Picker

    /// Creates the attachment picker ViewModel if the record type supports attachments.
    /// No-op for `.documentReference` (those are documents themselves, not containers).
    /// In edit mode, fetches existing attachments so they count toward `maxPerRecord`.
    func createDocumentPickerIfNeeded() async {
        guard recordType != .documentReference else { return }
        guard documentPickerViewModel == nil else { return }
        do {
            let primaryKey = try primaryKeyProvider.getPrimaryKey()
            var existingDocs: [DocumentReferenceRecord] = []
            if let existingRecord {
                let persisted = try await documentReferenceQueryService.attachmentsFor(
                    sourceRecordId: existingRecord.record.id,
                    personId: person.id,
                    primaryKey: primaryKey
                )
                existingDocs = persisted.map(\.content)
            }
            documentPickerViewModel = DocumentPickerViewModel(
                personId: person.id,
                sourceRecordId: existingRecord?.record.id,
                primaryKey: primaryKey,
                existing: existingDocs,
                blobService: blobService
            )
        } catch {
            logger.logError(error, context: "GenericRecordFormViewModel.createDocumentPickerIfNeeded")
        }
    }

    // MARK: - Providers

    /// Load this person's providers for the autocomplete dropdown.
    func loadProviders() async {
        do {
            let primaryKey = try primaryKeyProvider.getPrimaryKey()
            providers = try await providerRepository.fetchAll(forPerson: person.id, primaryKey: primaryKey)
        } catch {
            logger.logError(error, context: "GenericRecordFormViewModel.loadProviders")
            providers = []
        }
    }

    /// Save a new provider inline and add it to the loaded providers list.
    /// Returns `true` on success, `false` on failure (error is logged internally).
    func addProvider(_ provider: Provider) async -> Bool {
        do {
            let primaryKey = try primaryKeyProvider.getPrimaryKey()
            try await providerRepository.save(provider, personId: person.id, primaryKey: primaryKey)
            providers.append(provider)
            return true
        } catch {
            logger.logError(error, context: "GenericRecordFormViewModel.addProvider")
            return false
        }
    }

    // MARK: - Save

    /// Save the record. Returns true if the save succeeded.
    @discardableResult
    func save() async -> Bool {
        errorMessage = nil

        // Guard against schemaVersion downgrade: if the existing record was saved by a
        // newer app version, saving here would re-envelope it with our older schemaVersion
        // and silently discard any type-changes the newer version introduced. Refuse the
        // save rather than corrupt data; the forwardCompatibilityWarning already tells the
        // user what's happening.
        if let existing = existingRecord,
           existing.envelope.schemaVersion > recordType.currentSchemaVersion {
            errorMessage = "This record was saved by a newer version of the app and cannot be edited here."
            return false
        }

        guard validate() else { return false }

        isSaving = true
        defer { isSaving = false }

        do {
            let primaryKey = try primaryKeyProvider.getPrimaryKey()
            let fmk = try fmkService.retrieveFMK(
                familyMemberID: person.id.uuidString,
                primaryKey: primaryKey
            )

            let jsonData = try buildJSONData()
            let envelope = try buildEnvelope(jsonData: jsonData)
            let encryptedContent = try recordContentService.encrypt(envelope, using: fmk)

            let record = buildMedicalRecord(encryptedContent: encryptedContent)
            try await medicalRecordRepository.save(record)

            // Persist pending attachment drafts as separate DocumentReferenceRecords
            await saveAttachmentDrafts(parentRecordId: record.id, fmk: fmk)

            return true
        } catch {
            errorMessage = "Unable to save. Please try again."
            logger.logError(error, context: "GenericRecordFormViewModel.save")
            return false
        }
    }

    // MARK: - Validation

    private func validate() -> Bool {
        validationErrors.removeAll()
        for metadata in fieldMetadata where metadata.isRequired {
            if isValueMissing(for: metadata) {
                validationErrors[metadata.keyPath] = "Required"
            }
        }
        return validationErrors.isEmpty
    }

    private func isValueMissing(for metadata: FieldMetadata) -> Bool {
        guard let raw = fieldValues[metadata.keyPath] else { return true }
        if let string = raw as? String { return string.isEmpty }
        if let array = raw as? [Any] { return array.isEmpty }
        return false
    }

    // MARK: - Hydration (edit mode)

    private func hydrateFromExisting(_ decrypted: DecryptedRecord) {
        // Forward-compat warning if the stored schema is newer than what we know.
        if decrypted.envelope.schemaVersion > recordType.currentSchemaVersion {
            forwardCompatibilityWarning = "This record was saved with a newer app version."
                + " Unknown fields will be preserved but cannot be edited here."
        }

        do {
            let decoded = try decrypted.envelope.decodedFieldValues()
            // For editing we need tag lists to show as a comma-separated string.
            let metadataByKeyPath = Dictionary(uniqueKeysWithValues: fieldMetadata.map { ($0.keyPath, $0) })
            for (key, value) in decoded.known {
                if let metadata = metadataByKeyPath[key], metadata.isTagList,
                   let tags = value as? [String] {
                    fieldValues[key] = tags.joined(separator: ", ")
                } else {
                    fieldValues[key] = value
                }
            }
            unknownFieldsSnapshot = decoded.unknown
        } catch {
            logger.logError(error, context: "GenericRecordFormViewModel.hydrateFromExisting")
        }
    }

    // MARK: - JSON Build

    private func buildJSONData() throws -> Data {
        var normalized: [String: Any] = [:]
        let metadataByKeyPath = Dictionary(uniqueKeysWithValues: fieldMetadata.map { ($0.keyPath, $0) })

        for (key, value) in fieldValues {
            guard let metadata = metadataByKeyPath[key] else { continue }
            if let jsonValue = FieldValueNormalizer.normalize(value, for: metadata) {
                normalized[key] = jsonValue
            }
        }
        // Ensure `tags` is always present as array if the metadata expects it and user did not set it.
        if metadataByKeyPath["tags"] != nil, normalized["tags"] == nil {
            normalized["tags"] = []
        }
        // Merge preserved unknown fields (edit mode forward compat).
        for (key, value) in unknownFieldsSnapshot {
            normalized[key] = value
        }
        return try JSONSerialization.data(withJSONObject: normalized, options: [.sortedKeys])
    }

    private func buildEnvelope(jsonData: Data) throws -> RecordContentEnvelope {
        try RecordContentEnvelope.wrap(jsonData: jsonData, as: recordType)
    }

    private func saveAttachmentDrafts(parentRecordId: UUID, fmk: SymmetricKey) async {
        guard let pickerVM = documentPickerViewModel else { return }
        let drafts = pickerVM.allDocumentReferences
        guard !drafts.isEmpty else { return }

        for var docRef in drafts {
            docRef.sourceRecordId = parentRecordId
            do {
                let attachEnvelope = try RecordContentEnvelope(docRef)
                let encrypted = try recordContentService.encrypt(attachEnvelope, using: fmk)
                let attachRecord = MedicalRecord(personId: person.id, encryptedContent: encrypted)
                try await medicalRecordRepository.save(attachRecord)
            } catch {
                errorMessage = "Record saved, but some attachments could not be saved."
                logger.logError(error, context: "GenericRecordFormViewModel.saveAttachmentDrafts")
            }
        }
    }

    private func buildMedicalRecord(encryptedContent: Data) -> MedicalRecord {
        if let existing = existingRecord?.record {
            // MedicalRecord uses in-place-update semantics: MedicalRecordRepository.save
            // upserts by id (one row per record, no history rows). Setting
            // previousVersionId to existing.id here would make the row self-referential,
            // which is meaningless. Leave it nil until a row-per-version history
            // infrastructure exists to traverse.
            return MedicalRecord(
                id: existing.id,
                personId: existing.personId,
                encryptedContent: encryptedContent,
                createdAt: existing.createdAt,
                updatedAt: Date(),
                version: existing.version + 1,
                previousVersionId: nil
            )
        }
        return MedicalRecord(personId: person.id, encryptedContent: encryptedContent)
    }
}
