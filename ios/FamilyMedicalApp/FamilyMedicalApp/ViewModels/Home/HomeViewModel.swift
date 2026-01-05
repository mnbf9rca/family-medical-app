import CryptoKit
import Foundation
import Observation

/// ViewModel for the home screen displaying members list
@MainActor
@Observable
final class HomeViewModel {
    // MARK: - State

    var persons: [Person] = []
    var isLoading = false
    var errorMessage: String?

    // MARK: - Dependencies

    private let personRepository: PersonRepositoryProtocol
    private let primaryKeyProvider: PrimaryKeyProviderProtocol
    private let fmkService: FamilyMemberKeyServiceProtocol
    private let schemaSeeder: SchemaSeederProtocol
    private let logger = LoggingService.shared.logger(category: .ui)

    // MARK: - Initialization

    init(
        personRepository: PersonRepositoryProtocol? = nil,
        primaryKeyProvider: PrimaryKeyProviderProtocol? = nil,
        fmkService: FamilyMemberKeyServiceProtocol? = nil,
        schemaSeeder: SchemaSeederProtocol? = nil
    ) {
        // Use optional parameter pattern per ADR-0008
        let fmk = fmkService ?? FamilyMemberKeyService()
        self.fmkService = fmk
        self.personRepository = personRepository ?? PersonRepository(
            coreDataStack: CoreDataStack.shared,
            encryptionService: EncryptionService(),
            fmkService: fmk
        )
        self.primaryKeyProvider = primaryKeyProvider ?? PrimaryKeyProvider()
        self.schemaSeeder = schemaSeeder ?? SchemaSeeder(
            schemaRepository: CustomSchemaRepository(
                coreDataStack: CoreDataStack.shared,
                encryptionService: EncryptionService()
            )
        )
    }

    // MARK: - Actions

    /// Load all persons from the repository
    func loadPersons() async {
        isLoading = true
        errorMessage = nil

        do {
            let primaryKey = try primaryKeyProvider.getPrimaryKey()
            persons = try await personRepository.fetchAll(primaryKey: primaryKey)
        } catch {
            errorMessage = "Unable to load members. Please try again."
            logger.logError(error, context: "HomeViewModel.loadPersons")
        }

        isLoading = false
    }

    /// Create a new person
    ///
    /// After saving the person, this also seeds built-in schemas for them.
    /// Each Person has their own copy of schemas, encrypted with their FMK.
    ///
    /// - Parameter person: The person to create
    func createPerson(_ person: Person) async {
        isLoading = true
        errorMessage = nil

        do {
            let primaryKey = try primaryKeyProvider.getPrimaryKey()
            try await personRepository.save(person, primaryKey: primaryKey)

            // Seed built-in schemas for the new Person
            // FMK is created by personRepository.save() so we can retrieve it now
            let fmk = try fmkService.retrieveFMK(familyMemberID: person.id.uuidString, primaryKey: primaryKey)
            try await schemaSeeder.seedBuiltInSchemas(forPerson: person.id, familyMemberKey: fmk)

            // Reload the list after successful save
            await loadPersons()
        } catch {
            errorMessage = "Unable to save this member. Please try again."
            logger.logError(error, context: "HomeViewModel.createPerson")
            isLoading = false
        }
    }

    /// Delete a person by ID
    /// - Parameter id: The person's ID to delete
    func deletePerson(id: UUID) async {
        isLoading = true
        errorMessage = nil

        do {
            try await personRepository.delete(id: id)
            // Reload the list after successful delete
            await loadPersons()
        } catch {
            errorMessage = "Unable to remove this member. Please try again."
            logger.logError(error, context: "HomeViewModel.deletePerson")
            isLoading = false
        }
    }
}
