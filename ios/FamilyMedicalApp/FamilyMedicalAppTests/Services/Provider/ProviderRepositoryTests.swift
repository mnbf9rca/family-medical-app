import CryptoKit
import Foundation
import Testing
@testable import FamilyMedicalApp

// MARK: - Shared fixtures

struct ProviderTestFixtures {
    let repository: ProviderRepository
    let coreDataStack: MockCoreDataStack
    let encryptionService: MockEncryptionService
    let fmkService: MockFamilyMemberKeyService
}

func makeProviderRepositoryWithMocks() -> ProviderTestFixtures {
    let stack = MockCoreDataStack()
    let encryption = MockEncryptionService()
    let fmkService = MockFamilyMemberKeyService()
    let repo = ProviderRepository(
        coreDataStack: stack,
        encryptionService: encryption,
        fmkService: fmkService
    )
    return ProviderTestFixtures(
        repository: repo,
        coreDataStack: stack,
        encryptionService: encryption,
        fmkService: fmkService
    )
}

func makeTestProvider(
    name: String? = "Dr. Smith",
    organization: String? = "City Hospital"
) -> Provider {
    Provider(name: name, organization: organization)
}

func preSeedProviderFMK(fmkService: MockFamilyMemberKeyService, personId: UUID, primaryKey: SymmetricKey) {
    let fmk = fmkService.generateFMK()
    fmkService.storedFMKs[personId.uuidString] = fmk
}

// MARK: - Save and Fetch Tests

@Suite("ProviderRepository Tests")
struct ProviderRepositoryTests {
    let testPrimaryKey = SymmetricKey(size: .bits256)
    let testPersonId = UUID()

    @Test("Save new provider stores in Core Data")
    func save_newProvider_storesInCoreData() async throws {
        let fixtures = makeProviderRepositoryWithMocks()
        preSeedProviderFMK(fmkService: fixtures.fmkService, personId: testPersonId, primaryKey: testPrimaryKey)

        let provider = makeTestProvider()
        try await fixtures.repository.save(provider, personId: testPersonId, primaryKey: testPrimaryKey)

        let fetched = try await fixtures.repository.fetch(
            byId: provider.id,
            personId: testPersonId,
            primaryKey: testPrimaryKey
        )
        #expect(fetched != nil)
    }

    @Test("Save new provider encrypts data")
    func save_newProvider_encryptsData() async throws {
        let fixtures = makeProviderRepositoryWithMocks()
        preSeedProviderFMK(fmkService: fixtures.fmkService, personId: testPersonId, primaryKey: testPrimaryKey)

        let provider = makeTestProvider()
        try await fixtures.repository.save(provider, personId: testPersonId, primaryKey: testPrimaryKey)

        #expect(fixtures.encryptionService.encryptCalls.count == 1)
    }

    @Test("Save existing provider updates without re-encrypting with new key")
    func save_existingProvider_updatesRecord() async throws {
        let fixtures = makeProviderRepositoryWithMocks()
        preSeedProviderFMK(fmkService: fixtures.fmkService, personId: testPersonId, primaryKey: testPrimaryKey)

        var provider = makeTestProvider()
        try await fixtures.repository.save(provider, personId: testPersonId, primaryKey: testPrimaryKey)

        provider.specialty = "Updated Specialty"
        try await fixtures.repository.save(provider, personId: testPersonId, primaryKey: testPrimaryKey)

        let fetched = try await fixtures.repository.fetch(
            byId: provider.id,
            personId: testPersonId,
            primaryKey: testPrimaryKey
        )
        #expect(fetched?.specialty == "Updated Specialty")
    }

