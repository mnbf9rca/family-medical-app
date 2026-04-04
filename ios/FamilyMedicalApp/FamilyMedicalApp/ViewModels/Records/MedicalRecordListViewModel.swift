import CryptoKit
import Foundation
import Observation

/// ViewModel for displaying a list of medical records of a specific type
@MainActor
@Observable
final class MedicalRecordListViewModel {
    // MARK: - State

    let person: Person
    let recordType: RecordType
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

    init(
        person: Person,
        recordType: RecordType,
        medicalRecordRepository: MedicalRecordRepositoryProtocol? = nil,
        recordContentService: RecordContentServiceProtocol? = nil,
        primaryKeyProvider: PrimaryKeyProviderProtocol? = nil,
        fmkService: FamilyMemberKeyServiceProtocol? = nil
    ) {
        self.person = person
        self.recordType = recordType
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

    func loadRecords() async {
        isLoading = true
        errorMessage = nil

        do {
            let primaryKey = try primaryKeyProvider.getPrimaryKey()
            let fmk = try fmkService.retrieveFMK(
                familyMemberID: person.id.uuidString,
                primaryKey: primaryKey
            )

            let allRecords = try await medicalRecordRepository.fetchForPerson(personId: person.id)

            var decryptedRecords: [DecryptedRecord] = []
            for record in allRecords {
                do {
                    let envelope = try recordContentService.decrypt(record.encryptedContent, using: fmk)
                    if envelope.recordType == recordType {
                        decryptedRecords.append(DecryptedRecord(record: record, envelope: envelope))
                    }
                } catch {
                    logger.logError(error, context: "MedicalRecordListViewModel.loadRecords - decrypt")
                }
            }

            // Sort newest first by creation date
            records = decryptedRecords.sorted { $0.record.createdAt > $1.record.createdAt }
        } catch {
            errorMessage = "Unable to load records. Please try again."
            logger.logError(error, context: "MedicalRecordListViewModel.loadRecords")
        }

        isLoading = false
    }

    func deleteRecord(id: UUID) async {
        isLoading = true
        errorMessage = nil

        do {
            try await medicalRecordRepository.delete(id: id)
            records.removeAll { $0.id == id }
        } catch {
            errorMessage = "Unable to delete record. Please try again."
            logger.logError(error, context: "MedicalRecordListViewModel.deleteRecord")
        }

        isLoading = false
    }
}
