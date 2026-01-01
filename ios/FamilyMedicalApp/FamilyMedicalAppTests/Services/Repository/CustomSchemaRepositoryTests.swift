import CryptoKit
import Foundation
import Testing
@testable import FamilyMedicalApp

/// Tests for CustomSchemaRepository CRUD operations
struct CustomSchemaRepositoryTests {
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
                FieldDefinition(
                    id: "title",
                    displayName: "Title",
                    fieldType: .string,
                    isRequired: true,
                    displayOrder: 1
                ),
                FieldDefinition(
                    id: "description",
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

    let testPrimaryKey = SymmetricKey(size: .bits256)

    // MARK: - Save Tests

    @Test
    func save_newSchema_storesSuccessfully() async throws {
        let repo = makeRepository()
        let schema = try makeTestSchema()

        try await repo.save(schema, primaryKey: testPrimaryKey)

        let fetched = try await repo.fetch(schemaId: schema.id, primaryKey: testPrimaryKey)
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

        try await repo.save(schema, primaryKey: testPrimaryKey)

        #expect(encryption.encryptCalls.count == 1)
    }

    @Test
    func save_builtInSchemaId_throwsConflictError() async throws {
        let repo = makeRepository()

        let schema = try RecordSchema(
            id: "vaccine",
            displayName: "Custom Vaccine",
            iconSystemName: "syringe",
            fields: [
                FieldDefinition(id: "name", displayName: "Name", fieldType: .string)
            ],
            isBuiltIn: false,
            version: 1
        )

        await #expect(throws: RepositoryError.self) {
            try await repo.save(schema, primaryKey: testPrimaryKey)
        }
    }

