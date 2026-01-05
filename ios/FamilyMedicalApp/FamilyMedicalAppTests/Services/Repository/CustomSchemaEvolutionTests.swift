import CryptoKit
import Foundation
import Testing
@testable import FamilyMedicalApp

// swiftlint:disable type_body_length

/// Tests for schema evolution safe changes (no breaking changes)
struct CustomSchemaEvolutionSafeTests {
    // MARK: - Test Person ID

    // swiftlint:disable force_unwrapping
    /// Stable UUID for test person
    private static let testPersonId = UUID(uuidString: "22222222-0000-0000-0000-000000000001")!

    // MARK: - Test Field IDs

    // Stable UUIDs for consistent field identity across schema updates
    private static let titleFieldId = UUID(uuidString: "22222222-0001-0001-0000-000000000001")!
    private static let descriptionFieldId = UUID(uuidString: "22222222-0001-0002-0000-000000000001")!
    private static let field1Id = UUID(uuidString: "22222222-0001-0003-0000-000000000001")!
    private static let newFieldId = UUID(uuidString: "22222222-0001-0004-0000-000000000001")!
    private static let newRequiredFieldId = UUID(uuidString: "22222222-0001-0005-0000-000000000001")!
    // swiftlint:enable force_unwrapping

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
                    displayOrder: 2,
                    isMultiline: true
                )
            ],
            isBuiltIn: false,
            version: version
        )
    }

    let testPersonId = CustomSchemaEvolutionSafeTests.testPersonId
    let testFamilyMemberKey = SymmetricKey(size: .bits256)

    // MARK: - Display Name Changes

    @Test
    func save_displayNameChanged_succeeds() async throws {
        let repo = makeRepository()
        let schema = try makeTestSchema(version: 1)

        try await repo.save(schema, forPerson: testPersonId, familyMemberKey: testFamilyMemberKey)

        let updatedSchema = try RecordSchema(
            id: schema.id,
            displayName: "New Display Name",
            iconSystemName: schema.iconSystemName,
            fields: schema.fields,
            isBuiltIn: false,
            version: 2
        )

        try await repo.save(updatedSchema, forPerson: testPersonId, familyMemberKey: testFamilyMemberKey)

        let fetched = try await repo.fetch(
            schemaId: schema.id,
            forPerson: testPersonId,
            familyMemberKey: testFamilyMemberKey
        )
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
                .builtIn(id: Self.field1Id, displayName: "Original Name", fieldType: .string, displayOrder: 1)
            ],
            isBuiltIn: false,
            version: 1
        )

        try await repo.save(schema, forPerson: testPersonId, familyMemberKey: testFamilyMemberKey)

        let updatedSchema = try RecordSchema(
            id: schema.id,
            displayName: schema.displayName,
            iconSystemName: schema.iconSystemName,
            fields: [
                .builtIn(id: Self.field1Id, displayName: "Updated Name", fieldType: .string, displayOrder: 1)
            ],
            isBuiltIn: false,
            version: 2
        )

        try await repo.save(updatedSchema, forPerson: testPersonId, familyMemberKey: testFamilyMemberKey)

        let fetched = try await repo.fetch(
            schemaId: schema.id,
            forPerson: testPersonId,
            familyMemberKey: testFamilyMemberKey
        )
        #expect(fetched?.fields.first?.displayName == "Updated Name")
    }

    // MARK: - Field Add/Remove

    @Test
    func save_newFieldAdded_succeeds() async throws {
        let repo = makeRepository()
        let schema = try makeTestSchema(version: 1)

        try await repo.save(schema, forPerson: testPersonId, familyMemberKey: testFamilyMemberKey)

        var updatedFields = schema.fields
        updatedFields.append(.builtIn(
            id: Self.newFieldId,
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

        try await repo.save(updatedSchema, forPerson: testPersonId, familyMemberKey: testFamilyMemberKey)

        let fetched = try await repo.fetch(
            schemaId: schema.id,
            forPerson: testPersonId,
            familyMemberKey: testFamilyMemberKey
        )
        #expect(fetched?.fields.count == schema.fields.count + 1)
        #expect(fetched?.fields.contains { $0.id == Self.newFieldId } == true)
    }

    @Test
    func save_fieldRemoved_succeeds() async throws {
        let repo = makeRepository()
        let schema = try makeTestSchema(version: 1)

        try await repo.save(schema, forPerson: testPersonId, familyMemberKey: testFamilyMemberKey)

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

        try await repo.save(updatedSchema, forPerson: testPersonId, familyMemberKey: testFamilyMemberKey)

        let fetched = try await repo.fetch(
            schemaId: schema.id,
            forPerson: testPersonId,
            familyMemberKey: testFamilyMemberKey
        )
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
                .builtIn(
                    id: Self.field1Id,
                    displayName: "Field",
                    fieldType: .string,
                    isRequired: true,
                    displayOrder: 1
                )
            ],
            isBuiltIn: false,
            version: 1
        )

        try await repo.save(schema, forPerson: testPersonId, familyMemberKey: testFamilyMemberKey)

        let updatedSchema = try RecordSchema(
            id: schema.id,
            displayName: schema.displayName,
            iconSystemName: schema.iconSystemName,
            fields: [
                .builtIn(
                    id: Self.field1Id,
                    displayName: "Field",
                    fieldType: .string,
                    isRequired: false,
                    displayOrder: 1
                )
            ],
            isBuiltIn: false,
            version: 2
        )

        try await repo.save(updatedSchema, forPerson: testPersonId, familyMemberKey: testFamilyMemberKey)

        let fetched = try await repo.fetch(
            schemaId: schema.id,
            forPerson: testPersonId,
            familyMemberKey: testFamilyMemberKey
        )
        #expect(fetched?.fields.first?.isRequired == false)
    }

    @Test
    func save_optionalToRequired_succeeds() async throws {
        // Soft enforcement: optional→required is allowed
        // Existing records remain valid; enforcement happens at edit time
        let repo = makeRepository()
        let schema = try RecordSchema(
            id: "test-schema",
            displayName: "Test Schema",
            iconSystemName: "doc",
            fields: [
                .builtIn(
                    id: Self.field1Id,
                    displayName: "Field",
                    fieldType: .string,
                    isRequired: false,
                    displayOrder: 1
                )
            ],
            isBuiltIn: false,
            version: 1
        )

        try await repo.save(schema, forPerson: testPersonId, familyMemberKey: testFamilyMemberKey)

        let updatedSchema = try RecordSchema(
            id: schema.id,
            displayName: schema.displayName,
            iconSystemName: schema.iconSystemName,
            fields: [
                .builtIn(
                    id: Self.field1Id,
                    displayName: "Field",
                    fieldType: .string,
                    isRequired: true,
                    displayOrder: 1
                )
            ],
            isBuiltIn: false,
            version: 2
        )

        try await repo.save(updatedSchema, forPerson: testPersonId, familyMemberKey: testFamilyMemberKey)

        let fetched = try await repo.fetch(
            schemaId: schema.id,
            forPerson: testPersonId,
            familyMemberKey: testFamilyMemberKey
        )
        #expect(fetched?.fields.first?.isRequired == true)
    }

    @Test
    func save_newRequiredFieldAdded_succeeds() async throws {
        // Soft enforcement: adding required fields is allowed
        // Existing records remain valid; enforcement happens at edit time
        let repo = makeRepository()
        let schema = try makeTestSchema(version: 1)

        try await repo.save(schema, forPerson: testPersonId, familyMemberKey: testFamilyMemberKey)

        var updatedFields = schema.fields
        updatedFields.append(.builtIn(
            id: Self.newRequiredFieldId,
            displayName: "New Required Field",
            fieldType: .string,
            isRequired: true,
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

        try await repo.save(updatedSchema, forPerson: testPersonId, familyMemberKey: testFamilyMemberKey)

        let fetched = try await repo.fetch(
            schemaId: schema.id,
            forPerson: testPersonId,
            familyMemberKey: testFamilyMemberKey
        )
        #expect(fetched?.fields.count == schema.fields.count + 1)
        let newField = fetched?.fields.first { $0.id == Self.newRequiredFieldId }
        #expect(newField?.isRequired == true)
    }

    // MARK: - Icon Changes

    @Test
    func save_iconSystemNameChanged_succeeds() async throws {
        let repo = makeRepository()
        let schema = try makeTestSchema(version: 1)

        try await repo.save(schema, forPerson: testPersonId, familyMemberKey: testFamilyMemberKey)

        let updatedSchema = try RecordSchema(
            id: schema.id,
            displayName: schema.displayName,
            iconSystemName: "star.fill",
            fields: schema.fields,
            isBuiltIn: false,
            version: 2
        )

        try await repo.save(updatedSchema, forPerson: testPersonId, familyMemberKey: testFamilyMemberKey)

        let fetched = try await repo.fetch(
            schemaId: schema.id,
            forPerson: testPersonId,
            familyMemberKey: testFamilyMemberKey
        )
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
                .builtIn(
                    id: Self.field1Id,
                    displayName: "Field",
                    fieldType: .string,
                    displayOrder: 1,
                    validationRules: [.maxLength(100)]
                )
            ],
            isBuiltIn: false,
            version: 1
        )

        try await repo.save(schema, forPerson: testPersonId, familyMemberKey: testFamilyMemberKey)

        let updatedSchema = try RecordSchema(
            id: schema.id,
            displayName: schema.displayName,
            iconSystemName: schema.iconSystemName,
            fields: [
                .builtIn(
                    id: Self.field1Id,
                    displayName: "Field",
                    fieldType: .string,
                    displayOrder: 1,
                    validationRules: [.minLength(10), .maxLength(500)]
                )
            ],
            isBuiltIn: false,
            version: 2
        )

        try await repo.save(updatedSchema, forPerson: testPersonId, familyMemberKey: testFamilyMemberKey)

        let fetched = try await repo.fetch(
            schemaId: schema.id,
            forPerson: testPersonId,
            familyMemberKey: testFamilyMemberKey
        )
        #expect(fetched?.fields.first?.validationRules.count == 2)
    }
}

// swiftlint:enable type_body_length
