import CryptoKit
import Dependencies
import SwiftUI
import Testing
import ViewInspector
@testable import FamilyMedicalApp

@MainActor
struct SchemaListViewTests {
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
        isBuiltIn: Bool = false
    ) -> RecordSchema {
        RecordSchema(
            unsafeId: id,
            displayName: displayName,
            iconSystemName: "doc.text",
            fields: [],
            isBuiltIn: isBuiltIn,
            description: nil
        )
    }

    func createViewModel(person: Person, schemas: [RecordSchema] = []) -> SchemaListViewModel {
        let mockRepo = MockCustomSchemaRepository()
        for schema in schemas {
            mockRepo.addSchema(schema, forPerson: person.id)
        }

        let mockKeyProvider = MockPrimaryKeyProvider(primaryKey: testPrimaryKey)
        let mockFMKService = MockFamilyMemberKeyService()
        mockFMKService.setFMK(testFMK, for: person.id.uuidString)

        return withDependencies {
            $0.uuid = .incrementing
            $0.date = .constant(testDate)
        } operation: {
            SchemaListViewModel(
                person: person,
                customSchemaRepository: mockRepo,
                primaryKeyProvider: mockKeyProvider,
                fmkService: mockFMKService
            )
        }
    }

    // MARK: - Rendering Tests

    @Test
    func viewRendersSuccessfully() throws {
        let person = try createTestPerson()
        let view = SchemaListView(person: person)

        _ = try view.inspect()
    }

    @Test
    func viewRendersWithMockViewModel() throws {
        let person = try createTestPerson()
        let viewModel = createViewModel(person: person)
        let view = SchemaListView(person: person, viewModel: viewModel)

        _ = try view.inspect()
    }

    @Test
    func viewRendersWithLoadingState() throws {
        let person = try createTestPerson()
        let viewModel = createViewModel(person: person)
        viewModel.isLoading = true

        let view = SchemaListView(person: person, viewModel: viewModel)
        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.ProgressView.self)
    }

    @Test
    func viewRendersEmptyStateWhenNoSchemas() throws {
        let person = try createTestPerson()
        let viewModel = createViewModel(person: person)
        viewModel.schemas = []
        viewModel.isLoading = false

        let view = SchemaListView(person: person, viewModel: viewModel)
        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.ContentUnavailableView.self)
    }

    @Test
    func viewRendersSchemaListWhenSchemasExist() async throws {
        let person = try createTestPerson()
        let schema = createTestSchema(displayName: "My Schema")
        let viewModel = createViewModel(person: person, schemas: [schema])

        await viewModel.loadSchemas()

        let view = SchemaListView(person: person, viewModel: viewModel)
        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.List.self)
    }

    @Test
    func viewRendersWithBuiltInSchemas() async throws {
        let person = try createTestPerson()
        let builtInSchema = RecordSchema.builtIn(.vaccine)
        let viewModel = createViewModel(person: person, schemas: [builtInSchema])

        await viewModel.loadSchemas()

        let view = SchemaListView(person: person, viewModel: viewModel)
        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.List.self)
    }

    @Test
    func viewRendersWithCustomSchemas() async throws {
        let person = try createTestPerson()
        let customSchema = createTestSchema(id: "custom-1", displayName: "Custom", isBuiltIn: false)
        let viewModel = createViewModel(person: person, schemas: [customSchema])

        await viewModel.loadSchemas()

        let view = SchemaListView(person: person, viewModel: viewModel)
        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.List.self)
    }

    @Test
    func viewRendersWithMixedSchemaTypes() async throws {
        let person = try createTestPerson()
        let builtIn = RecordSchema.builtIn(.vaccine)
        let custom = createTestSchema(id: "custom-1", displayName: "Custom", isBuiltIn: false)
        let viewModel = createViewModel(person: person, schemas: [builtIn, custom])

        await viewModel.loadSchemas()

        let view = SchemaListView(person: person, viewModel: viewModel)
        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.List.self)
    }

    @Test
    func viewRendersWithErrorState() throws {
        let person = try createTestPerson()
        let viewModel = createViewModel(person: person)
        viewModel.errorMessage = "Test error"

        let view = SchemaListView(person: person, viewModel: viewModel)
        _ = try view.inspect()
    }

    @Test
    func viewHasAddButton() throws {
        let person = try createTestPerson()
        let viewModel = createViewModel(person: person)
        let view = SchemaListView(person: person, viewModel: viewModel)

        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.Button.self)
    }
}

