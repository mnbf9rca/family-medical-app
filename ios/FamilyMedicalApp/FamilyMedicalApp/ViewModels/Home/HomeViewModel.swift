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
    private let logger = LoggingService.shared.logger(category: .ui)

    // MARK: - Initialization

    init(
        personRepository: PersonRepositoryProtocol? = nil,
        primaryKeyProvider: PrimaryKeyProviderProtocol? = nil
    ) {
        // Use optional parameter pattern per ADR-0008
        self.personRepository = personRepository ?? PersonRepository(
            coreDataStack: CoreDataStack.shared,
            encryptionService: EncryptionService(),
            fmkService: FamilyMemberKeyService()
        )
        self.primaryKeyProvider = primaryKeyProvider ?? PrimaryKeyProvider()
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
    /// - Parameter person: The person to create
    func createPerson(_ person: Person) async {
        isLoading = true
        errorMessage = nil

        do {
            let primaryKey = try primaryKeyProvider.getPrimaryKey()
            try await personRepository.save(person, primaryKey: primaryKey)
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
