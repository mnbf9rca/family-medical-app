import CryptoKit
import Foundation
import Testing
@testable import FamilyMedicalApp

/// Tests for SchemaService functionality
struct SchemaServiceTests {
    // MARK: - Test Person ID

    // swiftlint:disable force_unwrapping
    private static let testPersonId = UUID(uuidString: "BBBBBBBB-0000-0000-0000-000000000001")!
    private static let testFieldId = UUID(uuidString: "BBBBBBBB-0001-0001-0000-000000000001")!
    // swiftlint:enable force_unwrapping

    // MARK: - Test Dependencies

    func makeService() -> (SchemaService, MockCustomSchemaRepository) {
        let repo = MockCustomSchemaRepository()
        let service = SchemaService(schemaRepository: repo)
        return (service, repo)
    }

    func makeCustomSchema(id: String = "custom-schema") throws -> RecordSchema {
        try RecordSchema(
            id: id,
            displayName: "Custom Schema",
            iconSystemName: "star",
            fields: [
                .builtIn(id: Self.testFieldId, displayName: "Field", fieldType: .string)
            ],
            isBuiltIn: false,
            version: 1
        )
    }

    let testPersonId = SchemaServiceTests.testPersonId
    let testFamilyMemberKey = SymmetricKey(size: .bits256)

    // MARK: - Schema Fetch Tests

    @Test
    func schema_storedSchema_returnsStored() async throws {
        let (service, repo) = makeService()
        let customSchema = try makeCustomSchema()
        repo.addSchema(customSchema, forPerson: testPersonId)

        let result = try await service.schema(
            forId: customSchema.id,
            personId: testPersonId,
            familyMemberKey: testFamilyMemberKey
        )

        #expect(result?.id == customSchema.id)
        #expect(result?.displayName == "Custom Schema")
    }

    @Test
    func schema_builtInSchemaNotStored_fallsBackToHardcoded() async throws {
        let (service, _) = makeService()

        let result = try await service.schema(
            forId: BuiltInSchemaType.vaccine.rawValue,
            personId: testPersonId,
            familyMemberKey: testFamilyMemberKey
        )

        #expect(result?.id == BuiltInSchemaType.vaccine.rawValue)
        #expect(result?.isBuiltIn == true)
    }

    @Test
    func schema_unknownSchemaId_returnsNil() async throws {
        let (service, _) = makeService()

        let result = try await service.schema(
            forId: "unknown-schema",
            personId: testPersonId,
            familyMemberKey: testFamilyMemberKey
        )

        #expect(result == nil)
    }

