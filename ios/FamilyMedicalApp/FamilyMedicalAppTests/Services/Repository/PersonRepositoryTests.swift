import CryptoKit
import Foundation
import Testing
@testable import FamilyMedicalApp

struct PersonRepositoryTests {
    // MARK: - Test Fixtures

    struct TestFixtures {
        let repository: PersonRepository
        let coreDataStack: MockCoreDataStack
        let encryptionService: MockEncryptionService
        let fmkService: MockFamilyMemberKeyService
    }

    // MARK: - Test Dependencies

    func makeRepository() -> PersonRepository {
        let stack = MockCoreDataStack()
        let encryption = MockEncryptionService()
        let fmkService = MockFamilyMemberKeyService()
        return PersonRepository(
            coreDataStack: stack,
            encryptionService: encryption,
            fmkService: fmkService
        )
    }

    func makeRepositoryWithMocks() -> TestFixtures {
        let stack = MockCoreDataStack()
        let encryption = MockEncryptionService()
        let fmkService = MockFamilyMemberKeyService()
        let repo = PersonRepository(
            coreDataStack: stack,
            encryptionService: encryption,
            fmkService: fmkService
        )
        return TestFixtures(
            repository: repo,
            coreDataStack: stack,
            encryptionService: encryption,
            fmkService: fmkService
        )
    }

    func makeTestPerson() throws -> Person {
        try PersonTestHelper.makeTestPerson(
            name: "Alice Johnson",
            dateOfBirth: Date(timeIntervalSince1970: 0),
            labels: ["child", "dependent"],
            notes: "Test notes"
        )
    }

    let testPrimaryKey = SymmetricKey(size: .bits256)

    // MARK: - Save Tests

    @Test
    func save_newPerson_createsFMK() async throws {
        let fixtures = makeRepositoryWithMocks()
        let fmkService = fixtures.fmkService
        let repo = fixtures.repository
        let person = try makeTestPerson()

        try await repo.save(person, primaryKey: testPrimaryKey)

        // FMK should be generated and stored
        #expect(fmkService.generateCalls == 1)
        #expect(fmkService.storedFMKs[person.id.uuidString] != nil)
    }

    @Test
    func save_newPerson_encryptsData() async throws {
        let fixtures = makeRepositoryWithMocks()
        let repo = fixtures.repository
        let encryption = fixtures.encryptionService
        let person = try makeTestPerson()

        try await repo.save(person, primaryKey: testPrimaryKey)

        // Encryption should be called once
        #expect(encryption.encryptCalls.count == 1)
    }

    @Test
    func save_newPerson_storesInCoreData() async throws {
        let repo = makeRepository()
        let person = try makeTestPerson()

        try await repo.save(person, primaryKey: testPrimaryKey)

        // Verify entity was saved
        let result = try await repo.fetch(id: person.id, primaryKey: testPrimaryKey)
        #expect(result != nil)
    }

    @Test
    func save_existingPerson_reusesFMK() async throws {
        let fixtures = makeRepositoryWithMocks()
        let fmkService = fixtures.fmkService
        let repo = fixtures.repository
        var person = try makeTestPerson()

        // Save first time
        try await repo.save(person, primaryKey: testPrimaryKey)
        let initialGenerateCalls = fmkService.generateCalls

        // Update and save again
        person.notes = "Updated notes"
        try await repo.save(person, primaryKey: testPrimaryKey)

        // Should not generate new FMK
        #expect(fmkService.generateCalls == initialGenerateCalls)
    }

