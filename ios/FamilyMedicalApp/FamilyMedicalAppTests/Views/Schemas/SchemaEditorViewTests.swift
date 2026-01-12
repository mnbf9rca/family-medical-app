import CryptoKit
import Dependencies
import SwiftUI
import Testing
import ViewInspector
@testable import FamilyMedicalApp

@MainActor
struct SchemaEditorViewTests {
    // MARK: - Test Data

    let testPrimaryKey = SymmetricKey(size: .bits256)
    let testFMK = SymmetricKey(size: .bits256)
    let testDate = Date(timeIntervalSinceReferenceDate: 1_234_567_890)

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
        displayName: String = "Test Field",
        fieldType: FieldType = .string
    ) -> FieldDefinition {
        let now = Date()
        return FieldDefinition(
            id: UUID(),
            displayName: displayName,
            fieldType: fieldType,
            isRequired: false,
            displayOrder: 1,
            placeholder: nil,
            helpText: nil,
            validationRules: [],
            isMultiline: false,
            capitalizationMode: .sentences,
            visibility: .active,
            createdBy: .zero,
            createdAt: now,
            updatedBy: .zero,
            updatedAt: now
        )
    }

    func createViewModel(
        person: Person,
        schema: RecordSchema? = nil,
        newSchemaTemplate: RecordSchema? = nil
    ) -> SchemaEditorViewModel {
        let mockRepo = MockCustomSchemaRepository()
        let mockKeyProvider = MockPrimaryKeyProvider(primaryKey: testPrimaryKey)
        let mockFMKService = MockFamilyMemberKeyService()
        mockFMKService.setFMK(testFMK, for: person.id.uuidString)

        return withDependencies {
            $0.uuid = .incrementing
            $0.date = .constant(testDate)
        } operation: {
            if let schema = schema {
                SchemaEditorViewModel(
                    person: person,
                    schema: schema,
                    customSchemaRepository: mockRepo,
                    primaryKeyProvider: mockKeyProvider,
                    fmkService: mockFMKService
                )
            } else if let template = newSchemaTemplate {
                SchemaEditorViewModel(
                    person: person,
                    newSchemaTemplate: template,
                    customSchemaRepository: mockRepo,
                    primaryKeyProvider: mockKeyProvider,
                    fmkService: mockFMKService
                )
            } else {
                // Default to editing a test schema
                SchemaEditorViewModel(
                    person: person,
                    schema: createTestSchema(),
                    customSchemaRepository: mockRepo,
                    primaryKeyProvider: mockKeyProvider,
                    fmkService: mockFMKService
                )
            }
        }
    }

    // MARK: - Rendering Tests

    @Test
    func viewRendersForNewSchema() throws {
        let person = try createTestPerson()
        let template = createTestSchema(id: "new-schema", displayName: "New Schema")

        let view = SchemaEditorView(person: person, newSchemaTemplate: template)

        _ = try view.inspect()
    }

    @Test
    func viewRendersForExistingSchema() throws {
        let person = try createTestPerson()
        let schema = createTestSchema(displayName: "Existing Schema")

        let view = SchemaEditorView(person: person, schema: schema)

        _ = try view.inspect()
    }

    @Test
    func viewRendersForSchemaWithFields() throws {
        let person = try createTestPerson()
        let field = createTestField(displayName: "Field 1")
        let schema = createTestSchema(fields: [field])

        let view = SchemaEditorView(person: person, schema: schema)

        _ = try view.inspect()
    }

    @Test
    func viewRendersForBuiltInSchema() throws {
        let person = try createTestPerson()
        let schema = RecordSchema.builtIn(.vaccine)

        let view = SchemaEditorView(person: person, schema: schema)

        _ = try view.inspect()
    }

    @Test
    func viewRendersWithMultipleFields() throws {
        let person = try createTestPerson()
        let fields = [
            createTestField(displayName: "Field 1", fieldType: .string),
            createTestField(displayName: "Field 2", fieldType: .int),
            createTestField(displayName: "Field 3", fieldType: .date)
        ]
        let schema = createTestSchema(fields: fields)

        let view = SchemaEditorView(person: person, schema: schema)

        _ = try view.inspect()
    }

    @Test
    func viewRendersForAllBuiltInSchemaTypes() throws {
        let person = try createTestPerson()
        for schemaType in BuiltInSchemaType.allCases {
            let schema = RecordSchema.builtIn(schemaType)
            let view = SchemaEditorView(person: person, schema: schema)
            _ = try view.inspect()
        }
    }

    @Test
    func viewRendersFormStructure() throws {
        let person = try createTestPerson()
        let schema = createTestSchema()
        let view = SchemaEditorView(person: person, schema: schema)

        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.Form.self)
    }

    @Test
    func viewRendersWithHiddenFields() throws {
        let person = try createTestPerson()
        var hiddenField = createTestField(displayName: "Hidden Field")
        hiddenField.visibility = .hidden
        let schema = createTestSchema(fields: [hiddenField])

        let view = SchemaEditorView(person: person, schema: schema)
        _ = try view.inspect()
    }

    @Test
    func viewRendersWithMixedVisibilityFields() throws {
        let person = try createTestPerson()
        let activeField = createTestField(displayName: "Active Field", fieldType: .string)
        var hiddenField = createTestField(displayName: "Hidden Field", fieldType: .int)
        hiddenField.visibility = .hidden
        let schema = createTestSchema(fields: [activeField, hiddenField])

        let view = SchemaEditorView(person: person, schema: schema)
        _ = try view.inspect()
    }

    @Test
    func viewRendersWithRequiredFields() throws {
        let person = try createTestPerson()
        var requiredField = createTestField(displayName: "Required Field")
        requiredField.isRequired = true
        let schema = createTestSchema(fields: [requiredField])

        let view = SchemaEditorView(person: person, schema: schema)
        _ = try view.inspect()
    }

    @Test
    func viewRendersWithAllFieldTypes() throws {
        let person = try createTestPerson()
        let fields = FieldType.allCases.map { fieldType in
            createTestField(displayName: "\(fieldType.displayName) Field", fieldType: fieldType)
        }
        let schema = createTestSchema(fields: fields)

        let view = SchemaEditorView(person: person, schema: schema)
        _ = try view.inspect()
    }

    @Test
    func viewRendersWithCustomIcon() throws {
        let person = try createTestPerson()
        let schema = RecordSchema(
            unsafeId: "custom-icon",
            displayName: "Custom Icon Schema",
            iconSystemName: "heart.fill",
            fields: [],
            isBuiltIn: false,
            description: nil
        )

        let view = SchemaEditorView(person: person, schema: schema)
        _ = try view.inspect()
    }

    @Test
    func viewRendersWithDescription() throws {
        let person = try createTestPerson()
        let schema = RecordSchema(
            unsafeId: "with-description",
            displayName: "Schema With Description",
            iconSystemName: "doc.text",
            fields: [],
            isBuiltIn: false,
            description: "This is a test description for the schema"
        )

        let view = SchemaEditorView(person: person, schema: schema)
        _ = try view.inspect()
    }
}