    @Test("Save fails when FMK not available")
    func save_fmkNotFound_throwsError() async throws {
        let fixtures = makeProviderRepositoryWithMocks()

        let provider = makeTestProvider()
        await #expect(throws: RepositoryError.self) {
            try await fixtures.repository.save(provider, personId: testPersonId, primaryKey: testPrimaryKey)
        }
    }

    @Test("Save fails when encryption fails")
    func save_encryptionFails_throwsError() async throws {
        let fixtures = makeProviderRepositoryWithMocks()
        preSeedProviderFMK(fmkService: fixtures.fmkService, personId: testPersonId, primaryKey: testPrimaryKey)
        fixtures.encryptionService.shouldFailEncryption = true

        let provider = makeTestProvider()
        await #expect(throws: RepositoryError.self) {
            try await fixtures.repository.save(provider, personId: testPersonId, primaryKey: testPrimaryKey)
        }
    }

    @Test("Fetch existing provider returns decrypted provider")
    func fetch_existingProvider_returnsDecryptedProvider() async throws {
        let fixtures = makeProviderRepositoryWithMocks()
        preSeedProviderFMK(fmkService: fixtures.fmkService, personId: testPersonId, primaryKey: testPrimaryKey)

        let provider = Provider(
            name: "Dr. Jones",
            organization: "General Hospital",
            specialty: "Cardiology",
            phone: "555-0001",
            address: "1 Hospital Way",
            notes: "Primary cardiologist"
        )
        try await fixtures.repository.save(provider, personId: testPersonId, primaryKey: testPrimaryKey)

        let fetched = try await fixtures.repository.fetch(
            byId: provider.id,
            personId: testPersonId,
            primaryKey: testPrimaryKey
        )

        #expect(fetched?.id == provider.id)
        #expect(fetched?.name == provider.name)
        #expect(fetched?.specialty == provider.specialty)
        #expect(fetched?.phone == provider.phone)
    }

    @Test("Fetch non-existent provider returns nil")
    func fetch_nonExistentProvider_returnsNil() async throws {
        let fixtures = makeProviderRepositoryWithMocks()
        preSeedProviderFMK(fmkService: fixtures.fmkService, personId: testPersonId, primaryKey: testPrimaryKey)

        let result = try await fixtures.repository.fetch(
            byId: UUID(),
            personId: testPersonId,
            primaryKey: testPrimaryKey
        )
        #expect(result == nil)
    }

    @Test("Fetch provider belonging to different person returns nil")
    func fetch_differentPersonId_returnsNil() async throws {
        let fixtures = makeProviderRepositoryWithMocks()
        preSeedProviderFMK(fmkService: fixtures.fmkService, personId: testPersonId, primaryKey: testPrimaryKey)

        let provider = makeTestProvider()
        try await fixtures.repository.save(provider, personId: testPersonId, primaryKey: testPrimaryKey)

        let otherPersonId = UUID()
        preSeedProviderFMK(fmkService: fixtures.fmkService, personId: otherPersonId, primaryKey: testPrimaryKey)

        let result = try await fixtures.repository.fetch(
            byId: provider.id,
            personId: otherPersonId,
            primaryKey: testPrimaryKey
        )
        #expect(result == nil)
    }

    @Test("Fetch fails when decryption fails")
    func fetch_decryptionFails_throwsError() async throws {
        let fixtures = makeProviderRepositoryWithMocks()
        preSeedProviderFMK(fmkService: fixtures.fmkService, personId: testPersonId, primaryKey: testPrimaryKey)

        let provider = makeTestProvider()
        try await fixtures.repository.save(provider, personId: testPersonId, primaryKey: testPrimaryKey)
        fixtures.encryptionService.shouldFailDecryption = true

        await #expect(throws: RepositoryError.self) {
            _ = try await fixtures.repository.fetch(
                byId: provider.id,
                personId: testPersonId,
                primaryKey: testPrimaryKey
            )
        }
    }

    @Test("Fetch fails when FMK not available")
    func fetch_fmkNotFound_throwsError() async throws {
        let fixtures = makeProviderRepositoryWithMocks()
        preSeedProviderFMK(fmkService: fixtures.fmkService, personId: testPersonId, primaryKey: testPrimaryKey)

        let provider = makeTestProvider()
        try await fixtures.repository.save(provider, personId: testPersonId, primaryKey: testPrimaryKey)
        fixtures.fmkService.storedFMKs.removeAll()

        await #expect(throws: RepositoryError.self) {
            _ = try await fixtures.repository.fetch(
                byId: provider.id,
                personId: testPersonId,
                primaryKey: testPrimaryKey
            )
        }
    }
}

// MARK: - FetchAll and Delete Tests

@Suite("ProviderRepository FetchAll and Delete Tests")
struct ProviderRepositoryFetchAllDeleteTests {
    let testPrimaryKey = SymmetricKey(size: .bits256)
    let testPersonId = UUID()

    @Test("FetchAll returns all providers for person")
    func fetchAll_multipleProviders_returnsAll() async throws {
        let fixtures = makeProviderRepositoryWithMocks()
        preSeedProviderFMK(fmkService: fixtures.fmkService, personId: testPersonId, primaryKey: testPrimaryKey)

        let provider1 = Provider(name: "Dr. A", organization: "Hospital A")
        let provider2 = Provider(name: "Dr. B", organization: "Hospital B")
        let provider3 = Provider(organization: "Clinic C")

        try await fixtures.repository.save(provider1, personId: testPersonId, primaryKey: testPrimaryKey)
        try await fixtures.repository.save(provider2, personId: testPersonId, primaryKey: testPrimaryKey)
        try await fixtures.repository.save(provider3, personId: testPersonId, primaryKey: testPrimaryKey)

        let all = try await fixtures.repository.fetchAll(forPerson: testPersonId, primaryKey: testPrimaryKey)

        #expect(all.count == 3)
        #expect(all.contains { $0.id == provider1.id })
        #expect(all.contains { $0.id == provider2.id })
    }