    @Test
    func save_encryptionFails_throwsError() async throws {
        let fixtures = makeRepositoryWithMocks()
        let repo = fixtures.repository
        let encryption = fixtures.encryptionService
        let person = try makeTestPerson()

        encryption.shouldFailEncryption = true

        await #expect(throws: RepositoryError.self) {
            try await repo.save(person, primaryKey: testPrimaryKey)
        }
    }

    @Test
    func save_fmkStorageFails_throwsError() async throws {
        let fixtures = makeRepositoryWithMocks()
        let fmkService = fixtures.fmkService
        let repo = fixtures.repository
        let person = try makeTestPerson()

        fmkService.shouldFailStore = true

        await #expect(throws: RepositoryError.self) {
            try await repo.save(person, primaryKey: testPrimaryKey)
        }
    }

    // MARK: - Fetch Tests

    @Test
    func fetch_existingPerson_returnsDecryptedPerson() async throws {
        let repo = makeRepository()
        let person = try makeTestPerson()

        try await repo.save(person, primaryKey: testPrimaryKey)
        let fetched = try await repo.fetch(id: person.id, primaryKey: testPrimaryKey)

        #expect(fetched != nil)
        #expect(fetched?.id == person.id)
        #expect(fetched?.name == person.name)
        #expect(fetched?.dateOfBirth == person.dateOfBirth)
        #expect(fetched?.labels == person.labels)
        #expect(fetched?.notes == person.notes)
    }

    @Test
    func fetch_nonExistentPerson_returnsNil() async throws {
        let repo = makeRepository()

        let result = try await repo.fetch(id: UUID(), primaryKey: testPrimaryKey)

        #expect(result == nil)
    }

    @Test
    func fetch_decryptionFails_throwsError() async throws {
        let fixtures = makeRepositoryWithMocks()
        let repo = fixtures.repository
        let encryption = fixtures.encryptionService
        let person = try makeTestPerson()

        try await repo.save(person, primaryKey: testPrimaryKey)

        // Make decryption fail
        encryption.shouldFailDecryption = true

        await #expect(throws: RepositoryError.self) {
            _ = try await repo.fetch(id: person.id, primaryKey: testPrimaryKey)
        }
    }

    @Test
    func fetch_fmkNotFound_throwsError() async throws {
        let fixtures = makeRepositoryWithMocks()
        let fmkService = fixtures.fmkService
        let repo = fixtures.repository
        let person = try makeTestPerson()

        // Save normally
        try await repo.save(person, primaryKey: testPrimaryKey)

        // Remove the FMK to simulate missing key
        fmkService.storedFMKs.removeAll()

        await #expect(throws: RepositoryError.self) {
            _ = try await repo.fetch(id: person.id, primaryKey: testPrimaryKey)
        }
    }

    // MARK: - FetchAll Tests

    @Test
    func fetchAll_multiplePersons_returnsAll() async throws {
        let repo = makeRepository()
        let person1 = try Person(id: UUID(), name: "Alice", labels: [])
        let person2 = try Person(id: UUID(), name: "Bob", labels: [])
        let person3 = try Person(id: UUID(), name: "Charlie", labels: [])

        try await repo.save(person1, primaryKey: testPrimaryKey)
        try await repo.save(person2, primaryKey: testPrimaryKey)
        try await repo.save(person3, primaryKey: testPrimaryKey)

        let all = try await repo.fetchAll(primaryKey: testPrimaryKey)

        #expect(all.count == 3)
        #expect(all.contains { $0.id == person1.id })
        #expect(all.contains { $0.id == person2.id })
        #expect(all.contains { $0.id == person3.id })
    }

    @Test
    func fetchAll_empty_returnsEmptyArray() async throws {
        let repo = makeRepository()

        let all = try await repo.fetchAll(primaryKey: testPrimaryKey)

        #expect(all.isEmpty)
    }

    @Test
    func fetchAll_decryptionFails_throwsError() async throws {
        let fixtures = makeRepositoryWithMocks()
        let repo = fixtures.repository
        let encryption = fixtures.encryptionService
        let person = try makeTestPerson()

        try await repo.save(person, primaryKey: testPrimaryKey)

        // Make decryption fail
        encryption.shouldFailDecryption = true

        await #expect(throws: RepositoryError.self) {
            _ = try await repo.fetchAll(primaryKey: testPrimaryKey)
        }
    }

    // MARK: - Delete Tests

    @Test
    func delete_existingPerson_removes() async throws {
        let repo = makeRepository()
        let person = try makeTestPerson()

        try await repo.save(person, primaryKey: testPrimaryKey)
        #expect(try await repo.exists(id: person.id))

        try await repo.delete(id: person.id)

        let exists = try await repo.exists(id: person.id)
        #expect(!exists)
    }

    @Test
    func delete_nonExistentPerson_throwsError() async throws {
        let repo = makeRepository()

        await #expect(throws: RepositoryError.self) {
            try await repo.delete(id: UUID())
        }
    }

    // MARK: - Exists Tests

    @Test
    func exists_existingPerson_returnsTrue() async throws {
        let repo = makeRepository()
        let person = try makeTestPerson()

        try await repo.save(person, primaryKey: testPrimaryKey)

        let exists = try await repo.exists(id: person.id)
        #expect(exists)
    }

    @Test
    func exists_nonExistentPerson_returnsFalse() async throws {
        let repo = makeRepository()

        let exists = try await repo.exists(id: UUID())
        #expect(!exists)
    }
}
