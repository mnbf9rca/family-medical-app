import CryptoKit
import Foundation
import Testing
@testable import FamilyMedicalApp

// swiftlint:disable type_body_length

/// Tests for CustomSchemaRepository CRUD operations
struct CustomSchemaRepositoryTests {
    // MARK: - Test Person ID

    // swiftlint:disable force_unwrapping
    /// Stable UUID for test person (schemas are now per-Person)
    private static let testPersonId = UUID(uuidString: "33333333-0000-0000-0000-000000000001")!

    // MARK: - Test Field IDs

    // Stable UUIDs for consistent field identity across tests
    private static let titleFieldId = UUID(uuidString: "33333333-0001-0001-0000-000000000001")!
    private static let descriptionFieldId = UUID(uuidString: "33333333-0001-0002-0000-000000000001")!
    private static let nameFieldId = UUID(uuidString: "33333333-0001-0003-0000-000000000001")!
    private static let stringFieldId = UUID(uuidString: "33333333-0002-0001-0000-000000000001")!
    private static let intFieldId = UUID(uuidString: "33333333-0002-0002-0000-000000000001")!
    private static let doubleFieldId = UUID(uuidString: "33333333-0002-0003-0000-000000000001")!
    private static let dateFieldId = UUID(uuidString: "33333333-0002-0004-0000-000000000001")!
    private static let boolFieldId = UUID(uuidString: "33333333-0002-0005-0000-000000000001")!
    private static let stringsFieldId = UUID(uuidString: "33333333-0002-0006-0000-000000000001")!
    private static let attachmentsFieldId = UUID(uuidString: "33333333-0002-0007-0000-000000000001")!
    // swiftlint:enable force_unwrapping

    // MARK: - Test Fixtures

    struct TestFixtures {
        let repository: CustomSchemaRepository
        let coreDataStack: MockCoreDataStack
        let encryptionService: MockEncryptionService
    }

    // MARK: - Test Dependencies

    func makeRepository() -> CustomSchemaRepository {
        let stack = MockCoreDataStack()
        let encryption = MockEncryptionService()
        return CustomSchemaRepository(
            coreDataStack: stack,
            encryptionService: encryption
        )
    }

    func makeRepositoryWithMocks() -> TestFixtures {
        let stack = MockCoreDataStack()
        let encryption = MockEncryptionService()
        let repo = CustomSchemaRepository(
            coreDataStack: stack,
            encryptionService: encryption
        )
        return TestFixtures(
            repository: repo,
            coreDataStack: stack,
            encryptionService: encryption
        )
    }

    func makeTestSchema(id: String = "test-schema", version: Int = 1) throws -> RecordSchema {
        try RecordSchema(
            id: id,
            displayName: "Test Schema",
            iconSystemName: "doc.text",
            fields: [
                .builtIn(
                    id: Self.titleFieldId,
                    displayName: "Title",
                    fieldType: .string,
                    isRequired: true,
                    displayOrder: 1
                ),
                .builtIn(
                    id: Self.descriptionFieldId,
                    displayName: "Description",
                    fieldType: .string,
                    isRequired: false,
                    displayOrder: 2,
                    isMultiline: true
                )
            ],
            isBuiltIn: false,
            version: version
        )
    }

    let testPersonId = CustomSchemaRepositoryTests.testPersonId
    let testFamilyMemberKey = SymmetricKey(size: .bits256)

    // MARK: - Save Tests

    @Test
    func save_newSchema_storesSuccessfully() async throws {
        let repo = makeRepository()
        let schema = try makeTestSchema()

        try await repo.save(schema, forPerson: testPersonId, familyMemberKey: testFamilyMemberKey)

        let fetched = try await repo.fetch(
            schemaId: schema.id,
            forPerson: testPersonId,
            familyMemberKey: testFamilyMemberKey
        )
        #expect(fetched != nil)
        #expect(fetched?.id == schema.id)
        #expect(fetched?.displayName == schema.displayName)
        #expect(fetched?.version == schema.version)
    }