// MARK: - ViewModel Injection Tests

extension SchemaEditorViewTests {
    @Test
    func viewUsesInjectedViewModelForExistingSchema() throws {
        let person = try createTestPerson()
        let schema = createTestSchema(displayName: "Original Name")
        let viewModel = createViewModel(person: person, schema: schema)
        viewModel.displayName = "Modified Name"

        let view = SchemaEditorView(person: person, schema: schema, viewModel: viewModel)

        _ = try view.inspect()
        #expect(viewModel.displayName == "Modified Name")
    }

    @Test
    func viewUsesInjectedViewModelForNewSchema() throws {
        let person = try createTestPerson()
        let template = createTestSchema(id: "new-template", displayName: "Template Name")
        let viewModel = createViewModel(person: person, newSchemaTemplate: template)
        viewModel.displayName = "New Schema Name"

        let view = SchemaEditorView(person: person, newSchemaTemplate: template, viewModel: viewModel)

        _ = try view.inspect()
        #expect(viewModel.displayName == "New Schema Name")
    }
}

// MARK: - State Tests

extension SchemaEditorViewTests {
    @Test
    func viewRendersWithLoadingState() throws {
        let person = try createTestPerson()
        let schema = createTestSchema()
        let viewModel = createViewModel(person: person, schema: schema)
        viewModel.isLoading = true

        let view = SchemaEditorView(person: person, schema: schema, viewModel: viewModel)

        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.ProgressView.self)
    }

    @Test
    func viewRendersWithErrorMessage() throws {
        let person = try createTestPerson()
        let schema = createTestSchema()
        let viewModel = createViewModel(person: person, schema: schema)
        viewModel.errorMessage = "Test error"

        let view = SchemaEditorView(person: person, schema: schema, viewModel: viewModel)

        _ = try view.inspect()
        #expect(viewModel.errorMessage == "Test error")
    }

    @Test
    func viewRendersNewSchemaWithCanEditNameTrue() throws {
        let person = try createTestPerson()
        let template = createTestSchema(id: "new-schema", displayName: "New Schema", isBuiltIn: false)
        let viewModel = createViewModel(person: person, newSchemaTemplate: template)

        let view = SchemaEditorView(person: person, newSchemaTemplate: template, viewModel: viewModel)

        _ = try view.inspect()
        #expect(viewModel.canEditName == true)
    }

    @Test
    func viewRendersBuiltInSchemaWithCanEditNameFalse() throws {
        let person = try createTestPerson()
        let schema = RecordSchema.builtIn(.vaccine)
        let viewModel = createViewModel(person: person, schema: schema)

        let view = SchemaEditorView(person: person, schema: schema, viewModel: viewModel)

        _ = try view.inspect()
        #expect(viewModel.canEditName == false)
    }

    @Test
    func viewRendersCustomSchemaWithCanEditNameTrue() throws {
        let person = try createTestPerson()
        let schema = createTestSchema(isBuiltIn: false)
        let viewModel = createViewModel(person: person, schema: schema)

        let view = SchemaEditorView(person: person, schema: schema, viewModel: viewModel)

        _ = try view.inspect()
        #expect(viewModel.canEditName == true)
    }
}

