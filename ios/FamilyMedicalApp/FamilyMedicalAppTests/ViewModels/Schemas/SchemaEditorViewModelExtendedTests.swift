import CryptoKit
import Dependencies
import Foundation
import Testing
@testable import FamilyMedicalApp

/// Extended tests for SchemaEditorViewModel - Field Management, Validation, Save, and Preview tests
@MainActor
struct SchemaEditorViewModelExtendedTests {
    // MARK: - Test Data

    let testPrimaryKey = SymmetricKey(size: .bits256)
    let testFMK = SymmetricKey(size: .bits256)

    func createTestPerson() throws -> Person {
        try PersonTestHelper.makeTestPerson()
    }

    func createTestSchema(
        id: String = "test-schema",
        displayName: String = "Test Schema",
        isBuiltIn: Bool = false,
        fields: [FieldDefinition] = []
    ) -> RecordSchema {
        RecordSchema(
            unsafeId: id,
            displayName: displayName,
            iconSystemName: "doc.text",
            fields: fields,
            isBuiltIn: isBuiltIn,
            description: "Test description"
        )
    }

    func createTestField(
        id: UUID = UUID(),
        displayName: String = "Test Field",
        fieldType: FieldType = .string,
        displayOrder: Int = 1,
        visibility: FieldVisibility = .active
    ) -> FieldDefinition {
        let now = Date()
        return FieldDefinition(
            id: id,
            displayName: displayName,
            fieldType: fieldType,
            isRequired: false,
            displayOrder: displayOrder,
            placeholder: nil,
            helpText: nil,
            validationRules: [],
            isMultiline: false,
            capitalizationMode: .sentences,
            visibility: visibility,
            createdBy: .zero,
            createdAt: now,
            updatedBy: .zero,
            updatedAt: now
        )
    }

    // MARK: - Field Management Tests

    @Test
    func createNewFieldGeneratesUniqueId() async throws {
        let person = try createTestPerson()
        let schema = createTestSchema()

        let fixedUUID = try #require(UUID(uuidString: "12345678-0000-0000-0000-000000000000"))
        let fixedDate = Date(timeIntervalSinceReferenceDate: 1_000_000)

        let viewModel = withDependencies {
            $0.uuid = .constant(fixedUUID)
            $0.date = .constant(fixedDate)
        } operation: {
            SchemaEditorViewModel(
                person: person,
                schema: schema,
                customSchemaRepository: MockCustomSchemaRepository(),
                primaryKeyProvider: MockPrimaryKeyProvider(primaryKey: testPrimaryKey),
                fmkService: MockFamilyMemberKeyService()
            )
        }

        let field = viewModel.createNewField(type: .string)

        #expect(field.id == fixedUUID)
        #expect(field.fieldType == .string)
        #expect(field.displayName == "New Field")
        #expect(field.displayOrder == 1)
    }

    @Test
    func createNewFieldSetsDisplayOrderAfterExisting() async throws {
        let person = try createTestPerson()
        let existingField = createTestField(displayOrder: 5)
        let schema = createTestSchema(fields: [existingField])

        let viewModel = withDependencies {
            $0.uuid = .incrementing
            $0.date = .constant(Date())
        } operation: {
            SchemaEditorViewModel(
                person: person,
                schema: schema,
                customSchemaRepository: MockCustomSchemaRepository(),
                primaryKeyProvider: MockPrimaryKeyProvider(primaryKey: testPrimaryKey),
                fmkService: MockFamilyMemberKeyService()
            )
        }

        let newField = viewModel.createNewField(type: .int)

        #expect(newField.displayOrder == 6)
    }

    @Test
    func addFieldAppendsToList() async throws {
        let person = try createTestPerson()
        let schema = createTestSchema()

        let viewModel = withDependencies {
            $0.uuid = .incrementing
            $0.date = .constant(Date())
        } operation: {
            SchemaEditorViewModel(
                person: person,
                schema: schema,
                customSchemaRepository: MockCustomSchemaRepository(),
                primaryKeyProvider: MockPrimaryKeyProvider(primaryKey: testPrimaryKey),
                fmkService: MockFamilyMemberKeyService()
            )
        }

        #expect(viewModel.fields.isEmpty)

        let newField = viewModel.createNewField(type: .string)
        viewModel.addField(newField)

        #expect(viewModel.fields.count == 1)
    }

    @Test
    func updateFieldModifiesExisting() async throws {
        let person = try createTestPerson()
        let fieldId = UUID()
        let field = createTestField(id: fieldId, displayName: "Original")
        let schema = createTestSchema(fields: [field])

        let viewModel = SchemaEditorViewModel(
            person: person,
            schema: schema,
            customSchemaRepository: MockCustomSchemaRepository(),
            primaryKeyProvider: MockPrimaryKeyProvider(primaryKey: testPrimaryKey),
            fmkService: MockFamilyMemberKeyService()
        )

        var updatedField = viewModel.fields[0]
        updatedField.displayName = "Updated"
        viewModel.updateField(updatedField)

        #expect(viewModel.fields[0].displayName == "Updated")
    }