    @Test
    func save_newSchema_encryptsData() async throws {
        let fixtures = makeRepositoryWithMocks()
        let repo = fixtures.repository
        let encryption = fixtures.encryptionService
        let schema = try makeTestSchema()

        try await repo.save(schema, forPerson: testPersonId, familyMemberKey: testFamilyMemberKey)

        #expect(encryption.encryptCalls.count == 1)
    }

    @Test
    func save_builtInSchemaId_allowedForPerPersonStorage() async throws {
        // Per-Person storage allows built-in schema IDs since each Person gets their own copy
        let repo = makeRepository()

        let schema = try RecordSchema(
            id: "vaccine",
            displayName: "Vaccine Records",
            iconSystemName: "syringe",
            fields: [
                .builtIn(id: Self.nameFieldId, displayName: "Name", fieldType: .string)
            ],
            isBuiltIn: true,
            version: 1
        )

        // Should not throw - built-in IDs are now allowed for per-Person storage
        try await repo.save(schema, forPerson: testPersonId, familyMemberKey: testFamilyMemberKey)

        let fetched = try await repo.fetch(
            schemaId: "vaccine",
            forPerson: testPersonId,
            familyMemberKey: testFamilyMemberKey
        )
        #expect(fetched != nil)
        #expect(fetched?.id == "vaccine")
    }

    @Test
    func save_sameSchemaIdDifferentPersons_storedSeparately() async throws {
        let person2Id = try #require(UUID(uuidString: "33333333-0000-0000-0000-000000000002"))
        let repo = makeRepository()
        let schema1 = try makeTestSchema(id: "shared-schema", version: 1)

        // Different display name for person 2's version
        let schema2 = try RecordSchema(
            id: "shared-schema",
            displayName: "Person 2's Schema",
            iconSystemName: "doc.text",
            fields: [
                .builtIn(id: Self.titleFieldId, displayName: "Title", fieldType: .string)
            ],
            isBuiltIn: false,
            version: 1
        )

        try await repo.save(schema1, forPerson: testPersonId, familyMemberKey: testFamilyMemberKey)
        try await repo.save(schema2, forPerson: person2Id, familyMemberKey: testFamilyMemberKey)

        let fetched1 = try await repo.fetch(
            schemaId: "shared-schema",
            forPerson: testPersonId,
            familyMemberKey: testFamilyMemberKey
        )
        let fetched2 = try await repo.fetch(
            schemaId: "shared-schema",
            forPerson: person2Id,
            familyMemberKey: testFamilyMemberKey
        )

        #expect(fetched1?.displayName == "Test Schema")
        #expect(fetched2?.displayName == "Person 2's Schema")
    }

    @Test
    func save_existingSchema_updatesSuccessfully() async throws {
        let repo = makeRepository()
        var schema = try makeTestSchema(version: 1)

        try await repo.save(schema, forPerson: testPersonId, familyMemberKey: testFamilyMemberKey)

        schema = try RecordSchema(
            id: schema.id,
            displayName: "Updated Schema Name",
            iconSystemName: schema.iconSystemName,
            fields: schema.fields,
            isBuiltIn: false,
            version: 2
        )
        try await repo.save(schema, forPerson: testPersonId, familyMemberKey: testFamilyMemberKey)

        let fetched = try await repo.fetch(
            schemaId: schema.id,
            forPerson: testPersonId,
            familyMemberKey: testFamilyMemberKey
        )
        #expect(fetched?.displayName == "Updated Schema Name")
        #expect(fetched?.version == 2)
    }