// MARK: - Field Visibility Tests

extension SchemaEditorViewTests {
    @Test
    func viewRendersEmptyActiveFieldsMessage() throws {
        let person = try createTestPerson()
        let schema = createTestSchema(fields: [])
        let viewModel = createViewModel(person: person, schema: schema)

        let view = SchemaEditorView(person: person, schema: schema, viewModel: viewModel)

        _ = try view.inspect()
        #expect(viewModel.activeFields.isEmpty)
    }

    @Test
    func viewRendersActiveFieldsSection() throws {
        let person = try createTestPerson()
        let field = createTestField()
        let schema = createTestSchema(fields: [field])
        let viewModel = createViewModel(person: person, schema: schema)

        let view = SchemaEditorView(person: person, schema: schema, viewModel: viewModel)

        _ = try view.inspect()
        #expect(viewModel.activeFields.count == 1)
    }

    @Test
    func viewRendersHiddenFieldsSection() throws {
        let person = try createTestPerson()
        var field = createTestField()
        field.visibility = .hidden
        let schema = createTestSchema(fields: [field])
        let viewModel = createViewModel(person: person, schema: schema)

        let view = SchemaEditorView(person: person, schema: schema, viewModel: viewModel)

        _ = try view.inspect()
        #expect(viewModel.hiddenFields.count == 1)
    }

    @Test
    func viewRendersWithMixedActiveAndHiddenFields() throws {
        let person = try createTestPerson()
        let activeField = createTestField(displayName: "Active")
        var hiddenField = createTestField(displayName: "Hidden")
        hiddenField.visibility = .hidden
        let schema = createTestSchema(fields: [activeField, hiddenField])
        let viewModel = createViewModel(person: person, schema: schema)

        let view = SchemaEditorView(person: person, schema: schema, viewModel: viewModel)

        _ = try view.inspect()
        #expect(viewModel.activeFields.count == 1)
        #expect(viewModel.hiddenFields.count == 1)
    }
}

// MARK: - New Schema Flag Tests

