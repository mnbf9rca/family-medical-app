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

func preSeedProviderFMK(fmkService: MockFamilyMemberKeyService, personId: UUID) {
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
        preSeedProviderFMK(fmkService: fixtures.fmkService, personId: testPersonId)

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
        preSeedProviderFMK(fmkService: fixtures.fmkService, personId: testPersonId)

        let provider = makeTestProvider()
        try await fixtures.repository.save(provider, personId: testPersonId, primaryKey: testPrimaryKey)

        #expect(fixtures.encryptionService.encryptCalls.count == 1)
    }

    @Test("Save existing provider updates and re-encrypts")
    func save_existingProvider_updatesRecord() async throws {
        let fixtures = makeProviderRepositoryWithMocks()
        preSeedProviderFMK(fmkService: fixtures.fmkService, personId: testPersonId)

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
        #expect(fixtures.encryptionService.encryptCalls.count == 2)
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
        preSeedProviderFMK(fmkService: fixtures.fmkService, personId: testPersonId)
        fixtures.encryptionService.shouldFailEncryption = true

        let provider = makeTestProvider()
        await #expect(throws: RepositoryError.self) {
            try await fixtures.repository.save(provider, personId: testPersonId, primaryKey: testPrimaryKey)
        }
    }

    @Test("Fetch existing provider returns decrypted provider")
    func fetch_existingProvider_returnsDecryptedProvider() async throws {
        let fixtures = makeProviderRepositoryWithMocks()
        preSeedProviderFMK(fmkService: fixtures.fmkService, personId: testPersonId)

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
        preSeedProviderFMK(fmkService: fixtures.fmkService, personId: testPersonId)

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
        preSeedProviderFMK(fmkService: fixtures.fmkService, personId: testPersonId)

        let provider = makeTestProvider()
        try await fixtures.repository.save(provider, personId: testPersonId, primaryKey: testPrimaryKey)

        let otherPersonId = UUID()
        preSeedProviderFMK(fmkService: fixtures.fmkService, personId: otherPersonId)

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
        preSeedProviderFMK(fmkService: fixtures.fmkService, personId: testPersonId)

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
        preSeedProviderFMK(fmkService: fixtures.fmkService, personId: testPersonId)

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