    @Test
    func hideFieldSetsVisibilityToHidden() async throws {
        let person = try createTestPerson()
        let fieldId = UUID()
        let field = createTestField(id: fieldId, visibility: .active)
        let schema = createTestSchema(fields: [field])

        let viewModel = SchemaEditorViewModel(
            person: person,
            schema: schema,
            customSchemaRepository: MockCustomSchemaRepository(),
            primaryKeyProvider: MockPrimaryKeyProvider(primaryKey: testPrimaryKey),
            fmkService: MockFamilyMemberKeyService()
        )

        viewModel.hideField(withId: fieldId)

        #expect(viewModel.fields[0].visibility == .hidden)
    }

    @Test
    func unhideFieldSetsVisibilityToActive() async throws {
        let person = try createTestPerson()
        let fieldId = UUID()
        let field = createTestField(id: fieldId, visibility: .hidden)
        let schema = createTestSchema(fields: [field])

        let viewModel = SchemaEditorViewModel(
            person: person,
            schema: schema,
            customSchemaRepository: MockCustomSchemaRepository(),
            primaryKeyProvider: MockPrimaryKeyProvider(primaryKey: testPrimaryKey),
            fmkService: MockFamilyMemberKeyService()
        )

        viewModel.unhideField(withId: fieldId)

        #expect(viewModel.fields[0].visibility == .active)
    }

    @Test
    func deleteFieldSucceedsForCustomField() async throws {
        let person = try createTestPerson()
        let customFieldId = UUID()
        let field = createTestField(id: customFieldId)
        let schema = createTestSchema(fields: [field])

        let viewModel = SchemaEditorViewModel(
            person: person,
            schema: schema,
            customSchemaRepository: MockCustomSchemaRepository(),
            primaryKeyProvider: MockPrimaryKeyProvider(primaryKey: testPrimaryKey),
            fmkService: MockFamilyMemberKeyService()
        )

        let success = viewModel.deleteField(withId: customFieldId)

        #expect(success == true)
        #expect(viewModel.fields.isEmpty)
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    func deleteFieldFailsForBuiltInField() async throws {
        let person = try createTestPerson()
        let builtInFieldId = BuiltInFieldIds.Vaccine.name
        var field = createTestField(id: builtInFieldId)
        field = FieldDefinition.builtIn(
            id: builtInFieldId,
            displayName: "Built-in Field",
            fieldType: .string,
            isRequired: true,
            displayOrder: 1
        )
        let schema = createTestSchema(fields: [field])

        let viewModel = SchemaEditorViewModel(
            person: person,
            schema: schema,
            customSchemaRepository: MockCustomSchemaRepository(),
            primaryKeyProvider: MockPrimaryKeyProvider(primaryKey: testPrimaryKey),
            fmkService: MockFamilyMemberKeyService()
        )

        let success = viewModel.deleteField(withId: builtInFieldId)

        #expect(success == false)
        #expect(viewModel.fields.count == 1)
        #expect(viewModel.errorMessage?.contains("Built-in") == true)
    }

    @Test
    func moveFieldsUpdatesDisplayOrder() async throws {
        let person = try createTestPerson()
        let field1 = createTestField(id: UUID(), displayName: "First", displayOrder: 1)
        let field2 = createTestField(id: UUID(), displayName: "Second", displayOrder: 2)
        let field3 = createTestField(id: UUID(), displayName: "Third", displayOrder: 3)
        let schema = createTestSchema(fields: [field1, field2, field3])

        let viewModel = SchemaEditorViewModel(
            person: person,
            schema: schema,
            customSchemaRepository: MockCustomSchemaRepository(),
            primaryKeyProvider: MockPrimaryKeyProvider(primaryKey: testPrimaryKey),
            fmkService: MockFamilyMemberKeyService()
        )

        viewModel.moveFields(from: IndexSet(integer: 0), to: 3)

        let active = viewModel.activeFields
        #expect(active[0].displayName == "Second")
        #expect(active[1].displayName == "Third")
        #expect(active[2].displayName == "First")
    }
}

// MARK: - Validation Tests

extension SchemaEditorViewModelExtendedTests {
    @Test
    func validateFailsWithEmptyName() async throws {
        let person = try createTestPerson()
        let field = createTestField()
        let schema = createTestSchema(fields: [field])

        let viewModel = SchemaEditorViewModel(
            person: person,
            schema: schema,
            customSchemaRepository: MockCustomSchemaRepository(),
            primaryKeyProvider: MockPrimaryKeyProvider(primaryKey: testPrimaryKey),
            fmkService: MockFamilyMemberKeyService()
        )

        viewModel.displayName = "   "

        let valid = viewModel.validate()

        #expect(valid == false)
        #expect(viewModel.errorMessage?.contains("name") == true)
    }

