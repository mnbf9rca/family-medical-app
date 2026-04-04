import CryptoKit
import Foundation
import Observation

/// ViewModel for person detail screen showing record types
@MainActor
@Observable
final class PersonDetailViewModel {
    // MARK: - State

    let person: Person
    var recordCounts: [RecordType: Int] = [:]
    var isLoading = false
    var errorMessage: String?

    // MARK: - Dependencies

    private let medicalRecordRepository: MedicalRecordRepositoryProtocol
    private let recordContentService: RecordContentServiceProtocol
    private let primaryKeyProvider: PrimaryKeyProviderProtocol
    private let fmkService: FamilyMemberKeyServiceProtocol
    private let logger = LoggingService.shared.logger(category: .storage)

    // MARK: - Initialization

    init(
        person: Person,
        medicalRecordRepository: MedicalRecordRepositoryProtocol? = nil,
        recordContentService: RecordContentServiceProtocol? = nil,
        primaryKeyProvider: PrimaryKeyProviderProtocol? = nil,
        fmkService: FamilyMemberKeyServiceProtocol? = nil
    ) {
        self.person = person
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

    func loadRecordCounts() async {
        isLoading = true
        errorMessage = nil

        do {
            let primaryKey = try primaryKeyProvider.getPrimaryKey()
            let fmk = try fmkService.retrieveFMK(
                familyMemberID: person.id.uuidString,
                primaryKey: primaryKey
            )

            let records = try await medicalRecordRepository.fetchForPerson(personId: person.id)

            var counts: [RecordType: Int] = [:]
            for record in records {
                do {
                    let envelope = try recordContentService.decrypt(record.encryptedContent, using: fmk)
                    counts[envelope.recordType, default: 0] += 1
                } catch {
                    logger.logError(error, context: "PersonDetailViewModel.loadRecordCounts - decrypt")
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
