import CryptoKit
import Foundation
import Testing
@testable import FamilyMedicalApp

@Suite("ProviderRepository Delete and Search Tests")
struct ProviderRepositoryDeleteSearchTests {
    let testPrimaryKey = SymmetricKey(size: .bits256)
    let testPersonId = UUID()

    // MARK: - Factory Methods

    func makeRepositoryWithMocks() -> ProviderRepositoryTests.TestFixtures {
        let stack = MockCoreDataStack()
        let encryption = MockEncryptionService()
        let fmkService = MockFamilyMemberKeyService()
        let repo = ProviderRepository(
            coreDataStack: stack,
            encryptionService: encryption,
            fmkService: fmkService
        )
        return ProviderRepositoryTests.TestFixtures(
            repository: repo,
            coreDataStack: stack,
            encryptionService: encryption,
            fmkService: fmkService
        )
    }

    func preSeedFMK(fmkService: MockFamilyMemberKeyService, personId: UUID, primaryKey: SymmetricKey) {
        let fmk = fmkService.generateFMK()
        fmkService.storedFMKs[personId.uuidString] = fmk
    }

    // MARK: - Delete Tests

    @Test("Delete existing provider removes it")
    func delete_existingProvider_removes() async throws {
        let fixtures = makeRepositoryWithMocks()
        preSeedFMK(fmkService: fixtures.fmkService, personId: testPersonId, primaryKey: testPrimaryKey)

        let provider = Provider(name: "Dr. Smith", organization: "City Hospital")
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
        let fixtures = makeRepositoryWithMocks()

        await #expect(throws: RepositoryError.self) {
            try await fixtures.repository.delete(id: UUID())
        }
    }

    // MARK: - Search Tests

    @Test("Search returns providers matching name")
    func search_matchesName() async throws {
        let fixtures = makeRepositoryWithMocks()
        preSeedFMK(fmkService: fixtures.fmkService, personId: testPersonId, primaryKey: testPrimaryKey)

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
        let fixtures = makeRepositoryWithMocks()
        preSeedFMK(fmkService: fixtures.fmkService, personId: testPersonId, primaryKey: testPrimaryKey)

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
        let fixtures = makeRepositoryWithMocks()
        preSeedFMK(fmkService: fixtures.fmkService, personId: testPersonId, primaryKey: testPrimaryKey)

        let provider = Provider(name: "Dr. Smith", organization: "City Hospital")
        try await fixtures.repository.save(provider, personId: testPersonId, primaryKey: testPrimaryKey)

        let resultsLower = try await fixtures.repository.search(
            query: "smith",
            forPerson: testPersonId,
            primaryKey: testPrimaryKey
        )
        let resultsUpper = try await fixtures.repository.search(
            query: "SMITH",
            forPerson: testPersonId,
            primaryKey: testPrimaryKey
        )
        let resultsMixed = try await fixtures.repository.search(
            query: "SmItH",
            forPerson: testPersonId,
            primaryKey: testPrimaryKey
        )

        #expect(resultsLower.count == 1)
        #expect(resultsUpper.count == 1)
        #expect(resultsMixed.count == 1)
    }

    @Test("Search returns empty when no matches")
    func search_noMatches_returnsEmpty() async throws {
        let fixtures = makeRepositoryWithMocks()
        preSeedFMK(fmkService: fixtures.fmkService, personId: testPersonId, primaryKey: testPrimaryKey)

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
        let fixtures = makeRepositoryWithMocks()
        preSeedFMK(fmkService: fixtures.fmkService, personId: testPersonId, primaryKey: testPrimaryKey)

        let provider1 = Provider(name: "Dr. Smith", organization: "Smith Medical")
        let provider2 = Provider(name: "Dr. Jones", organization: "City Hospital")
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
        let fixtures = makeRepositoryWithMocks()
        let otherPersonId = UUID()

        preSeedFMK(fmkService: fixtures.fmkService, personId: testPersonId, primaryKey: testPrimaryKey)
        preSeedFMK(fmkService: fixtures.fmkService, personId: otherPersonId, primaryKey: testPrimaryKey)

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
