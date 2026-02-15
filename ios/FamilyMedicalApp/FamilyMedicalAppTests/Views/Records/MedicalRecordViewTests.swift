import SwiftUI
import Testing
@testable import FamilyMedicalApp

/// Tests for MedicalRecordRowView and EmptyRecordListView
/// MedicalRecordRowView tests use generic schema (ExampleSchema.comprehensiveExample).
/// EmptyRecordListView requires BuiltInSchemaType, so those are integration tests.
@MainActor
struct MedicalRecordViewTests {
    // MARK: - Test Helpers

    /// Returns the comprehensive example schema that exercises all field types
    var testSchema: RecordSchema {
        ExampleSchema.comprehensiveExample
    }

    /// Schema ID for the comprehensive example schema
    var testSchemaId: String {
        "comprehensive_example"
    }

    /// Required string field UUID in the comprehensive schema
    var requiredStringFieldId: UUID {
        ExampleSchema.FieldIds.exampleName
    }

    /// Required date field UUID in the comprehensive schema
    var requiredDateFieldId: UUID {
        ExampleSchema.FieldIds.recordedDate
    }

    // MARK: - MedicalRecordRowView Tests (using generic schema)

    @Test
    func medicalRecordRowViewRendersWithContent() {
        var content = RecordContent(schemaId: testSchemaId)
        content.setString(requiredStringFieldId, "Test Record")

        let view = MedicalRecordRowView(schema: testSchema, content: content)

        _ = view.body

        #expect(content.getString(requiredStringFieldId) == "Test Record")
    }

    @Test
    func medicalRecordRowViewRendersWithDate() {
        var content = RecordContent(schemaId: testSchemaId)
        content.setString(requiredStringFieldId, "Test Record")
        content.setDate(requiredDateFieldId, Date())

        let view = MedicalRecordRowView(schema: testSchema, content: content)
        _ = view.body

        #expect(content.getDate(requiredDateFieldId) != nil)
    }

    @Test
    func medicalRecordRowViewRendersWithoutOptionalFields() {
        var content = RecordContent(schemaId: testSchemaId)
        content.setString(requiredStringFieldId, "Test Record")

        let view = MedicalRecordRowView(schema: testSchema, content: content)
        _ = view.body

        // Optional fields should be nil
        #expect(content.getString(ExampleSchema.FieldIds.notes) == nil)
    }

    // MARK: - Parameterized Schema Type Tests
    //
    // Using @Test(arguments:) instead of manual loops provides:
    // - Clear test names showing which schema type failed
    // - Parallel execution of independent test cases
    // - Better test reporting in Xcode and CI

    @Test(arguments: BuiltInSchemaType.allCases)
    func medicalRecordRowViewRendersForSchemaType(_ schemaType: BuiltInSchemaType) {
        let schema = RecordSchema.builtIn(schemaType)
        var content = RecordContent(schemaId: schemaType.rawValue)
        content.setDate(BuiltInFieldIds.Vaccine.dateAdministered, Date())

        let view = MedicalRecordRowView(schema: schema, content: content)
        _ = view.body
    }

    // MARK: - EmptyRecordListView Integration Tests

    @Test(arguments: BuiltInSchemaType.allCases)
    func emptyRecordListViewRendersForSchemaType(_ schemaType: BuiltInSchemaType) {
        let view = EmptyRecordListView(schema: RecordSchema.builtIn(schemaType)) {}
        _ = view.body
    }

    @Test
    func emptyRecordListViewCallbackNotTriggeredOnRender() {
        var wasCallbackCalled = false
        let view = EmptyRecordListView(schema: RecordSchema.builtIn(.vaccine)) {
            wasCallbackCalled = true
        }

        _ = view.body

        #expect(wasCallbackCalled == false)
    }
}
