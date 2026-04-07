import CryptoKit
import Foundation
import Testing
@testable import FamilyMedicalApp

@Suite("ImportService Extended Tests")
struct ImportServiceExtendedTests {
    // MARK: - Test Setup

    let testPrimaryKey = SymmetricKey(size: .bits256)

    func makeService(
        personRepository: MockPersonRepository = MockPersonRepository(),
        recordRepository: MockMedicalRecordRepository = MockMedicalRecordRepository(),
        recordContentService: MockRecordContentService = MockRecordContentService(),
        providerRepository: MockProviderRepository = MockProviderRepository(),
        fmkService: MockFamilyMemberKeyService = MockFamilyMemberKeyService()
    ) -> ImportService {
        ImportService(
            personRepository: personRepository,
            recordRepository: recordRepository,
            recordContentService: recordContentService,
            providerRepository: providerRepository,
            fmkService: fmkService
        )
    }

    func makeTestPayload(
        persons: [PersonBackup] = [],
        records: [MedicalRecordBackup] = [],
        providers: [ProviderBackup] = []
    ) -> BackupPayload {
        BackupPayload(
            exportedAt: Date(),
            appVersion: "1.0.0",
            metadata: BackupMetadata(
                personCount: persons.count,
                recordCount: records.count,
                providerCount: providers.count
            ),
            persons: persons,
            records: records,
            providers: providers
        )
    }

    func makePersonBackup(name: String = "Test Person") -> PersonBackup {
        PersonBackup(
            id: UUID(),
            name: name,
            dateOfBirth: Date(),
            labels: ["child"],
            notes: "Test notes",
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    func makeRecordBackup(personId: UUID) throws -> MedicalRecordBackup {
        let immunization = ImmunizationRecord(vaccineCode: "COVID-19", occurrenceDate: Date())
        let contentJSON = try JSONEncoder().encode(immunization)
        return MedicalRecordBackup(
            id: UUID(),
            personId: personId,
            recordType: "immunization",
            schemaVersion: 1,
            contentJSON: contentJSON,
            createdAt: Date(),
            updatedAt: Date(),
            version: 1,
            previousVersionId: nil
        )
    }

    // MARK: - Full Import Tests

    @Test("Full import includes all data types")
    func fullImportIncludesAllData() async throws {
        let personRepository = MockPersonRepository()
        let recordRepository = MockMedicalRecordRepository()
        let recordContentService = MockRecordContentService()
        let fmkService = MockFamilyMemberKeyService()

        let service = makeService(
            personRepository: personRepository,
            recordRepository: recordRepository,
            recordContentService: recordContentService,
            fmkService: fmkService
        )

        let personBackup = makePersonBackup(name: "Full Test")
        let recordBackup = try makeRecordBackup(personId: personBackup.id)

        let payload = makeTestPayload(
            persons: [personBackup],
            records: [recordBackup]
        )

        try await service.importData(payload, primaryKey: testPrimaryKey)

        #expect(personRepository.saveCallCount == 1)
        #expect(recordRepository.saveCallCount == 1)
    }

    // MARK: - Error Handling Tests

    @Test("Throws error when record has no matching person FMK")
    func throwsWhenRecordHasNoPersonFMK() async throws {
        let personRepository = MockPersonRepository()
        let recordRepository = MockMedicalRecordRepository()
        let fmkService = MockFamilyMemberKeyService()

        let service = makeService(
            personRepository: personRepository,
            recordRepository: recordRepository,
            fmkService: fmkService
        )

        // Record references a person that isn't being imported
        let unrelatedPersonId = UUID()
        let recordBackup = try makeRecordBackup(personId: unrelatedPersonId)
        let payload = makeTestPayload(records: [recordBackup])

        await #expect(throws: BackupError.self) {
            try await service.importData(payload, primaryKey: testPrimaryKey)
        }
    }

    @Test("Throws error when record content encryption fails")
    func throwsOnRecordEncryptionFailure() async throws {
        let personRepository = MockPersonRepository()
        let recordRepository = MockMedicalRecordRepository()
        let recordContentService = MockRecordContentService()
        let fmkService = MockFamilyMemberKeyService()
        recordContentService.shouldFailEncrypt = true

        let service = makeService(
            personRepository: personRepository,
            recordRepository: recordRepository,
            recordContentService: recordContentService,
            fmkService: fmkService
        )

        let personBackup = makePersonBackup()
        let recordBackup = try makeRecordBackup(personId: personBackup.id)
        let payload = makeTestPayload(persons: [personBackup], records: [recordBackup])

        await #expect(throws: BackupError.self) {
            try await service.importData(payload, primaryKey: testPrimaryKey)
        }
    }
}
