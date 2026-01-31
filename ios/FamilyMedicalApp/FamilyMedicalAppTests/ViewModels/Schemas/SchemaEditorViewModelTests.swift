import CryptoKit
import Dependencies
import Foundation
import Testing
@testable import FamilyMedicalApp

@MainActor
struct SchemaEditorViewModelTests {
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

    // MARK: - Initialization Tests

    @Test
    func initWithExistingSchemaPopulatesState() throws {
        let person = try createTestPerson()
        let field1 = createTestField(displayName: "Field 1", displayOrder: 1)
        let field2 = createTestField(displayName: "Field 2", displayOrder: 2)
        let schema = createTestSchema(
            id: "my-schema",
            displayName: "My Schema",
            fields: [field1, field2]
        )

        let viewModel = SchemaEditorViewModel(
            person: person,
            schema: schema,
            customSchemaRepository: MockCustomSchemaRepository(),
            primaryKeyProvider: MockPrimaryKeyProvider(primaryKey: testPrimaryKey),
            fmkService: MockFamilyMemberKeyService()
        )

        #expect(viewModel.schemaId == "my-schema")
        #expect(viewModel.displayName == "My Schema")
        #expect(viewModel.schemaDescription == "Test description")
        #expect(viewModel.fields.count == 2)
        #expect(viewModel.isNewSchema == false)
        #expect(viewModel.originalSchema != nil)
    }

    @Test
    func initForNewSchemaCreatesEmptyState() throws {
        let person = try createTestPerson()
        let template = createTestSchema(id: "new-schema", displayName: "New Schema")

        let viewModel = SchemaEditorViewModel(
            person: person,
            newSchemaTemplate: template,
            customSchemaRepository: MockCustomSchemaRepository(),
            primaryKeyProvider: MockPrimaryKeyProvider(primaryKey: testPrimaryKey),
            fmkService: MockFamilyMemberKeyService()
        )

        #expect(viewModel.schemaId == "new-schema")
        #expect(viewModel.displayName == "New Schema")
        #expect(viewModel.isNewSchema == true)
        #expect(viewModel.originalSchema == nil)
    }
}

// MARK: - Computed Properties Tests

extension SchemaEditorViewModelTests {
    @Test
    func isBuiltInSchemaReturnsTrueForBuiltIn() throws {
        let person = try createTestPerson()
        let schema = createTestSchema(isBuiltIn: true)

        let viewModel = SchemaEditorViewModel(
            person: person,
            schema: schema,
            customSchemaRepository: MockCustomSchemaRepository(),
            primaryKeyProvider: MockPrimaryKeyProvider(primaryKey: testPrimaryKey),
            fmkService: MockFamilyMemberKeyService()
        )

        #expect(viewModel.isBuiltInSchema == true)
        #expect(viewModel.canEditName == false)
    }

    @Test
    func isBuiltInSchemaReturnsFalseForCustom() throws {
        let person = try createTestPerson()
        let schema = createTestSchema(isBuiltIn: false)

        let viewModel = SchemaEditorViewModel(
            person: person,
            schema: schema,
            customSchemaRepository: MockCustomSchemaRepository(),
            primaryKeyProvider: MockPrimaryKeyProvider(primaryKey: testPrimaryKey),
            fmkService: MockFamilyMemberKeyService()
        )

        #expect(viewModel.isBuiltInSchema == false)
        #expect(viewModel.canEditName == true)
    }

    @Test
    func nextVersionIncrementsFromOriginal() throws {
        let person = try createTestPerson()
        var schema = createTestSchema()
        // Manually set version (normally done via unsafeId initializer)
        schema = RecordSchema(
            unsafeId: schema.id,
            displayName: schema.displayName,
            iconSystemName: schema.iconSystemName,
            fields: schema.fields,
            isBuiltIn: schema.isBuiltIn,
            description: schema.description,
            version: 5
        )

        let viewModel = SchemaEditorViewModel(
            person: person,
            schema: schema,
            customSchemaRepository: MockCustomSchemaRepository(),
            primaryKeyProvider: MockPrimaryKeyProvider(primaryKey: testPrimaryKey),
            fmkService: MockFamilyMemberKeyService()
        )

        #expect(viewModel.nextVersion == 6)
    }

    @Test
    func activeFieldsFiltersAndSorts() throws {
        let person = try createTestPerson()
        let field1 = createTestField(displayName: "C Field", displayOrder: 3, visibility: .active)
        let field2 = createTestField(displayName: "A Field", displayOrder: 1, visibility: .active)
        let field3 = createTestField(displayName: "Hidden", displayOrder: 2, visibility: .hidden)
        let schema = createTestSchema(fields: [field1, field2, field3])

        let viewModel = SchemaEditorViewModel(
            person: person,
            schema: schema,
            customSchemaRepository: MockCustomSchemaRepository(),
            primaryKeyProvider: MockPrimaryKeyProvider(primaryKey: testPrimaryKey),
            fmkService: MockFamilyMemberKeyService()
        )

        let active = viewModel.activeFields
        #expect(active.count == 2)
        #expect(active[0].displayName == "A Field") // Order 1
        #expect(active[1].displayName == "C Field") // Order 3
    }

    @Test
    func hiddenFieldsFiltersCorrectly() throws {
        let person = try createTestPerson()
        let field1 = createTestField(displayName: "Active", visibility: .active)
        let field2 = createTestField(displayName: "Hidden", visibility: .hidden)
        let schema = createTestSchema(fields: [field1, field2])

        let viewModel = SchemaEditorViewModel(
            person: person,
            schema: schema,
            customSchemaRepository: MockCustomSchemaRepository(),
            primaryKeyProvider: MockPrimaryKeyProvider(primaryKey: testPrimaryKey),
            fmkService: MockFamilyMemberKeyService()
        )

        #expect(viewModel.hiddenFields.count == 1)
        #expect(viewModel.hiddenFields[0].displayName == "Hidden")
    }
}

// MARK: - Has Unsaved Changes Tests

extension SchemaEditorViewModelTests {
    @Test
    func hasUnsavedChangesDetectsNameChange() throws {
        let person = try createTestPerson()
        let field = createTestField()
        let schema = createTestSchema(displayName: "Original", fields: [field])

        let viewModel = SchemaEditorViewModel(
            person: person,
            schema: schema,
            customSchemaRepository: MockCustomSchemaRepository(),
            primaryKeyProvider: MockPrimaryKeyProvider(primaryKey: testPrimaryKey),
            fmkService: MockFamilyMemberKeyService()
        )

        #expect(viewModel.hasUnsavedChanges == false)

        viewModel.displayName = "Modified"

        #expect(viewModel.hasUnsavedChanges == true)
    }

    @Test
    func hasUnsavedChangesDetectsFieldAddition() throws {
        let person = try createTestPerson()
        let schema = createTestSchema(fields: [])

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

        #expect(viewModel.hasUnsavedChanges == false)

        let newField = viewModel.createNewField(type: .string)
        viewModel.addField(newField)

        #expect(viewModel.hasUnsavedChanges == true)
    }

    @Test
    func hasUnsavedChangesDetectsFieldVisibilityChange() throws {
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

        #expect(viewModel.hasUnsavedChanges == false)

        viewModel.hideField(withId: fieldId)

        #expect(viewModel.hasUnsavedChanges == true)
    }
}
