import CryptoKit
import Foundation
import Observation

/// ViewModel for adding or editing a medical record
@MainActor
@Observable
final class MedicalRecordFormViewModel {
    // MARK: - State

    let person: Person
    let schema: RecordSchema
    let existingRecord: MedicalRecord? // nil for create, non-nil for edit

    /// Form field values keyed by field ID
    var fieldValues: [String: FieldValue] = [:]

    var isLoading = false
    var errorMessage: String?
    var didSaveSuccessfully = false

    // MARK: - Dependencies

    private let medicalRecordRepository: MedicalRecordRepositoryProtocol
    private let recordContentService: RecordContentServiceProtocol
    private let primaryKeyProvider: PrimaryKeyProviderProtocol
    private let fmkService: FamilyMemberKeyServiceProtocol
    private let logger = LoggingService.shared.logger(category: .storage)

    // MARK: - Computed Properties

    var isEditing: Bool {
        existingRecord != nil
    }

    var title: String {
        isEditing ? "Edit \(schema.displayName)" : "Add \(schema.displayName)"
    }

    // MARK: - Initialization

    /// Initialize form for adding or editing a record
    ///
    /// - Parameters:
    ///   - person: The person this record belongs to
    ///   - schema: The record schema (defines fields and validation)
    ///   - existingRecord: Optional existing record for editing
    ///   - existingContent: Optional existing content for editing
    ///   - medicalRecordRepository: Repository (defaults to production)
    ///   - recordContentService: Service (defaults to production)
    ///   - primaryKeyProvider: Provider (defaults to production)
    ///   - fmkService: Service (defaults to production)
    init(
        person: Person,
        schema: RecordSchema,
        existingRecord: MedicalRecord? = nil,
        existingContent: RecordContent? = nil,
        medicalRecordRepository: MedicalRecordRepositoryProtocol? = nil,
        recordContentService: RecordContentServiceProtocol? = nil,
        primaryKeyProvider: PrimaryKeyProviderProtocol? = nil,
        fmkService: FamilyMemberKeyServiceProtocol? = nil
    ) {
        self.person = person
        self.schema = schema
        self.existingRecord = existingRecord

        // Initialize field values from existing content if editing,
        // or pre-populate date fields with today's date for new records
        if let content = existingContent {
            self.fieldValues = content.allFields
        } else {
            // For new records, initialize date fields with today's date
            // This ensures DatePicker's visual default matches the actual value
            var initialValues: [String: FieldValue] = [:]
            for field in schema.fields where field.fieldType == .date {
                initialValues[field.id] = .date(Date())
            }
            self.fieldValues = initialValues
        }

        // Use optional parameter pattern per ADR-0008
        self.medicalRecordRepository = medicalRecordRepository ?? MedicalRecordRepository(
            coreDataStack: CoreDataStack.shared
        )
        self.recordContentService = recordContentService ?? RecordContentService(
            encryptionService: EncryptionService()
        )
        self.primaryKeyProvider = primaryKeyProvider ?? PrimaryKeyProvider()
        self.fmkService = fmkService ?? FamilyMemberKeyService()
    }

    // MARK: - Validation

    /// Validate all fields and return true if valid
    ///
    /// Sets `errorMessage` if validation fails.
    func validate() -> Bool {
        let content = RecordContent(schemaId: schema.id, fields: fieldValues)

        do {
            try schema.validate(content: content)
            errorMessage = nil
            return true
        } catch let error as ModelError {
            errorMessage = error.userFacingMessage
            logger.logError(error, context: "MedicalRecordFormViewModel.validate")
            return false
        } catch {
            errorMessage = "Unable to validate form. Please check your input."
            logger.logError(error, context: "MedicalRecordFormViewModel.validate")
            return false
        }
    }

    // MARK: - Save

    /// Save the record (create or update)
    func save() async {
        guard validate() else {
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            // Get encryption keys
            let primaryKey = try primaryKeyProvider.getPrimaryKey()
            let fmk = try fmkService.retrieveFMK(
                familyMemberID: person.id.uuidString,
                primaryKey: primaryKey
            )

            // Create content and encrypt
            let content = RecordContent(schemaId: schema.id, fields: fieldValues)
            let encryptedData = try recordContentService.encrypt(content, using: fmk)

            // Create or update record
            let record = if let existingRecord {
                // In-place update: same ID, no version chain (future feature)
                // When true versioning is added, this will create a new ID
                // and set previousVersionId to the old record's ID
                MedicalRecord(
                    id: existingRecord.id,
                    personId: person.id,
                    encryptedContent: encryptedData,
                    createdAt: existingRecord.createdAt,
                    updatedAt: Date(),
                    version: existingRecord.version + 1,
                    previousVersionId: nil
                )
            } else {
                // Create new record
                MedicalRecord(
                    personId: person.id,
                    encryptedContent: encryptedData
                )
            }

            // Save to repository
            try await medicalRecordRepository.save(record)
            didSaveSuccessfully = true
        } catch {
            errorMessage = "Unable to save record. Please try again."
            logger.logError(error, context: "MedicalRecordFormViewModel.save")
        }

        isLoading = false
    }
}