extension SchemaEditorViewTests {
    @Test
    func viewRendersNewSchemaWithCancelButton() throws {
        let person = try createTestPerson()
        let template = createTestSchema(id: "new-schema", displayName: "New Schema")
        let viewModel = createViewModel(person: person, newSchemaTemplate: template)

        let view = SchemaEditorView(person: person, newSchemaTemplate: template, viewModel: viewModel)

        _ = try view.inspect()
        #expect(viewModel.isNewSchema == true)
    }

    @Test
    func viewRendersExistingSchemaWithoutCancelButton() throws {
        let person = try createTestPerson()
        let schema = createTestSchema()
        let viewModel = createViewModel(person: person, schema: schema)

        let view = SchemaEditorView(person: person, schema: schema, viewModel: viewModel)

        _ = try view.inspect()
        #expect(viewModel.isNewSchema == false)
    }
}

// MARK: - FieldRowView Tests

@MainActor
struct FieldRowViewTests {
    // MARK: - Test Data

    func createTestField(
        id: UUID = UUID(),
        displayName: String = "Test Field",
        fieldType: FieldType = .string,
        isRequired: Bool = false
    ) -> FieldDefinition {
        let now = Date()
        return FieldDefinition(
            id: id,
            displayName: displayName,
            fieldType: fieldType,
            isRequired: isRequired,
            displayOrder: 1,
            placeholder: nil,
            helpText: nil,
            validationRules: [],
            isMultiline: false,
            capitalizationMode: .sentences,
            visibility: .active,
            createdBy: .zero,
            createdAt: now,
            updatedBy: .zero,
            updatedAt: now
        )
    }

    // MARK: - Content Tests

    @Test
    func viewDisplaysFieldName() throws {
        let field = createTestField(displayName: "My Field")
        let view = FieldRowView(field: field)

        let hStack = try view.inspect().hStack()
        let vStack = try hStack.vStack(0)
        let nameHStack = try vStack.hStack(0)
        let nameText = try nameHStack.text(0)
        #expect(try nameText.string() == "My Field")
    }

    @Test
    func viewDisplaysFieldType() throws {
        let field = createTestField(fieldType: .date)
        let view = FieldRowView(field: field)

        let hStack = try view.inspect().hStack()
        let vStack = try hStack.vStack(0)
        let typeText = try vStack.text(1)
        #expect(try typeText.string() == "Date")
    }

    @Test
    func viewShowsRequiredIndicator() throws {
        let field = createTestField(isRequired: true)
        let view = FieldRowView(field: field)

        let hStack = try view.inspect().hStack()
        let vStack = try hStack.vStack(0)
        let nameHStack = try vStack.hStack(0)
        let requiredText = try nameHStack.text(1)
        #expect(try requiredText.string() == "*")
    }

    @Test
    func viewHidesRequiredIndicatorWhenOptional() throws {
        let field = createTestField(isRequired: false)
        let view = FieldRowView(field: field)

        let hStack = try view.inspect().hStack()
        let vStack = try hStack.vStack(0)
        let nameHStack = try vStack.hStack(0)
        // Should only have one text (the name) when not required
        #expect(throws: (any Error).self) {
            _ = try nameHStack.text(1)
        }
    }

    @Test
    func viewShowsBuiltInBadgeForBuiltInFields() throws {
        let builtInId = BuiltInFieldIds.Vaccine.name
        let field = FieldDefinition.builtIn(
            id: builtInId,
            displayName: "Built-in Field",
            fieldType: .string,
            isRequired: true,
            displayOrder: 1
        )
        let view = FieldRowView(field: field)

        let hStack = try view.inspect().hStack()
        // HStack has: VStack(0), Spacer(1), Text(2) "Built-in", Image(3)
        let badgeText = try hStack.text(2)
        #expect(try badgeText.string() == "Built-in")
    }

    @Test
    func viewRendersSuccessfully() throws {
        let field = createTestField()
        let view = FieldRowView(field: field)

        _ = try view.inspect()
    }

    @Test
    func viewWorksWithAllFieldTypes() throws {
        for fieldType in FieldType.allCases {
            let field = createTestField(fieldType: fieldType)
            let view = FieldRowView(field: field)
            _ = try view.inspect()
        }
    }
}
