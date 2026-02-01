import CryptoKit
import Foundation
import Testing
@testable import FamilyMedicalApp

/// Tests for SchemaSeeder functionality
struct SchemaSeederTests {
    // MARK: - Test Person ID

    // swiftlint:disable:next force_unwrapping
    private static let testPersonId = UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000001")!

    // MARK: - Test Dependencies

    func makeSeeder() -> (SchemaSeeder, MockCustomSchemaRepository) {
        let repo = MockCustomSchemaRepository()
        let seeder = SchemaSeeder(schemaRepository: repo)
        return (seeder, repo)
    }

    let testPersonId = SchemaSeederTests.testPersonId
    let testFamilyMemberKey = SymmetricKey(size: .bits256)

    // MARK: - Seed Tests

    @Test
    func seedBuiltInSchemas_createsAllBuiltInSchemas() async throws {
        let (seeder, repo) = makeSeeder()

        try await seeder.seedBuiltInSchemas(
            forPerson: testPersonId,
            familyMemberKey: testFamilyMemberKey
        )

        // Verify all built-in schemas were saved
        let schemas = repo.getAllSchemas(forPerson: testPersonId)
        #expect(schemas.count == BuiltInSchemaType.allCases.count)

        // Verify each built-in schema exists
        for builtInType in BuiltInSchemaType.allCases {
            let found = schemas.first { $0.id == builtInType.rawValue }
            #expect(found != nil, "Missing schema: \(builtInType.rawValue)")
        }
    }

    @Test
    func seedBuiltInSchemas_callsSaveCorrectNumberOfTimes() async throws {
        let (seeder, repo) = makeSeeder()

        try await seeder.seedBuiltInSchemas(
            forPerson: testPersonId,
            familyMemberKey: testFamilyMemberKey
        )

        #expect(repo.saveCallCount == BuiltInSchemaType.allCases.count)
    }

    @Test
    func seedBuiltInSchemas_usesCorrectPersonId() async throws {
        let (seeder, repo) = makeSeeder()

        try await seeder.seedBuiltInSchemas(
            forPerson: testPersonId,
            familyMemberKey: testFamilyMemberKey
        )

        #expect(repo.lastSavedPersonId == testPersonId)
    }

    @Test
    func seedBuiltInSchemas_repositoryFailure_throwsError() async throws {
        let (seeder, repo) = makeSeeder()
        repo.shouldFailSave = true

        await #expect(throws: RepositoryError.self) {
            try await seeder.seedBuiltInSchemas(
                forPerson: testPersonId,
                familyMemberKey: testFamilyMemberKey
            )
        }
    }

    // MARK: - HasSchemas Tests

    @Test
    func hasSchemas_afterSeeding_returnsTrue() async throws {
        let (seeder, _) = makeSeeder()

        try await seeder.seedBuiltInSchemas(
            forPerson: testPersonId,
            familyMemberKey: testFamilyMemberKey
        )

        let result = try await seeder.hasSchemas(
            forPerson: testPersonId,
            familyMemberKey: testFamilyMemberKey
        )

        #expect(result == true)
    }

    @Test
    func hasSchemas_beforeSeeding_returnsFalse() async throws {
        let (seeder, _) = makeSeeder()

        let result = try await seeder.hasSchemas(
            forPerson: testPersonId,
            familyMemberKey: testFamilyMemberKey
        )

        #expect(result == false)
    }

    @Test
    func hasSchemas_repositoryFailure_throwsError() async throws {
        let (seeder, repo) = makeSeeder()
        repo.shouldFailFetchAll = true

        await #expect(throws: RepositoryError.self) {
            _ = try await seeder.hasSchemas(
                forPerson: testPersonId,
                familyMemberKey: testFamilyMemberKey
            )
        }
    }

    // MARK: - Multiple Persons Tests

    @Test
    func seedBuiltInSchemas_multiplePersons_seedsIndependently() async throws {
        let person2Id = try #require(UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000002"))
        let (seeder, repo) = makeSeeder()

        try await seeder.seedBuiltInSchemas(
            forPerson: testPersonId,
            familyMemberKey: testFamilyMemberKey
        )
        try await seeder.seedBuiltInSchemas(
            forPerson: person2Id,
            familyMemberKey: testFamilyMemberKey
        )

        let person1Schemas = repo.getAllSchemas(forPerson: testPersonId)
        let person2Schemas = repo.getAllSchemas(forPerson: person2Id)

        #expect(person1Schemas.count == BuiltInSchemaType.allCases.count)
        #expect(person2Schemas.count == BuiltInSchemaType.allCases.count)
    }
}
