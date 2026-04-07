import CryptoKit
import Foundation
import Testing
@testable import FamilyMedicalApp

@Suite("ExportService Tests")
struct ExportServiceTests {
    // MARK: - Test Setup

    let testPrimaryKey = SymmetricKey(size: .bits256)

    func makeService(
        personRepository: MockPersonRepository = MockPersonRepository(),
        recordRepository: MockMedicalRecordRepository = MockMedicalRecordRepository(),
        recordContentService: MockRecordContentService = MockRecordContentService(),
        providerRepository: MockProviderRepository = MockProviderRepository(),
        fmkService: MockFamilyMemberKeyService = MockFamilyMemberKeyService()
    ) -> ExportService {
        ExportService(
            personRepository: personRepository,
            recordRepository: recordRepository,
            recordContentService: recordContentService,
            providerRepository: providerRepository,
            fmkService: fmkService
        )
    }

    func makeTestPerson(name: String = "Test Person") throws -> Person {
        try Person(
            id: UUID(),
            name: name,
            dateOfBirth: Date(),
            labels: ["child"],
            notes: "Test notes"
        )
    }

    func makeTestEnvelope() throws -> RecordContentEnvelope {
        let immunization = ImmunizationRecord(vaccineCode: "COVID-19", occurrenceDate: Date())
        return try RecordContentEnvelope(immunization)
    }

    // MARK: - Empty Export Tests

    @Test("Exports empty payload when no data exists")
    func exportsEmptyPayload() async throws {
        let service = makeService()

        let payload = try await service.exportData(primaryKey: testPrimaryKey)

        #expect(payload.isEmpty)
        #expect(payload.persons.isEmpty)
        #expect(payload.records.isEmpty)
        #expect(payload.metadata.personCount == 0)
    }

    // MARK: - Person Export Tests

    @Test("Exports persons correctly")
    func exportsPersons() async throws {
        let personRepository = MockPersonRepository()
        let fmkService = MockFamilyMemberKeyService()

        let person = try makeTestPerson(name: "Alice")
        personRepository.addPerson(person)
        fmkService.setFMK(SymmetricKey(size: .bits256), for: person.id.uuidString)

        let service = makeService(
            personRepository: personRepository,
            fmkService: fmkService
        )

        let payload = try await service.exportData(primaryKey: testPrimaryKey)

        #expect(payload.persons.count == 1)
        #expect(payload.persons[0].name == "Alice")
        #expect(payload.persons[0].id == person.id)
        #expect(payload.metadata.personCount == 1)
    }

    @Test("Exports multiple persons")
    func exportsMultiplePersons() async throws {
        let personRepository = MockPersonRepository()
        let fmkService = MockFamilyMemberKeyService()

        let alice = try makeTestPerson(name: "Alice")
        let bob = try makeTestPerson(name: "Bob")
        personRepository.addPerson(alice)
        personRepository.addPerson(bob)
        fmkService.setFMK(SymmetricKey(size: .bits256), for: alice.id.uuidString)
        fmkService.setFMK(SymmetricKey(size: .bits256), for: bob.id.uuidString)

        let service = makeService(
            personRepository: personRepository,
            fmkService: fmkService
        )

        let payload = try await service.exportData(primaryKey: testPrimaryKey)

        #expect(payload.persons.count == 2)
        #expect(payload.metadata.personCount == 2)
    }

    // MARK: - Medical Record Export Tests

    @Test("Exports medical records for persons")
    func exportsMedicalRecords() async throws {
        let personRepository = MockPersonRepository()
        let recordRepository = MockMedicalRecordRepository()
        let recordContentService = MockRecordContentService()
        let fmkService = MockFamilyMemberKeyService()

        let person = try makeTestPerson()
        let fmk = SymmetricKey(size: .bits256)
        personRepository.addPerson(person)
        fmkService.setFMK(fmk, for: person.id.uuidString)

        let envelope = try makeTestEnvelope()
        let encryptedContent = try recordContentService.encrypt(envelope, using: fmk)
        let record = MedicalRecord(
            id: UUID(),
            personId: person.id,
            encryptedContent: encryptedContent,
            createdAt: Date(),
            updatedAt: Date(),
            version: 1,
            previousVersionId: nil
        )
        recordRepository.addRecord(record)

        let service = makeService(
            personRepository: personRepository,
            recordRepository: recordRepository,
            recordContentService: recordContentService,
            fmkService: fmkService
        )

        let payload = try await service.exportData(primaryKey: testPrimaryKey)

        #expect(payload.records.count == 1)
        #expect(payload.records[0].personId == person.id)
        #expect(payload.records[0].recordType == "immunization")
        #expect(payload.metadata.recordCount == 1)
    }

    // MARK: - Provider Export Tests

    @Test("Exports providers for persons")
    func exportsProviders() async throws {
        let personRepository = MockPersonRepository()
        let providerRepository = MockProviderRepository()
        let fmkService = MockFamilyMemberKeyService()

        let person = try makeTestPerson()
        let fmk = SymmetricKey(size: .bits256)
        personRepository.addPerson(person)
        fmkService.setFMK(fmk, for: person.id.uuidString)

        let provider = Provider(name: "Dr. Smith", organization: "City Hospital")
        providerRepository.addProvider(provider, personId: person.id)

        let service = makeService(
            personRepository: personRepository,
            providerRepository: providerRepository,
            fmkService: fmkService
        )

        let payload = try await service.exportData(primaryKey: testPrimaryKey)

        #expect(payload.providers.count == 1)
        #expect(payload.providers[0].personId == person.id)
        #expect(payload.providers[0].name == "Dr. Smith")
        #expect(payload.providers[0].organization == "City Hospital")
        #expect(payload.metadata.providerCount == 1)
    }

    @Test("Exports empty providers when person has none")
    func exportsEmptyProvidersWhenNone() async throws {
        let personRepository = MockPersonRepository()
        let fmkService = MockFamilyMemberKeyService()

        let person = try makeTestPerson()
        personRepository.addPerson(person)
        fmkService.setFMK(SymmetricKey(size: .bits256), for: person.id.uuidString)

        let service = makeService(
            personRepository: personRepository,
            fmkService: fmkService
        )

        let payload = try await service.exportData(primaryKey: testPrimaryKey)

        #expect(payload.providers.isEmpty)
        #expect(payload.metadata.providerCount == 0)
    }
}
