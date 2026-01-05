import CryptoKit
import Foundation
import Testing
@testable import FamilyMedicalApp

/// Tests for schema evolution breaking change validation
struct CustomSchemaEvolutionBreakingTests {
    // MARK: - Test Person ID

    // swiftlint:disable force_unwrapping
    /// Stable UUID for test person
    private static let testPersonId = UUID(uuidString: "11111111-0000-0000-0000-000000000001")!

    // MARK: - Test Field IDs

    // Stable UUIDs for consistent field identity across schema updates
    private static let titleFieldId = UUID(uuidString: "11111111-0001-0001-0000-000000000001")!
    private static let descriptionFieldId = UUID(uuidString: "11111111-0001-0002-0000-000000000001")!
    private static let valueFieldId = UUID(uuidString: "11111111-0001-0003-0000-000000000001")!
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

    let testPersonId = CustomSchemaEvolutionBreakingTests.testPersonId
    let testFamilyMemberKey = SymmetricKey(size: .bits256)

    // MARK: - Version Validation Tests

    @Test
    func save_versionNotIncremented_throwsError() async throws {
        let repo = makeRepository()
        let schema = try makeTestSchema(version: 1)

        try await repo.save(schema, forPerson: testPersonId, familyMemberKey: testFamilyMemberKey)

        let updatedSchema = try RecordSchema(
            id: schema.id,
            displayName: "Updated Name",
            iconSystemName: schema.iconSystemName,
            fields: schema.fields,
            isBuiltIn: false,
            version: 1
        )

        await #expect(throws: RepositoryError.schemaVersionNotIncremented(current: 1, expected: 2)) {
            try await repo.save(updatedSchema, forPerson: testPersonId, familyMemberKey: testFamilyMemberKey)
        }
    }

    @Test
    func save_versionDecremented_throwsError() async throws {
        let repo = makeRepository()
        let schema = try makeTestSchema(version: 5)

        try await repo.save(schema, forPerson: testPersonId, familyMemberKey: testFamilyMemberKey)

        let updatedSchema = try RecordSchema(
            id: schema.id,
            displayName: "Updated Name",
            iconSystemName: schema.iconSystemName,
            fields: schema.fields,
            isBuiltIn: false,
            version: 3
        )

        await #expect(throws: RepositoryError.schemaVersionNotIncremented(current: 5, expected: 6)) {
            try await repo.save(updatedSchema, forPerson: testPersonId, familyMemberKey: testFamilyMemberKey)
        }
    }

    // MARK: - Field Type Change Tests

    @Test
    func save_fieldTypeChanged_throwsError() async throws {
        let repo = makeRepository()
        let schema = try RecordSchema(
            id: "test-schema",
            displayName: "Test Schema",
            iconSystemName: "doc",
            fields: [
                .builtIn(id: Self.valueFieldId, displayName: "Value", fieldType: .string, displayOrder: 1)
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
                .builtIn(id: Self.valueFieldId, displayName: "Value", fieldType: .int, displayOrder: 1)
            ],
            isBuiltIn: false,
            version: 2
        )

        await #expect(throws: RepositoryError.fieldTypeChangeNotAllowed(
            fieldId: Self.valueFieldId.uuidString,
            from: .string,
            to: .int
        )) {
            try await repo.save(updatedSchema, forPerson: testPersonId, familyMemberKey: testFamilyMemberKey)
        }
    }

    @Test
    func save_intToDouble_throwsError() async throws {
        let repo = makeRepository()
        let schema = try RecordSchema(
            id: "test-schema",
            displayName: "Test Schema",
            iconSystemName: "doc",
            fields: [
                .builtIn(id: Self.valueFieldId, displayName: "Value", fieldType: .int, displayOrder: 1)
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
                .builtIn(id: Self.valueFieldId, displayName: "Value", fieldType: .double, displayOrder: 1)
            ],
            isBuiltIn: false,
            version: 2
        )

        await #expect(throws: RepositoryError.fieldTypeChangeNotAllowed(
            fieldId: Self.valueFieldId.uuidString,
            from: .int,
            to: .double
        )) {
            try await repo.save(updatedSchema, forPerson: testPersonId, familyMemberKey: testFamilyMemberKey)
        }
    }
}