    @Test
    func schema_repositoryFailure_throwsError() async throws {
        let (service, repo) = makeService()
        repo.shouldFailFetch = true

        await #expect(throws: RepositoryError.self) {
            _ = try await service.schema(
                forId: "test",
                personId: testPersonId,
                familyMemberKey: testFamilyMemberKey
            )
        }
    }

    // MARK: - AllSchemas Tests

    @Test
    func allSchemas_withStoredSchemas_returnsStored() async throws {
        let (service, repo) = makeService()
        let customSchema = try makeCustomSchema()
        repo.addSchema(customSchema, forPerson: testPersonId)

        let result = try await service.allSchemas(
            forPerson: testPersonId,
            familyMemberKey: testFamilyMemberKey
        )

        #expect(result.count == 1)
        #expect(result.first?.id == customSchema.id)
    }

    @Test
    func allSchemas_noStoredSchemas_fallsBackToBuiltIn() async throws {
        let (service, _) = makeService()

        let result = try await service.allSchemas(
            forPerson: testPersonId,
            familyMemberKey: testFamilyMemberKey
        )

        #expect(result.count == BuiltInSchemaType.allCases.count)

        // Verify all built-in schemas are present
        for builtInType in BuiltInSchemaType.allCases {
            let found = result.first { $0.id == builtInType.rawValue }
            #expect(found != nil, "Missing schema: \(builtInType.rawValue)")
        }
    }

    @Test
    func allSchemas_repositoryFailure_throwsError() async throws {
        let (service, repo) = makeService()
        repo.shouldFailFetchAll = true

        await #expect(throws: RepositoryError.self) {
            _ = try await service.allSchemas(
                forPerson: testPersonId,
                familyMemberKey: testFamilyMemberKey
            )
        }
    }

    // MARK: - BuiltInSchemas Tests

    @Test
    func builtInSchemas_withMixedSchemas_filtersToBuiltInOnly() async throws {
        let (service, repo) = makeService()

        // Add built-in schemas
        for builtInType in BuiltInSchemaType.allCases {
            repo.addSchema(builtInType.schema, forPerson: testPersonId)
        }

        // Add custom schema
        let customSchema = try makeCustomSchema()
        repo.addSchema(customSchema, forPerson: testPersonId)

        let result = try await service.builtInSchemas(
            forPerson: testPersonId,
            familyMemberKey: testFamilyMemberKey
        )

        // Should only return built-in schemas
        #expect(result.count == BuiltInSchemaType.allCases.count)
        #expect(!result.contains { $0.id == customSchema.id })
    }

    @Test
    func builtInSchemas_noStoredSchemas_fallsBackToBuiltIn() async throws {
        let (service, _) = makeService()

        let result = try await service.builtInSchemas(
            forPerson: testPersonId,
            familyMemberKey: testFamilyMemberKey
        )

        #expect(result.count == BuiltInSchemaType.allCases.count)
    }

    // MARK: - Save Tests

    @Test
    func save_schema_delegatesToRepository() async throws {
        let (service, repo) = makeService()
        let customSchema = try makeCustomSchema()

        try await service.save(
            customSchema,
            forPerson: testPersonId,
            familyMemberKey: testFamilyMemberKey
        )

        #expect(repo.saveCallCount == 1)
        #expect(repo.lastSavedSchema?.id == customSchema.id)
    }

    @Test
    func save_repositoryFailure_throwsError() async throws {
        let (service, repo) = makeService()
        let customSchema = try makeCustomSchema()
        repo.shouldFailSave = true

        await #expect(throws: RepositoryError.self) {
            try await service.save(
                customSchema,
                forPerson: testPersonId,
                familyMemberKey: testFamilyMemberKey
            )
        }
    }

    // MARK: - Multiple Persons Tests

    @Test
    func schema_differentPersons_returnsIndependentSchemas() async throws {
        // swiftlint:disable:next force_unwrapping
        let person2Id = try #require(UUID(uuidString: "BBBBBBBB-0000-0000-0000-000000000002"))
        let (service, repo) = makeService()

        // Add different schemas for each person
        let schema1 = try RecordSchema(
            id: "shared-id",
            displayName: "Person 1 Schema",
            iconSystemName: "star",
            fields: [.builtIn(id: Self.testFieldId, displayName: "Field", fieldType: .string)],
            isBuiltIn: false,
            version: 1
        )
        let schema2 = try RecordSchema(
            id: "shared-id",
            displayName: "Person 2 Schema",
            iconSystemName: "heart",
            fields: [.builtIn(id: Self.testFieldId, displayName: "Field", fieldType: .string)],
            isBuiltIn: false,
            version: 1
        )

        repo.addSchema(schema1, forPerson: testPersonId)
        repo.addSchema(schema2, forPerson: person2Id)

        let result1 = try await service.schema(
            forId: "shared-id",
            personId: testPersonId,
            familyMemberKey: testFamilyMemberKey
        )
        let result2 = try await service.schema(
            forId: "shared-id",
            personId: person2Id,
            familyMemberKey: testFamilyMemberKey
        )

        #expect(result1?.displayName == "Person 1 Schema")
        #expect(result2?.displayName == "Person 2 Schema")
    }
}
