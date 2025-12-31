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
                // Update existing record
                MedicalRecord(
                    id: existingRecord.id,
                    personId: person.id,
                    encryptedContent: encryptedData,
                    createdAt: existingRecord.createdAt,
                    updatedAt: Date(),
                    version: existingRecord.version + 1,
                    previousVersionId: existingRecord.id
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

// MARK: - ModelError Extension

extension ModelError {
    /// User-friendly error message for display
    var userFacingMessage: String {
        switch self {
        // Person errors (shouldn't occur in record forms, but handle for completeness)
        case .nameEmpty:
            return "Name cannot be empty."
        case let .nameTooLong(maxLength):
            return "Name must be no more than \(maxLength) character\(maxLength == 1 ? "" : "s")."
        case .labelEmpty:
            return "Label cannot be empty."
        case let .labelTooLong(label, maxLength):
            return "Label '\(label)' must be no more than \(maxLength) character\(maxLength == 1 ? "" : "s")."
        // Record field errors
        case let .fieldRequired(fieldName):
            return "\(fieldName) is required."
        case let .fieldTypeMismatch(fieldName, expected, got):
            return "\(fieldName) has an invalid value. Expected \(expected), got \(got)."
        case let .stringTooShort(fieldName, minLength):
            return "\(fieldName) must be at least \(minLength) character\(minLength == 1 ? "" : "s")."
        case let .stringTooLong(fieldName, maxLength):
            return "\(fieldName) must be no more than \(maxLength) character\(maxLength == 1 ? "" : "s")."
        case let .numberOutOfRange(fieldName, min, max):
            if let min, let max {
                return "\(fieldName) must be between \(min) and \(max)."
            } else if let min {
                return "\(fieldName) must be at least \(min)."
            } else if let max {
                return "\(fieldName) must be at most \(max)."
            } else {
                return "\(fieldName) has an invalid value."
            }
        case let .dateOutOfRange(fieldName, min, max):
            if let min, let max {
                let minStr = min.formatted(date: .abbreviated, time: .omitted)
                let maxStr = max.formatted(date: .abbreviated, time: .omitted)
                return "\(fieldName) must be between \(minStr) and \(maxStr)."
            } else if let min {
                let minStr = min.formatted(date: .abbreviated, time: .omitted)
                return "\(fieldName) must be after \(minStr)."
            } else if let max {
                let maxStr = max.formatted(date: .abbreviated, time: .omitted)
                return "\(fieldName) must be before \(maxStr)."
            } else {
                return "\(fieldName) has an invalid date."
            }
        case let .validationFailed(fieldName, reason):
            return "\(fieldName): \(reason)"
        // Attachment errors (shouldn't occur in record forms yet, but handle for completeness)
        case .fileNameEmpty:
            return "File name cannot be empty."
        case let .fileNameTooLong(maxLength):
            return "File name must be no more than \(maxLength) character\(maxLength == 1 ? "" : "s")."
        case let .mimeTypeTooLong(maxLength):
            return "MIME type must be no more than \(maxLength) character\(maxLength == 1 ? "" : "s")."
        case .invalidFileSize:
            return "File size is invalid."
        // Schema errors
        case let .schemaNotFound(schemaId):
            return "Schema '\(schemaId)' not found."
        case let .invalidSchemaId(id):
            return "Invalid schema ID: \(id)"
        case let .duplicateFieldId(fieldId):
            return "Duplicate field: \(fieldId)"
        case let .fieldNotFound(fieldId):
            return "Field '\(fieldId)' not found."
        }
    }
}
