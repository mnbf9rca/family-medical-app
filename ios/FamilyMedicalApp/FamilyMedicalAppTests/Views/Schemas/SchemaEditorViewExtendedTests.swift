import CryptoKit
import Dependencies
import SwiftUI
import Testing
import ViewInspector
@testable import FamilyMedicalApp

/// Extended tests for SchemaEditorView - Schema Icon, Built-in Field, and Change Tracking tests
@MainActor
struct SchemaEditorViewExtendedTests {
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

    // MARK: - Schema Icon Tests

    @Test
    func viewRendersWithDifferentIcons() throws {
        let person = try createTestPerson()
        let icons = ["doc.text", "heart.fill", "cross.case", "pills", "syringe"]

        for icon in icons {
            let schema = RecordSchema(
                unsafeId: "icon-test-\(icon)",
                displayName: "Schema with \(icon)",
                iconSystemName: icon,
                fields: [],
                isBuiltIn: false,
                description: nil
            )
            let view = SchemaEditorView(person: person, schema: schema)
            _ = try view.inspect()
        }
    }
}

// MARK: - Built-in Field Tests

extension SchemaEditorViewExtendedTests {
    @Test
    func viewRendersBuiltInFieldsCorrectly() throws {
        let person = try createTestPerson()
        let schema = RecordSchema.builtIn(.vaccine)
        let viewModel = createViewModel(person: person, schema: schema)

        let view = SchemaEditorView(person: person, schema: schema, viewModel: viewModel)

        _ = try view.inspect()
        #expect(viewModel.activeFields.isEmpty == false)
    }

    @Test
    func viewRendersWithBuiltInAndCustomFields() throws {
        let person = try createTestPerson()
        let schema = RecordSchema.builtIn(.vaccine)
        let viewModel = createViewModel(person: person, schema: schema)

        let customField = createTestField(displayName: "Custom Field")
        viewModel.addField(customField)

        let view = SchemaEditorView(person: person, schema: schema, viewModel: viewModel)

        _ = try view.inspect()
        #expect(viewModel.activeFields.count > 1)
    }
}

// MARK: - Has Unsaved Changes Tests

extension SchemaEditorViewExtendedTests {
    @Test
    func viewRendersWithNoUnsavedChanges() throws {
        let person = try createTestPerson()
        let schema = createTestSchema()
        let viewModel = createViewModel(person: person, schema: schema)

        let view = SchemaEditorView(person: person, schema: schema, viewModel: viewModel)

        _ = try view.inspect()
        #expect(viewModel.hasUnsavedChanges == false)
    }

    @Test
    func viewRendersWithUnsavedChanges() throws {
        let person = try createTestPerson()
        let schema = createTestSchema()
        let viewModel = createViewModel(person: person, schema: schema)
        viewModel.displayName = "Modified Name"

        let view = SchemaEditorView(person: person, schema: schema, viewModel: viewModel)

        _ = try view.inspect()
        #expect(viewModel.hasUnsavedChanges == true)
    }
}

// MARK: - Did Save Successfully Tests

extension SchemaEditorViewExtendedTests {
    @Test
    func viewRendersWithDidSaveSuccessfullyFalse() throws {
        let person = try createTestPerson()
        let schema = createTestSchema()
        let viewModel = createViewModel(person: person, schema: schema)

        let view = SchemaEditorView(person: person, schema: schema, viewModel: viewModel)

        _ = try view.inspect()
        #expect(viewModel.didSaveSuccessfully == false)
    }
}
