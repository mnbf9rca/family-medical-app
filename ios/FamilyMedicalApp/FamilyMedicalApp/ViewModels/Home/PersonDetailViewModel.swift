import CryptoKit
import Foundation
import Observation

/// ViewModel for person detail screen showing record types
@MainActor
@Observable
final class PersonDetailViewModel {
    // MARK: - State

    let person: Person
    var recordCounts: [String: Int] = [:]
    var schemas: [String: RecordSchema] = [:]
    var isLoading = false
    var errorMessage: String?

    // MARK: - Dependencies

    private let medicalRecordRepository: MedicalRecordRepositoryProtocol
    private let recordContentService: RecordContentServiceProtocol
    private let primaryKeyProvider: PrimaryKeyProviderProtocol
    private let fmkService: FamilyMemberKeyServiceProtocol
    private let schemaService: SchemaServiceProtocol
    private let logger = LoggingService.shared.logger(category: .storage)

    // MARK: - Initialization

    init(
        person: Person,
        medicalRecordRepository: MedicalRecordRepositoryProtocol? = nil,
        recordContentService: RecordContentServiceProtocol? = nil,
        primaryKeyProvider: PrimaryKeyProviderProtocol? = nil,
        fmkService: FamilyMemberKeyServiceProtocol? = nil,
        schemaService: SchemaServiceProtocol? = nil
    ) {
        self.person = person
        // Use optional parameter pattern per ADR-0008
        self.medicalRecordRepository = medicalRecordRepository ?? MedicalRecordRepository(
            coreDataStack: CoreDataStack.shared
        )
        self.recordContentService = recordContentService ?? RecordContentService(
            encryptionService: EncryptionService()
        )
        self.primaryKeyProvider = primaryKeyProvider ?? PrimaryKeyProvider()
        self.fmkService = fmkService ?? FamilyMemberKeyService()
        self.schemaService = schemaService ?? SchemaService(
            schemaRepository: CustomSchemaRepository(
                coreDataStack: CoreDataStack.shared,
                encryptionService: EncryptionService()
            )
        )
    }

    // MARK: - Schema Access

    /// Get the user's schema for a built-in schema type
    func schemaForType(_ type: BuiltInSchemaType) -> RecordSchema? {
        schemas[type.rawValue]
    }

    // MARK: - Actions

    /// Load record counts for each schema type
    func loadRecordCounts() async {
        isLoading = true
        errorMessage = nil

        do {
            // Get the primary key and FMK
            let primaryKey = try primaryKeyProvider.getPrimaryKey()
            let fmk = try fmkService.retrieveFMK(
                familyMemberID: person.id.uuidString,
                primaryKey: primaryKey
            )

            // Fetch user's schemas for display
            let fetchedSchemas = try await schemaService.builtInSchemas(
                forPerson: person.id,
                familyMemberKey: fmk
            )
            schemas = Dictionary(fetchedSchemas.map { ($0.id, $0) }) { _, latest in latest }

            // Fetch all medical records for this person
            let records = try await medicalRecordRepository.fetchForPerson(personId: person.id)

            // Count records by schema type
            var counts: [String: Int] = [:]
            for record in records {
                let content = try recordContentService.decrypt(record.encryptedContent, using: fmk)
                if let schemaId = content.schemaId {
                    counts[schemaId, default: 0] += 1
                }
            }

            recordCounts = counts
        } catch {
            errorMessage = "Unable to load records. Please try again."
            logger.logError(error, context: "PersonDetailViewModel.loadRecordCounts")
        }

        isLoading = false
    }
}