    @Test("FetchAll returns empty array when no providers")
    func fetchAll_noProviders_returnsEmpty() async throws {
        let fixtures = makeProviderRepositoryWithMocks()
        preSeedProviderFMK(fmkService: fixtures.fmkService, personId: testPersonId, primaryKey: testPrimaryKey)

        let all = try await fixtures.repository.fetchAll(forPerson: testPersonId, primaryKey: testPrimaryKey)
        #expect(all.isEmpty)
    }

    @Test("FetchAll only returns providers for specified person")
    func fetchAll_onlyReturnsScopeToPersonId() async throws {
        let fixtures = makeProviderRepositoryWithMocks()
        let otherPersonId = UUID()

        preSeedProviderFMK(fmkService: fixtures.fmkService, personId: testPersonId, primaryKey: testPrimaryKey)
        preSeedProviderFMK(fmkService: fixtures.fmkService, personId: otherPersonId, primaryKey: testPrimaryKey)

        let providerForPerson = Provider(name: "Dr. A")
        let providerForOther = Provider(name: "Dr. B")

        try await fixtures.repository.save(providerForPerson, personId: testPersonId, primaryKey: testPrimaryKey)
        try await fixtures.repository.save(providerForOther, personId: otherPersonId, primaryKey: testPrimaryKey)

        let results = try await fixtures.repository.fetchAll(forPerson: testPersonId, primaryKey: testPrimaryKey)

        #expect(results.count == 1)
        #expect(results[0].id == providerForPerson.id)
    }

    @Test("FetchAll fails when decryption fails")
    func fetchAll_decryptionFails_throwsError() async throws {
        let fixtures = makeProviderRepositoryWithMocks()
        preSeedProviderFMK(fmkService: fixtures.fmkService, personId: testPersonId, primaryKey: testPrimaryKey)

        let provider = makeTestProvider()
        try await fixtures.repository.save(provider, personId: testPersonId, primaryKey: testPrimaryKey)
        fixtures.encryptionService.shouldFailDecryption = true

        await #expect(throws: RepositoryError.self) {
            _ = try await fixtures.repository.fetchAll(forPerson: testPersonId, primaryKey: testPrimaryKey)
        }
    }

    @Test("Delete existing provider removes it")
    func delete_existingProvider_removes() async throws {
        let fixtures = makeProviderRepositoryWithMocks()
        preSeedProviderFMK(fmkService: fixtures.fmkService, personId: testPersonId, primaryKey: testPrimaryKey)

        let provider = makeTestProvider()
        try await fixtures.repository.save(provider, personId: testPersonId, primaryKey: testPrimaryKey)
        try await fixtures.repository.delete(id: provider.id)

        let result = try await fixtures.repository.fetch(
            byId: provider.id,
            personId: testPersonId,
            primaryKey: testPrimaryKey
        )
        #expect(result == nil)
    }

    @Test("Delete non-existent provider throws error")
    func delete_nonExistentProvider_throwsError() async throws {
        let fixtures = makeProviderRepositoryWithMocks()

        await #expect(throws: RepositoryError.self) {
            try await fixtures.repository.delete(id: UUID())
        }
    }
}

// MARK: - Search Tests

@Suite("ProviderRepository Search Tests")
struct ProviderRepositorySearchTests {
    let testPrimaryKey = SymmetricKey(size: .bits256)
    let testPersonId = UUID()

    @Test("Search returns providers matching name")
    func search_matchesName() async throws {
        let fixtures = makeProviderRepositoryWithMocks()
        preSeedProviderFMK(fmkService: fixtures.fmkService, personId: testPersonId, primaryKey: testPrimaryKey)

        let drSmith = Provider(name: "Dr. Smith", organization: "Any Hospital")
        let drJones = Provider(name: "Dr. Jones", organization: "Other Clinic")
        try await fixtures.repository.save(drSmith, personId: testPersonId, primaryKey: testPrimaryKey)
        try await fixtures.repository.save(drJones, personId: testPersonId, primaryKey: testPrimaryKey)

        let results = try await fixtures.repository.search(
            query: "Smith",
            forPerson: testPersonId,
            primaryKey: testPrimaryKey
        )

        #expect(results.count == 1)
        #expect(results[0].id == drSmith.id)
    }