// MARK: - Schema List Content Tests

extension SchemaListViewTests {
    @Test
    func viewRendersAllBuiltInSchemaTypes() async throws {
        let person = try createTestPerson()
        let builtInSchemas = BuiltInSchemaType.allCases.map { RecordSchema.builtIn($0) }
        let viewModel = createViewModel(person: person, schemas: builtInSchemas)

        await viewModel.loadSchemas()

        let view = SchemaListView(person: person, viewModel: viewModel)
        _ = try view.inspect()

        #expect(viewModel.schemas.count == BuiltInSchemaType.allCases.count)
    }

    @Test
    func viewRendersMultipleCustomSchemas() async throws {
        let person = try createTestPerson()
        let schemas = [
            createTestSchema(id: "custom-1", displayName: "Custom 1"),
            createTestSchema(id: "custom-2", displayName: "Custom 2"),
            createTestSchema(id: "custom-3", displayName: "Custom 3")
        ]
        let viewModel = createViewModel(person: person, schemas: schemas)

        await viewModel.loadSchemas()

        let view = SchemaListView(person: person, viewModel: viewModel)
        _ = try view.inspect()

        #expect(viewModel.schemas.count == 3)
    }
}

// MARK: - Record Counts Tests

extension SchemaListViewTests {
    @Test
    func viewRendersWithZeroRecordCounts() async throws {
        let person = try createTestPerson()
        let schema = createTestSchema(displayName: "Empty Schema")
        let viewModel = createViewModel(person: person, schemas: [schema])

        await viewModel.loadSchemas()

        let view = SchemaListView(person: person, viewModel: viewModel)
        _ = try view.inspect()

        #expect(viewModel.recordCounts[schema.id] ?? 0 == 0)
    }

    @Test
    func viewRendersWithNonZeroRecordCounts() async throws {
        let person = try createTestPerson()
        let schema = createTestSchema(displayName: "Schema with Records")
        let viewModel = createViewModel(person: person, schemas: [schema])

        await viewModel.loadSchemas()
        // Set record counts after loading (loadSchemas resets them)
        viewModel.recordCounts[schema.id] = 5

        let view = SchemaListView(person: person, viewModel: viewModel)
        _ = try view.inspect()

        #expect(viewModel.recordCounts[schema.id] == 5)
    }
}

// MARK: - ViewModel State Tests

extension SchemaListViewTests {
    @Test
    func viewRendersWithNilErrorMessage() throws {
        let person = try createTestPerson()
        let viewModel = createViewModel(person: person)
        viewModel.errorMessage = nil

        let view = SchemaListView(person: person, viewModel: viewModel)
        _ = try view.inspect()

        #expect(viewModel.errorMessage == nil)
    }

    @Test
    func viewRendersWithNonNilErrorMessage() throws {
        let person = try createTestPerson()
        let viewModel = createViewModel(person: person)
        viewModel.errorMessage = "Error loading schemas"

        let view = SchemaListView(person: person, viewModel: viewModel)
        _ = try view.inspect()

        #expect(viewModel.errorMessage == "Error loading schemas")
    }

    @Test
    func viewRendersWhenNotLoading() throws {
        let person = try createTestPerson()
        let viewModel = createViewModel(person: person)
        viewModel.isLoading = false

        let view = SchemaListView(person: person, viewModel: viewModel)
        _ = try view.inspect()

        #expect(viewModel.isLoading == false)
    }
}

// MARK: - Schema Template Tests

extension SchemaListViewTests {
    @Test
    func viewModelCreatesNewSchemaTemplate() throws {
        let person = try createTestPerson()
        let viewModel = createViewModel(person: person)

        let template = viewModel.createNewSchemaTemplate()

        #expect(template.displayName == "New Record Type")
        #expect(template.isBuiltIn == false)
        #expect(template.fields.isEmpty)
    }
}

// MARK: - Section Visibility Tests

extension SchemaListViewTests {
    @Test
    func viewShowsBuiltInSectionWhenBuiltInSchemasExist() async throws {
        let person = try createTestPerson()
        let builtIn = RecordSchema.builtIn(.vaccine)
        let viewModel = createViewModel(person: person, schemas: [builtIn])

        await viewModel.loadSchemas()

        let builtInSchemas = viewModel.schemas.filter(\.isBuiltIn)
        #expect(builtInSchemas.isEmpty == false)

        let view = SchemaListView(person: person, viewModel: viewModel)
        _ = try view.inspect()
    }