    @Test
    func save_encryptionFails_throwsError() async throws {
        let fixtures = makeRepositoryWithMocks()
        let repo = fixtures.repository
        let encryption = fixtures.encryptionService
        let schema = try makeTestSchema()

        encryption.shouldFailEncryption = true

        await #expect(throws: RepositoryError.self) {
            try await repo.save(schema, forPerson: testPersonId, familyMemberKey: testFamilyMemberKey)
        }
    }

    // MARK: - Fetch Tests

    @Test
    func fetch_existingSchema_returnsDecryptedSchema() async throws {
        let repo = makeRepository()
        let schema = try makeTestSchema()

        try await repo.save(schema, forPerson: testPersonId, familyMemberKey: testFamilyMemberKey)
        let fetched = try await repo.fetch(
            schemaId: schema.id,
            forPerson: testPersonId,
            familyMemberKey: testFamilyMemberKey
        )

        #expect(fetched != nil)
        #expect(fetched?.id == schema.id)
        #expect(fetched?.displayName == schema.displayName)
        #expect(fetched?.iconSystemName == schema.iconSystemName)
        #expect(fetched?.fields.count == schema.fields.count)
        #expect(fetched?.version == schema.version)
    }

    @Test
    func fetch_nonExistentSchema_returnsNil() async throws {
        let repo = makeRepository()

        let result = try await repo.fetch(
            schemaId: "non-existent",
            forPerson: testPersonId,
            familyMemberKey: testFamilyMemberKey
        )

        #expect(result == nil)
    }

    @Test
    func fetch_wrongPerson_returnsNil() async throws {
        let person2Id = try #require(UUID(uuidString: "33333333-0000-0000-0000-000000000002"))
        let repo = makeRepository()
        let schema = try makeTestSchema()

        try await repo.save(schema, forPerson: testPersonId, familyMemberKey: testFamilyMemberKey)

        // Try to fetch with wrong person - should return nil
        let result = try await repo.fetch(
            schemaId: schema.id,
            forPerson: person2Id,
            familyMemberKey: testFamilyMemberKey
        )

        #expect(result == nil)
    }

    @Test
    func fetch_decryptionFails_throwsError() async throws {
        let fixtures = makeRepositoryWithMocks()
        let repo = fixtures.repository
        let encryption = fixtures.encryptionService
        let schema = try makeTestSchema()

        try await repo.save(schema, forPerson: testPersonId, familyMemberKey: testFamilyMemberKey)

        encryption.shouldFailDecryption = true

        await #expect(throws: RepositoryError.self) {
            _ = try await repo.fetch(
                schemaId: schema.id,
                forPerson: testPersonId,
                familyMemberKey: testFamilyMemberKey
            )
        }
    }

    // MARK: - FetchAll Tests

    @Test
    func fetchAll_multipleSchemas_returnsAll() async throws {
        let repo = makeRepository()
        let schema1 = try makeTestSchema(id: "schema-a")
        let schema2 = try makeTestSchema(id: "schema-b")
        let schema3 = try makeTestSchema(id: "schema-c")

        try await repo.save(schema1, forPerson: testPersonId, familyMemberKey: testFamilyMemberKey)
        try await repo.save(schema2, forPerson: testPersonId, familyMemberKey: testFamilyMemberKey)
        try await repo.save(schema3, forPerson: testPersonId, familyMemberKey: testFamilyMemberKey)

        let all = try await repo.fetchAll(forPerson: testPersonId, familyMemberKey: testFamilyMemberKey)

        #expect(all.count == 3)
        #expect(all.contains { $0.id == schema1.id })
        #expect(all.contains { $0.id == schema2.id })
        #expect(all.contains { $0.id == schema3.id })
    }

    @Test
    func fetchAll_onlyReturnsForSpecifiedPerson() async throws {
        let person2Id = try #require(UUID(uuidString: "33333333-0000-0000-0000-000000000002"))
        let repo = makeRepository()
        let schema1 = try makeTestSchema(id: "schema-a")
        let schema2 = try makeTestSchema(id: "schema-b")

        try await repo.save(schema1, forPerson: testPersonId, familyMemberKey: testFamilyMemberKey)
        try await repo.save(schema2, forPerson: person2Id, familyMemberKey: testFamilyMemberKey)

        let person1Schemas = try await repo.fetchAll(
            forPerson: testPersonId,
            familyMemberKey: testFamilyMemberKey
        )
        let person2Schemas = try await repo.fetchAll(
            forPerson: person2Id,
            familyMemberKey: testFamilyMemberKey
        )

        #expect(person1Schemas.count == 1)
        #expect(person1Schemas.first?.id == "schema-a")
        #expect(person2Schemas.count == 1)
        #expect(person2Schemas.first?.id == "schema-b")
    }

    @Test
    func fetchAll_empty_returnsEmptyArray() async throws {
        let repo = makeRepository()

        let all = try await repo.fetchAll(forPerson: testPersonId, familyMemberKey: testFamilyMemberKey)

        #expect(all.isEmpty)
    }

    @Test
    func fetchAll_decryptionFails_throwsError() async throws {
        let fixtures = makeRepositoryWithMocks()
        let repo = fixtures.repository
        let encryption = fixtures.encryptionService
        let schema = try makeTestSchema()

        try await repo.save(schema, forPerson: testPersonId, familyMemberKey: testFamilyMemberKey)

        encryption.shouldFailDecryption = true

        await #expect(throws: RepositoryError.self) {
            _ = try await repo.fetchAll(forPerson: testPersonId, familyMemberKey: testFamilyMemberKey)
        }
    }

    // MARK: - Delete Tests

    @Test
    func delete_existingSchema_removes() async throws {
        let repo = makeRepository()
        let schema = try makeTestSchema()

        try await repo.save(schema, forPerson: testPersonId, familyMemberKey: testFamilyMemberKey)
        #expect(try await repo.exists(schemaId: schema.id, forPerson: testPersonId))

        try await repo.delete(schemaId: schema.id, forPerson: testPersonId)

        let exists = try await repo.exists(schemaId: schema.id, forPerson: testPersonId)
        #expect(!exists)
    }

    @Test
    func delete_onlyDeletesForSpecifiedPerson() async throws {
        let person2Id = try #require(UUID(uuidString: "33333333-0000-0000-0000-000000000002"))
        let repo = makeRepository()
        let schema = try makeTestSchema(id: "shared-schema")

        // Save same schema ID for both persons
        try await repo.save(schema, forPerson: testPersonId, familyMemberKey: testFamilyMemberKey)
        try await repo.save(schema, forPerson: person2Id, familyMemberKey: testFamilyMemberKey)

        // Delete only for person 1
        try await repo.delete(schemaId: schema.id, forPerson: testPersonId)

        // Person 1 should no longer have it
        let exists1 = try await repo.exists(schemaId: schema.id, forPerson: testPersonId)
        #expect(!exists1)

        // Person 2 should still have it
        let exists2 = try await repo.exists(schemaId: schema.id, forPerson: person2Id)
        #expect(exists2)
    }

    @Test
    func delete_nonExistentSchema_throwsError() async throws {
        let repo = makeRepository()

        await #expect(throws: RepositoryError.customSchemaNotFound("non-existent")) {
            try await repo.delete(schemaId: "non-existent", forPerson: testPersonId)
        }
    }

    // MARK: - Exists Tests

    @Test
    func exists_existingSchema_returnsTrue() async throws {
        let repo = makeRepository()
        let schema = try makeTestSchema()

        try await repo.save(schema, forPerson: testPersonId, familyMemberKey: testFamilyMemberKey)

        let exists = try await repo.exists(schemaId: schema.id, forPerson: testPersonId)
        #expect(exists)
    }

    @Test
    func exists_nonExistentSchema_returnsFalse() async throws {
        let repo = makeRepository()

        let exists = try await repo.exists(schemaId: "non-existent", forPerson: testPersonId)
        #expect(!exists)
    }

    @Test
    func exists_wrongPerson_returnsFalse() async throws {
        let person2Id = try #require(UUID(uuidString: "33333333-0000-0000-0000-000000000002"))
        let repo = makeRepository()
        let schema = try makeTestSchema()

        try await repo.save(schema, forPerson: testPersonId, familyMemberKey: testFamilyMemberKey)

        let exists = try await repo.exists(schemaId: schema.id, forPerson: person2Id)
        #expect(!exists)
    }

    // MARK: - Encryption Verification Tests

    @Test
    func save_dataIsEncryptedAtRest() async throws {
        let fixtures = makeRepositoryWithMocks()
        let repo = fixtures.repository
        let encryption = fixtures.encryptionService
        let schema = try makeTestSchema()

        try await repo.save(schema, forPerson: testPersonId, familyMemberKey: testFamilyMemberKey)

        #expect(encryption.encryptCalls.count == 1)
        let encryptedData = encryption.encryptCalls.first?.data
        #expect(encryptedData != nil)

        if let data = encryptedData {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let decoded = try decoder.decode(RecordSchema.self, from: data)
            #expect(decoded.id == schema.id)
            #expect(decoded.displayName == schema.displayName)
        }
    }

    @Test
    func fetch_dataIsDecrypted() async throws {
        let fixtures = makeRepositoryWithMocks()
        let repo = fixtures.repository
        let encryption = fixtures.encryptionService
        let schema = try makeTestSchema()

        try await repo.save(schema, forPerson: testPersonId, familyMemberKey: testFamilyMemberKey)
        let callsAfterSave = encryption.decryptCalls.count

        _ = try await repo.fetch(
            schemaId: schema.id,
            forPerson: testPersonId,
            familyMemberKey: testFamilyMemberKey
        )

        #expect(encryption.decryptCalls.count == callsAfterSave + 1)
    }

    // MARK: - Multiple Field Type Tests

    @Test
    func save_schemaWithAllFieldTypes_succeeds() async throws {
        let repo = makeRepository()
        let schema = try RecordSchema(
            id: "all-types-schema",
            displayName: "All Types Schema",
            iconSystemName: "list.bullet",
            fields: [
                .builtIn(id: Self.stringFieldId, displayName: "String", fieldType: .string, displayOrder: 1),
                .builtIn(id: Self.intFieldId, displayName: "Integer", fieldType: .int, displayOrder: 2),
                .builtIn(id: Self.doubleFieldId, displayName: "Decimal", fieldType: .double, displayOrder: 3),
                .builtIn(id: Self.dateFieldId, displayName: "Date", fieldType: .date, displayOrder: 4),
                .builtIn(id: Self.boolFieldId, displayName: "Boolean", fieldType: .bool, displayOrder: 5),
                .builtIn(id: Self.stringsFieldId, displayName: "Tags", fieldType: .stringArray, displayOrder: 6),
                .builtIn(
                    id: Self.attachmentsFieldId,
                    displayName: "Attachments",
                    fieldType: .attachmentIds,
                    displayOrder: 7
                )
            ],
            isBuiltIn: false,
            version: 1
        )

        try await repo.save(schema, forPerson: testPersonId, familyMemberKey: testFamilyMemberKey)

        let fetched = try await repo.fetch(
            schemaId: schema.id,
            forPerson: testPersonId,
            familyMemberKey: testFamilyMemberKey
        )
        #expect(fetched?.fields.count == 7)
        #expect(fetched?.fields[0].fieldType == .string)
        #expect(fetched?.fields[1].fieldType == .int)
        #expect(fetched?.fields[2].fieldType == .double)
        #expect(fetched?.fields[3].fieldType == .date)
        #expect(fetched?.fields[4].fieldType == .bool)
        #expect(fetched?.fields[5].fieldType == .stringArray)
        #expect(fetched?.fields[6].fieldType == .attachmentIds)
    }
}

// swiftlint:enable type_body_length
