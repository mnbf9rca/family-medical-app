import CryptoKit
import Foundation
import Testing
@testable import FamilyMedicalApp

/// Tests for schema evolution safe changes (no breaking changes)
struct CustomSchemaEvolutionSafeTests {
    // MARK: - Test Dependencies

    func makeRepository() -> CustomSchemaRepository {
        let stack = MockCoreDataStack()
        let encryption = MockEncryptionService()
        return CustomSchemaRepository(
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
                    displayOrder: 2,
                    isMultiline: true
                )
            ],
            isBuiltIn: false,
            version: version
        )
    }

    let testPrimaryKey = SymmetricKey(size: .bits256)

    // MARK: - Display Name Changes

    @Test
    func save_displayNameChanged_succeeds() async throws {
        let repo = makeRepository()
        let schema = try makeTestSchema(version: 1)

        try await repo.save(schema, primaryKey: testPrimaryKey)

        let updatedSchema = try RecordSchema(
            id: schema.id,
            displayName: "New Display Name",
            iconSystemName: schema.iconSystemName,
            fields: schema.fields,
            isBuiltIn: false,
            version: 2
        )

        try await repo.save(updatedSchema, primaryKey: testPrimaryKey)

        let fetched = try await repo.fetch(schemaId: schema.id, primaryKey: testPrimaryKey)
        #expect(fetched?.displayName == "New Display Name")
        #expect(fetched?.version == 2)
    }

    @Test
    func save_fieldDisplayNameChanged_succeeds() async throws {
        let repo = makeRepository()
        let schema = try RecordSchema(
            id: "test-schema",
            displayName: "Test Schema",
            iconSystemName: "doc",
            fields: [
                FieldDefinition(id: "field1", displayName: "Original Name", fieldType: .string, displayOrder: 1)
            ],
            isBuiltIn: false,
            version: 1
        )

        try await repo.save(schema, primaryKey: testPrimaryKey)

        let updatedSchema = try RecordSchema(
            id: schema.id,
            displayName: schema.displayName,
            iconSystemName: schema.iconSystemName,
            fields: [
                FieldDefinition(id: "field1", displayName: "Updated Name", fieldType: .string, displayOrder: 1)
            ],
            isBuiltIn: false,
            version: 2
        )

        try await repo.save(updatedSchema, primaryKey: testPrimaryKey)

        let fetched = try await repo.fetch(schemaId: schema.id, primaryKey: testPrimaryKey)
        #expect(fetched?.fields.first?.displayName == "Updated Name")
    }

    // MARK: - Field Add/Remove

    @Test
    func save_newFieldAdded_succeeds() async throws {
        let repo = makeRepository()
        let schema = try makeTestSchema(version: 1)

        try await repo.save(schema, primaryKey: testPrimaryKey)

        var updatedFields = schema.fields
        updatedFields.append(FieldDefinition(
            id: "new-field",
            displayName: "New Field",
            fieldType: .string,
            displayOrder: 10
        ))

        let updatedSchema = try RecordSchema(
            id: schema.id,
            displayName: schema.displayName,
            iconSystemName: schema.iconSystemName,
            fields: updatedFields,
            isBuiltIn: false,
            version: 2
        )

        try await repo.save(updatedSchema, primaryKey: testPrimaryKey)

        let fetched = try await repo.fetch(schemaId: schema.id, primaryKey: testPrimaryKey)
        #expect(fetched?.fields.count == schema.fields.count + 1)
        #expect(fetched?.fields.contains { $0.id == "new-field" } == true)
    }

    @Test
    func save_fieldRemoved_succeeds() async throws {
        let repo = makeRepository()
        let schema = try makeTestSchema(version: 1)

        try await repo.save(schema, primaryKey: testPrimaryKey)

        guard let firstField = schema.fields.first else {
            Issue.record("Schema should have at least one field")
            return
        }
        let updatedFields = [firstField]

        let updatedSchema = try RecordSchema(
            id: schema.id,
            displayName: schema.displayName,
            iconSystemName: schema.iconSystemName,
            fields: updatedFields,
            isBuiltIn: false,
            version: 2
        )

        try await repo.save(updatedSchema, primaryKey: testPrimaryKey)

        let fetched = try await repo.fetch(schemaId: schema.id, primaryKey: testPrimaryKey)
        #expect(fetched?.fields.count == 1)
    }

    // MARK: - Required Relaxation

    @Test
    func save_requiredToOptional_succeeds() async throws {
        let repo = makeRepository()
        let schema = try RecordSchema(
            id: "test-schema",
            displayName: "Test Schema",
            iconSystemName: "doc",
            fields: [
                FieldDefinition(
                    id: "field1",
                    displayName: "Field",
                    fieldType: .string,
                    isRequired: true,
                    displayOrder: 1
                )
            ],
            isBuiltIn: false,
            version: 1
        )

        try await repo.save(schema, primaryKey: testPrimaryKey)

        let updatedSchema = try RecordSchema(
            id: schema.id,
            displayName: schema.displayName,
            iconSystemName: schema.iconSystemName,
            fields: [
                FieldDefinition(
                    id: "field1",
                    displayName: "Field",
                    fieldType: .string,
                    isRequired: false,
                    displayOrder: 1
                )
            ],
            isBuiltIn: false,
            version: 2
        )

        try await repo.save(updatedSchema, primaryKey: testPrimaryKey)

        let fetched = try await repo.fetch(schemaId: schema.id, primaryKey: testPrimaryKey)
        #expect(fetched?.fields.first?.isRequired == false)
    }

    // MARK: - Icon Changes

    @Test
    func save_iconSystemNameChanged_succeeds() async throws {
        let repo = makeRepository()
        let schema = try makeTestSchema(version: 1)

        try await repo.save(schema, primaryKey: testPrimaryKey)

        let updatedSchema = try RecordSchema(
            id: schema.id,
            displayName: schema.displayName,
            iconSystemName: "star.fill",
            fields: schema.fields,
            isBuiltIn: false,
            version: 2
        )

        try await repo.save(updatedSchema, primaryKey: testPrimaryKey)

        let fetched = try await repo.fetch(schemaId: schema.id, primaryKey: testPrimaryKey)
        #expect(fetched?.iconSystemName == "star.fill")
    }

    // MARK: - Validation Rule Changes

    @Test
    func save_validationRulesChanged_succeeds() async throws {
        let repo = makeRepository()
        let schema = try RecordSchema(
            id: "test-schema",
            displayName: "Test Schema",
            iconSystemName: "doc",
            fields: [
                FieldDefinition(
                    id: "field1",
                    displayName: "Field",
                    fieldType: .string,
                    displayOrder: 1,
                    validationRules: [.maxLength(100)]
                )
            ],
            isBuiltIn: false,
            version: 1
        )

        try await repo.save(schema, primaryKey: testPrimaryKey)

        let updatedSchema = try RecordSchema(
            id: schema.id,
            displayName: schema.displayName,
            iconSystemName: schema.iconSystemName,
            fields: [
                FieldDefinition(
                    id: "field1",
                    displayName: "Field",
                    fieldType: .string,
                    displayOrder: 1,
                    validationRules: [.minLength(10), .maxLength(500)]
                )
            ],
            isBuiltIn: false,
            version: 2
        )

        try await repo.save(updatedSchema, primaryKey: testPrimaryKey)

        let fetched = try await repo.fetch(schemaId: schema.id, primaryKey: testPrimaryKey)
        #expect(fetched?.fields.first?.validationRules.count == 2)
    }
}