    @Test
    func save_allBuiltInSchemaIds_throwsConflictError() async throws {
        let repo = makeRepository()

        for builtInType in BuiltInSchemaType.allCases {
            let schema = try RecordSchema(
                id: builtInType.rawValue,
                displayName: "Custom \(builtInType.displayName)",
                iconSystemName: "doc",
                fields: [
                    FieldDefinition(id: "name", displayName: "Name", fieldType: .string)
                ],
                isBuiltIn: false,
                version: 1
            )

            await #expect(throws: RepositoryError.schemaIdConflictsWithBuiltIn(builtInType.rawValue)) {
                try await repo.save(schema, primaryKey: testPrimaryKey)
            }
        }
    }

    @Test
    func save_existingSchema_updatesSuccessfully() async throws {
        let repo = makeRepository()
        var schema = try makeTestSchema(version: 1)

        try await repo.save(schema, primaryKey: testPrimaryKey)

        schema = try RecordSchema(
            id: schema.id,
            displayName: "Updated Schema Name",
            iconSystemName: schema.iconSystemName,
            fields: schema.fields,
            isBuiltIn: false,
            version: 2
        )
        try await repo.save(schema, primaryKey: testPrimaryKey)

        let fetched = try await repo.fetch(schemaId: schema.id, primaryKey: testPrimaryKey)
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
            try await repo.save(schema, primaryKey: testPrimaryKey)
        }
    }

    // MARK: - Fetch Tests

    @Test
    func fetch_existingSchema_returnsDecryptedSchema() async throws {
        let repo = makeRepository()
        let schema = try makeTestSchema()

        try await repo.save(schema, primaryKey: testPrimaryKey)
        let fetched = try await repo.fetch(schemaId: schema.id, primaryKey: testPrimaryKey)

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

        let result = try await repo.fetch(schemaId: "non-existent", primaryKey: testPrimaryKey)

        #expect(result == nil)
    }

    @Test
    func fetch_decryptionFails_throwsError() async throws {
        let fixtures = makeRepositoryWithMocks()
        let repo = fixtures.repository
        let encryption = fixtures.encryptionService
        let schema = try makeTestSchema()

        try await repo.save(schema, primaryKey: testPrimaryKey)

        encryption.shouldFailDecryption = true

        await #expect(throws: RepositoryError.self) {
            _ = try await repo.fetch(schemaId: schema.id, primaryKey: testPrimaryKey)
        }
    }

    // MARK: - FetchAll Tests

    @Test
    func fetchAll_multipleSchemas_returnsAll() async throws {
        let repo = makeRepository()
        let schema1 = try makeTestSchema(id: "schema-a")
        let schema2 = try makeTestSchema(id: "schema-b")
        let schema3 = try makeTestSchema(id: "schema-c")

        try await repo.save(schema1, primaryKey: testPrimaryKey)
        try await repo.save(schema2, primaryKey: testPrimaryKey)
        try await repo.save(schema3, primaryKey: testPrimaryKey)

        let all = try await repo.fetchAll(primaryKey: testPrimaryKey)

        #expect(all.count == 3)
        #expect(all.contains { $0.id == schema1.id })
        #expect(all.contains { $0.id == schema2.id })
        #expect(all.contains { $0.id == schema3.id })
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
        let schema = try makeTestSchema()

        try await repo.save(schema, primaryKey: testPrimaryKey)

        encryption.shouldFailDecryption = true

        await #expect(throws: RepositoryError.self) {
            _ = try await repo.fetchAll(primaryKey: testPrimaryKey)
        }
    }

    // MARK: - Delete Tests

    @Test
    func delete_existingSchema_removes() async throws {
        let repo = makeRepository()
        let schema = try makeTestSchema()

        try await repo.save(schema, primaryKey: testPrimaryKey)
        #expect(try await repo.exists(schemaId: schema.id))

        try await repo.delete(schemaId: schema.id)

        let exists = try await repo.exists(schemaId: schema.id)
        #expect(!exists)
    }

    @Test
    func delete_nonExistentSchema_throwsError() async throws {
        let repo = makeRepository()

        await #expect(throws: RepositoryError.customSchemaNotFound("non-existent")) {
            try await repo.delete(schemaId: "non-existent")
        }
    }

    // MARK: - Exists Tests

    @Test
    func exists_existingSchema_returnsTrue() async throws {
        let repo = makeRepository()
        let schema = try makeTestSchema()

        try await repo.save(schema, primaryKey: testPrimaryKey)

        let exists = try await repo.exists(schemaId: schema.id)
        #expect(exists)
    }

    @Test
    func exists_nonExistentSchema_returnsFalse() async throws {
        let repo = makeRepository()

        let exists = try await repo.exists(schemaId: "non-existent")
        #expect(!exists)
    }

    // MARK: - Encryption Verification Tests

    @Test
    func save_dataIsEncryptedAtRest() async throws {
        let fixtures = makeRepositoryWithMocks()
        let repo = fixtures.repository
        let encryption = fixtures.encryptionService
        let schema = try makeTestSchema()

        try await repo.save(schema, primaryKey: testPrimaryKey)

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

        try await repo.save(schema, primaryKey: testPrimaryKey)
        let callsAfterSave = encryption.decryptCalls.count

        _ = try await repo.fetch(schemaId: schema.id, primaryKey: testPrimaryKey)

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
                FieldDefinition(id: "string-field", displayName: "String", fieldType: .string, displayOrder: 1),
                FieldDefinition(id: "int-field", displayName: "Integer", fieldType: .int, displayOrder: 2),
                FieldDefinition(id: "double-field", displayName: "Decimal", fieldType: .double, displayOrder: 3),
                FieldDefinition(id: "date-field", displayName: "Date", fieldType: .date, displayOrder: 4),
                FieldDefinition(id: "bool-field", displayName: "Boolean", fieldType: .bool, displayOrder: 5),
                FieldDefinition(id: "strings-field", displayName: "Tags", fieldType: .stringArray, displayOrder: 6),
                FieldDefinition(
                    id: "attachments-field",
                    displayName: "Attachments",
                    fieldType: .attachmentIds,
                    displayOrder: 7
                )
            ],
            isBuiltIn: false,
            version: 1
        )

        try await repo.save(schema, primaryKey: testPrimaryKey)

        let fetched = try await repo.fetch(schemaId: schema.id, primaryKey: testPrimaryKey)
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
