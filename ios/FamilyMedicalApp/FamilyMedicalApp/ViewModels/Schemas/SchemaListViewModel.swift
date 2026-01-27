import CryptoKit
import Dependencies
import Foundation
import Observation

/// ViewModel for the schema list screen showing all schemas for a Person
@MainActor
@Observable
final class SchemaListViewModel {
    // MARK: - State

    let person: Person
    var schemas: [RecordSchema] = []
    var recordCounts: [String: Int] = [:]
    var isLoading = false
    var errorMessage: String?

    // MARK: - Dependencies

    @ObservationIgnored @Dependency(\.uuid) private var uuid
    private let customSchemaRepository: CustomSchemaRepositoryProtocol
    private let medicalRecordRepository: MedicalRecordRepositoryProtocol
    private let recordContentService: RecordContentServiceProtocol
    private let primaryKeyProvider: PrimaryKeyProviderProtocol
    private let fmkService: FamilyMemberKeyServiceProtocol
    private let logger = LoggingService.shared.logger(category: .storage)

    // MARK: - Initialization

    init(
        person: Person,
        customSchemaRepository: CustomSchemaRepositoryProtocol? = nil,
        medicalRecordRepository: MedicalRecordRepositoryProtocol? = nil,
        recordContentService: RecordContentServiceProtocol? = nil,
        primaryKeyProvider: PrimaryKeyProviderProtocol? = nil,
        fmkService: FamilyMemberKeyServiceProtocol? = nil
    ) {
        self.person = person
        // Use optional parameter pattern per ADR-0008
        self.customSchemaRepository = customSchemaRepository ?? CustomSchemaRepository(
            coreDataStack: CoreDataStack.shared,
            encryptionService: EncryptionService()
        )
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

    /// Load all schemas and their record counts for this Person
    func loadSchemas() async {
        isLoading = true
        errorMessage = nil

        do {
            // Get the primary key and FMK
            let primaryKey = try primaryKeyProvider.getPrimaryKey()
            let fmk = try fmkService.retrieveFMK(
                familyMemberID: person.id.uuidString,
                primaryKey: primaryKey
            )

            // Fetch all schemas for this Person
            let fetchedSchemas = try await customSchemaRepository.fetchAll(
                forPerson: person.id,
                familyMemberKey: fmk
            )

            // Sort: built-in first (by display name), then custom (by display name)
            schemas = fetchedSchemas.sorted { lhs, rhs in
                if lhs.isBuiltIn != rhs.isBuiltIn {
                    return lhs.isBuiltIn
                }
                return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }

            // Count records per schema
            await loadRecordCounts(fmk: fmk)
        } catch {
            errorMessage = "Unable to load schemas. Please try again."
            logger.logError(error, context: "SchemaListViewModel.loadSchemas")
        }

        isLoading = false
    }

    /// Create a new custom schema template with a unique ID
    ///
    /// - Returns: A new RecordSchema template ready for editing
    func createNewSchemaTemplate() -> RecordSchema {
        let schemaId = "custom-\(uuid().uuidString.lowercased().prefix(8))"
        return RecordSchema(
            unsafeId: schemaId,
            displayName: "New Record Type",
            iconSystemName: "doc.text",
            fields: [],
            isBuiltIn: false,
            description: nil
        )
    }

    /// Delete a custom schema
    ///
    /// - Parameter schemaId: The schema ID to delete
    /// - Returns: true if deletion succeeded, false if schema is built-in
    func deleteSchema(schemaId: String) async -> Bool {
        // Check if it's a built-in schema (cannot delete)
        if let schema = schemas.first(where: { $0.id == schemaId }), schema.isBuiltIn {
            errorMessage = "Built-in schemas cannot be deleted."
            return false
        }

        do {
            try await customSchemaRepository.delete(schemaId: schemaId, forPerson: person.id)
            schemas.removeAll { $0.id == schemaId }
            recordCounts.removeValue(forKey: schemaId)
            return true
        } catch {
            errorMessage = "Unable to delete schema. Please try again."
            logger.logError(error, context: "SchemaListViewModel.deleteSchema")
            return false
        }
    }

    // MARK: - Private

    /// Load record counts for each schema
    private func loadRecordCounts(fmk: SymmetricKey) async {
        do {
            // Fetch all medical records for this person
            let records = try await medicalRecordRepository.fetchForPerson(personId: person.id)

            // Count records by schema ID
            var counts: [String: Int] = [:]
            for record in records {
                let content = try recordContentService.decrypt(record.encryptedContent, using: fmk)
                if let schemaId = content.schemaId {
                    counts[schemaId, default: 0] += 1
                }
            }

            recordCounts = counts
        } catch {
            // Don't fail the whole operation - just log and continue with empty counts
            logger.logError(error, context: "SchemaListViewModel.loadRecordCounts")
        }
    }
}