    @Test
    func validateFailsWithNoActiveFields() async throws {
        let person = try createTestPerson()
        let schema = createTestSchema(fields: [])

        let viewModel = SchemaEditorViewModel(
            person: person,
            schema: schema,
            customSchemaRepository: MockCustomSchemaRepository(),
            primaryKeyProvider: MockPrimaryKeyProvider(primaryKey: testPrimaryKey),
            fmkService: MockFamilyMemberKeyService()
        )

        let valid = viewModel.validate()

        #expect(valid == false)
        #expect(viewModel.errorMessage?.contains("field") == true)
    }

    @Test
    func validateSucceedsWithValidSchema() async throws {
        let person = try createTestPerson()
        let field = createTestField()
        let schema = createTestSchema(displayName: "Valid Schema", fields: [field])

        let viewModel = SchemaEditorViewModel(
            person: person,
            schema: schema,
            customSchemaRepository: MockCustomSchemaRepository(),
            primaryKeyProvider: MockPrimaryKeyProvider(primaryKey: testPrimaryKey),
            fmkService: MockFamilyMemberKeyService()
        )

        let valid = viewModel.validate()

        #expect(valid == true)
        #expect(viewModel.errorMessage == nil)
    }
}

// MARK: - Save Tests

extension SchemaEditorViewModelExtendedTests {
    @Test
    func saveSucceedsAndSetsFlag() async throws {
        let person = try createTestPerson()
        let field = createTestField()
        let schema = createTestSchema(displayName: "Test", fields: [field])

        let mockSchemaRepo = MockCustomSchemaRepository()
        let mockKeyProvider = MockPrimaryKeyProvider(primaryKey: testPrimaryKey)
        let mockFMKService = MockFamilyMemberKeyService()
        mockFMKService.setFMK(testFMK, for: person.id.uuidString)

        let viewModel = SchemaEditorViewModel(
            person: person,
            schema: schema,
            customSchemaRepository: mockSchemaRepo,
            primaryKeyProvider: mockKeyProvider,
            fmkService: mockFMKService
        )

        await viewModel.save()

        #expect(viewModel.didSaveSuccessfully == true)
        #expect(viewModel.errorMessage == nil)
        #expect(mockSchemaRepo.saveCallCount == 1)
        #expect(mockSchemaRepo.lastSavedSchema?.version == 2)
    }

    @Test
    func saveFailsValidationDoesNotCallRepository() async throws {
        let person = try createTestPerson()
        let schema = createTestSchema(fields: [])

        let mockSchemaRepo = MockCustomSchemaRepository()
        let mockKeyProvider = MockPrimaryKeyProvider(primaryKey: testPrimaryKey)
        let mockFMKService = MockFamilyMemberKeyService()
        mockFMKService.setFMK(testFMK, for: person.id.uuidString)

        let viewModel = SchemaEditorViewModel(
            person: person,
            schema: schema,
            customSchemaRepository: mockSchemaRepo,
            primaryKeyProvider: mockKeyProvider,
            fmkService: mockFMKService
        )

        await viewModel.save()

        #expect(viewModel.didSaveSuccessfully == false)
        #expect(viewModel.errorMessage != nil)
        #expect(mockSchemaRepo.saveCallCount == 0)
    }

    @Test
    func saveHandlesRepositoryFailure() async throws {
        let person = try createTestPerson()
        let field = createTestField()
        let schema = createTestSchema(fields: [field])

        let mockSchemaRepo = MockCustomSchemaRepository()
        mockSchemaRepo.shouldFailSave = true

        let mockKeyProvider = MockPrimaryKeyProvider(primaryKey: testPrimaryKey)
        let mockFMKService = MockFamilyMemberKeyService()
        mockFMKService.setFMK(testFMK, for: person.id.uuidString)

        let viewModel = SchemaEditorViewModel(
            person: person,
            schema: schema,
            customSchemaRepository: mockSchemaRepo,
            primaryKeyProvider: mockKeyProvider,
            fmkService: mockFMKService
        )

        await viewModel.save()

        #expect(viewModel.didSaveSuccessfully == false)
        #expect(viewModel.errorMessage?.contains("Unable to save") == true)
    }
}

// MARK: - Preview Support Tests

extension SchemaEditorViewModelExtendedTests {
    @Test
    func createPreviewSchemaReturnsCurrentState() async throws {
        let person = try createTestPerson()
        let field = createTestField(displayName: "Preview Field")
        let schema = createTestSchema(fields: [field])

        let viewModel = SchemaEditorViewModel(
            person: person,
            schema: schema,
            customSchemaRepository: MockCustomSchemaRepository(),
            primaryKeyProvider: MockPrimaryKeyProvider(primaryKey: testPrimaryKey),
            fmkService: MockFamilyMemberKeyService()
        )

        viewModel.displayName = "Modified Name"

        let preview = viewModel.createPreviewSchema()

        #expect(preview.displayName == "Modified Name")
        #expect(preview.fields.count == 1)
        #expect(preview.fields[0].displayName == "Preview Field")
    }
}
