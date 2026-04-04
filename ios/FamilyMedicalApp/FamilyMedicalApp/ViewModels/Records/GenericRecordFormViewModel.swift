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

    // MARK: - Dependencies (exposed to views)

    let providerRepository: ProviderRepositoryProtocol
    let autocompleteService: AutocompleteServiceProtocol

    // MARK: - Private Dependencies

    private let medicalRecordRepository: MedicalRecordRepositoryProtocol
    private let recordContentService: RecordContentServiceProtocol
    private let primaryKeyProvider: PrimaryKeyProviderProtocol
    private let fmkService: FamilyMemberKeyServiceProtocol
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
        autocompleteService: AutocompleteServiceProtocol? = nil
    ) {
        self.person = person
        self.recordType = recordType
        self.existingRecord = existingRecord
        self.medicalRecordRepository = medicalRecordRepository ?? MedicalRecordRepository(
            coreDataStack: CoreDataStack.shared
        )
        self.recordContentService = recordContentService ?? RecordContentService(
            encryptionService: EncryptionService()
        )
        self.primaryKeyProvider = primaryKeyProvider ?? PrimaryKeyProvider()
        let resolvedFmkService = fmkService ?? FamilyMemberKeyService()
        self.fmkService = resolvedFmkService
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

    /// Typed accessor for UUID fields. Returns nil if unset.
    func uuidValue(for keyPath: String) -> UUID? {
        fieldValues[keyPath] as? UUID
    }

    /// Typed accessor for [ObservationComponent] fields. Returns empty if unset.
    func componentsValue(for keyPath: String) -> [ObservationComponent] {
        (fieldValues[keyPath] as? [ObservationComponent]) ?? []
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
                if let metadata = metadataByKeyPath[key], metadata.keyPath == "tags",
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

    private func buildMedicalRecord(encryptedContent: Data) -> MedicalRecord {
        if let existing = existingRecord?.record {
            return MedicalRecord(
                id: existing.id,
                personId: existing.personId,
                encryptedContent: encryptedContent,
                createdAt: existing.createdAt,
                updatedAt: Date(),
                version: existing.version + 1,
                previousVersionId: existing.id
            )
        }
        return MedicalRecord(personId: person.id, encryptedContent: encryptedContent)
    }
}