    @Test("Search returns providers matching organization")
    func search_matchesOrganization() async throws {
        let fixtures = makeProviderRepositoryWithMocks()
        preSeedProviderFMK(fmkService: fixtures.fmkService, personId: testPersonId, primaryKey: testPrimaryKey)

        let cityHospital = Provider(name: "Dr. Smith", organization: "City Hospital")
        let generalClinic = Provider(name: "Dr. Jones", organization: "General Clinic")
        try await fixtures.repository.save(cityHospital, personId: testPersonId, primaryKey: testPrimaryKey)
        try await fixtures.repository.save(generalClinic, personId: testPersonId, primaryKey: testPrimaryKey)

        let results = try await fixtures.repository.search(
            query: "City",
            forPerson: testPersonId,
            primaryKey: testPrimaryKey
        )

        #expect(results.count == 1)
        #expect(results[0].id == cityHospital.id)
    }

    @Test("Search is case-insensitive")
    func search_caseInsensitive() async throws {
        let fixtures = makeProviderRepositoryWithMocks()
        preSeedProviderFMK(fmkService: fixtures.fmkService, personId: testPersonId, primaryKey: testPrimaryKey)

        let provider = Provider(name: "Dr. Smith", organization: "City Hospital")
        try await fixtures.repository.save(provider, personId: testPersonId, primaryKey: testPrimaryKey)

        let resultsLower = try await fixtures.repository.search(
            query: "smith", forPerson: testPersonId, primaryKey: testPrimaryKey
        )
        let resultsUpper = try await fixtures.repository.search(
            query: "SMITH", forPerson: testPersonId, primaryKey: testPrimaryKey
        )
        let resultsMixed = try await fixtures.repository.search(
            query: "SmItH", forPerson: testPersonId, primaryKey: testPrimaryKey
        )

        #expect(resultsLower.count == 1)
        #expect(resultsUpper.count == 1)
        #expect(resultsMixed.count == 1)
    }

    @Test("Search returns empty when no matches")
    func search_noMatches_returnsEmpty() async throws {
        let fixtures = makeProviderRepositoryWithMocks()
        preSeedProviderFMK(fmkService: fixtures.fmkService, personId: testPersonId, primaryKey: testPrimaryKey)

        let provider = Provider(name: "Dr. Smith", organization: "City Hospital")
        try await fixtures.repository.save(provider, personId: testPersonId, primaryKey: testPrimaryKey)

        let results = try await fixtures.repository.search(
            query: "nonexistent",
            forPerson: testPersonId,
            primaryKey: testPrimaryKey
        )
        #expect(results.isEmpty)
    }

    @Test("Search returns multiple matches")
    func search_multipleMatches() async throws {
        let fixtures = makeProviderRepositoryWithMocks()
        preSeedProviderFMK(fmkService: fixtures.fmkService, personId: testPersonId, primaryKey: testPrimaryKey)

        let provider1 = Provider(name: "Dr. Smith", organization: "Smith Medical")
        let provider2 = Provider(name: "Dr. Jane Smith", organization: "City Hospital")
        try await fixtures.repository.save(provider1, personId: testPersonId, primaryKey: testPrimaryKey)
        try await fixtures.repository.save(provider2, personId: testPersonId, primaryKey: testPrimaryKey)

        let results = try await fixtures.repository.search(
            query: "Smith",
            forPerson: testPersonId,
            primaryKey: testPrimaryKey
        )

        #expect(results.count == 2)
    }

    @Test("Search is scoped to person")
    func search_scopedToPersonId() async throws {
        let fixtures = makeProviderRepositoryWithMocks()
        let otherPersonId = UUID()

        preSeedProviderFMK(fmkService: fixtures.fmkService, personId: testPersonId, primaryKey: testPrimaryKey)
        preSeedProviderFMK(fmkService: fixtures.fmkService, personId: otherPersonId, primaryKey: testPrimaryKey)

        let providerForPerson = Provider(name: "Dr. Smith", organization: "City Hospital")
        let providerForOther = Provider(name: "Dr. Smith", organization: "Other Hospital")

        try await fixtures.repository.save(providerForPerson, personId: testPersonId, primaryKey: testPrimaryKey)
        try await fixtures.repository.save(providerForOther, personId: otherPersonId, primaryKey: testPrimaryKey)

        let results = try await fixtures.repository.search(
            query: "Smith",
            forPerson: testPersonId,
            primaryKey: testPrimaryKey
        )

        #expect(results.count == 1)
        #expect(results[0].id == providerForPerson.id)
    }
}
