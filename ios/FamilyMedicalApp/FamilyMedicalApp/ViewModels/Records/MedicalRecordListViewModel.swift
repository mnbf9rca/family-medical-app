import CryptoKit
import Foundation
import Observation

/// ViewModel for displaying a list of medical records of a specific schema type
@MainActor
@Observable
final class MedicalRecordListViewModel {
    // MARK: - State

    let person: Person
    let schemaType: BuiltInSchemaType
    var records: [DecryptedRecord] = []
    var isLoading = false
    var errorMessage: String?

    // MARK: - Dependencies

    private let medicalRecordRepository: MedicalRecordRepositoryProtocol
    private let recordContentService: RecordContentServiceProtocol
    private let primaryKeyProvider: PrimaryKeyProviderProtocol
    private let fmkService: FamilyMemberKeyServiceProtocol
    private let logger = LoggingService.shared.logger(category: .storage)

    // MARK: - Initialization

    /// Initialize with a person and schema type
    ///
    /// Uses optional parameter pattern per ADR-0008 for testability.
    ///
    /// - Parameters:
    ///   - person: The person whose records to display
    ///   - schemaType: The type of records to show (vaccine, condition, etc.)
    ///   - medicalRecordRepository: Repository for medical records (defaults to production)
    ///   - recordContentService: Service for encrypting/decrypting content (defaults to production)
    ///   - primaryKeyProvider: Provider for user's primary key (defaults to production)
    ///   - fmkService: Service for family member keys (defaults to production)
    init(
        person: Person,
        schemaType: BuiltInSchemaType,
        medicalRecordRepository: MedicalRecordRepositoryProtocol? = nil,
        recordContentService: RecordContentServiceProtocol? = nil,
        primaryKeyProvider: PrimaryKeyProviderProtocol? = nil,
        fmkService: FamilyMemberKeyServiceProtocol? = nil
    ) {
        self.person = person
        self.schemaType = schemaType
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

    // MARK: - Actions

    /// Load medical records for the person and schema type
    func loadRecords() async {
        isLoading = true
        errorMessage = nil

        do {
            // Get the primary key and FMK
            let primaryKey = try primaryKeyProvider.getPrimaryKey()
            let fmk = try fmkService.retrieveFMK(
                familyMemberID: person.id.uuidString,
                primaryKey: primaryKey
            )

            // Fetch all medical records for this person
            let allRecords = try await medicalRecordRepository.fetchForPerson(personId: person.id)

            // Decrypt and filter by schema type
            var decryptedRecords: [DecryptedRecord] = []
            for record in allRecords {
                do {
                    let content = try recordContentService.decrypt(record.encryptedContent, using: fmk)
                    // Only include records that match our schema type
                    if content.schemaId == schemaType.rawValue {
                        decryptedRecords.append(DecryptedRecord(record: record, content: content))
                    }
                } catch {
                    // Log decryption error but continue with other records
                    logger.logError(error, context: "MedicalRecordListViewModel.loadRecords - decrypt")
                }
            }

            // Sort by date field (newest first)
            records = sortRecordsByDate(decryptedRecords)
        } catch {
            errorMessage = "Unable to load records. Please try again."
            logger.logError(error, context: "MedicalRecordListViewModel.loadRecords")
        }

        isLoading = false
    }

    /// Delete a medical record
    ///
    /// - Parameter id: The record ID to delete
    func deleteRecord(id: UUID) async {
        isLoading = true
        errorMessage = nil

        do {
            try await medicalRecordRepository.delete(id: id)
            // Remove from local array
            records.removeAll { $0.id == id }
        } catch {
            errorMessage = "Unable to delete record. Please try again."
            logger.logError(error, context: "MedicalRecordListViewModel.deleteRecord")
        }

        isLoading = false
    }

    // MARK: - Private Helpers

    /// Sort records by the first date field found (newest first)
    private func sortRecordsByDate(_ records: [DecryptedRecord]) -> [DecryptedRecord] {
        let schema = RecordSchema.builtIn(schemaType)

        // Find the first date field in the schema
        guard let dateField = schema.fields.first(where: { $0.fieldType == .date }) else {
            // No date field, return unsorted
            return records
        }

        return records.sorted { lhs, rhs in
            let lhsDate = lhs.content.getDate(dateField.id) ?? Date.distantPast
            let rhsDate = rhs.content.getDate(dateField.id) ?? Date.distantPast
            return lhsDate > rhsDate // Newest first
        }
    }
}