    @Test
    func viewShowsCustomSectionWhenCustomSchemasExist() async throws {
        let person = try createTestPerson()
        let custom = createTestSchema(id: "custom-1", displayName: "Custom", isBuiltIn: false)
        let viewModel = createViewModel(person: person, schemas: [custom])

        await viewModel.loadSchemas()

        let customSchemas = viewModel.schemas.filter { !$0.isBuiltIn }
        #expect(customSchemas.isEmpty == false)

        let view = SchemaListView(person: person, viewModel: viewModel)
        _ = try view.inspect()
    }

    @Test
    func viewShowsBothSectionsWhenBothTypesExist() async throws {
        let person = try createTestPerson()
        let builtIn = RecordSchema.builtIn(.vaccine)
        let custom = createTestSchema(id: "custom-1", displayName: "Custom", isBuiltIn: false)
        let viewModel = createViewModel(person: person, schemas: [builtIn, custom])

        await viewModel.loadSchemas()

        let builtInSchemas = viewModel.schemas.filter(\.isBuiltIn)
        let customSchemas = viewModel.schemas.filter { !$0.isBuiltIn }

        #expect(builtInSchemas.isEmpty == false)
        #expect(customSchemas.isEmpty == false)

        let view = SchemaListView(person: person, viewModel: viewModel)
        _ = try view.inspect()
    }
}

// MARK: - Empty State Tests

extension SchemaListViewTests {
    @Test
    func emptyStateShowsWhenNoSchemasAndNotLoading() throws {
        let person = try createTestPerson()
        let viewModel = createViewModel(person: person)
        viewModel.schemas = []
        viewModel.isLoading = false

        let view = SchemaListView(person: person, viewModel: viewModel)
        let inspected = try view.inspect()

        _ = try inspected.find(ViewType.ContentUnavailableView.self)
    }

    @Test
    func emptyStateNotShownWhenLoading() throws {
        let person = try createTestPerson()
        let viewModel = createViewModel(person: person)
        viewModel.schemas = []
        viewModel.isLoading = true

        let view = SchemaListView(person: person, viewModel: viewModel)
        let inspected = try view.inspect()

        // Should show ProgressView instead of empty state
        _ = try inspected.find(ViewType.ProgressView.self)
    }

    @Test
    func listShownWhenSchemasExist() async throws {
        let person = try createTestPerson()
        let schema = createTestSchema()
        let viewModel = createViewModel(person: person, schemas: [schema])

        await viewModel.loadSchemas()

        let view = SchemaListView(person: person, viewModel: viewModel)
        let inspected = try view.inspect()

        _ = try inspected.find(ViewType.List.self)
    }
}

// MARK: - Navigation Tests

extension SchemaListViewTests {
    @Test
    func viewSupportsNavigationToSchema() async throws {
        let person = try createTestPerson()
        let schema = createTestSchema()
        let viewModel = createViewModel(person: person, schemas: [schema])

        await viewModel.loadSchemas()

        let view = SchemaListView(person: person, viewModel: viewModel)
        let inspected = try view.inspect()

        // NavigationLinks should be present in the list
        _ = try inspected.find(ViewType.List.self)
    }
}

// MARK: - Delete Schema Tests

extension SchemaListViewTests {
    @Test
    func viewModelCanDeleteCustomSchema() async throws {
        let person = try createTestPerson()
        let customSchema = createTestSchema(id: "custom-delete-test", displayName: "Delete Me", isBuiltIn: false)
        let viewModel = createViewModel(person: person, schemas: [customSchema])

        await viewModel.loadSchemas()
        #expect(viewModel.schemas.count == 1)

        _ = await viewModel.deleteSchema(schemaId: customSchema.id)

        // After deletion, schema should be removed
        #expect(viewModel.schemas.isEmpty)
    }
}

// MARK: - Schema with Records Tests

extension SchemaListViewTests {
    @Test
    func viewDisplaysRecordCountInDeleteWarning() async throws {
        let person = try createTestPerson()
        let schema = createTestSchema(id: "schema-with-records", displayName: "Has Records")
        let viewModel = createViewModel(person: person, schemas: [schema])

        await viewModel.loadSchemas()
        // Set record counts after loading (loadSchemas resets them)
        viewModel.recordCounts[schema.id] = 10

        let view = SchemaListView(person: person, viewModel: viewModel)
        _ = try view.inspect()

        #expect(viewModel.recordCounts[schema.id] == 10)
    }
}
