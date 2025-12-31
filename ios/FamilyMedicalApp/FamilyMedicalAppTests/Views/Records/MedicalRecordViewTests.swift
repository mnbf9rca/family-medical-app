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
    var testSchema: RecordSchema { ExampleSchema.comprehensiveExample }

    /// Schema ID for the comprehensive example schema
    var testSchemaId: String { "comprehensive_example" }

    /// Required string field ID in the comprehensive schema
    var requiredStringFieldId: String { "exampleName" }

    /// Required date field ID in the comprehensive schema
    var requiredDateFieldId: String { "recordedDate" }

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
        #expect(content.getString("notes") == nil)
    }

    @Test
    func medicalRecordRowViewRendersForAllSchemaTypes() {
        for schemaType in BuiltInSchemaType.allCases {
            let schema = RecordSchema.builtIn(schemaType)
            var content = RecordContent(schemaId: schemaType.rawValue)
            content.setDate("dateAdministered", Date())

            let view = MedicalRecordRowView(schema: schema, content: content)
            _ = view.body
        }
    }

    // MARK: - EmptyRecordListView Integration Tests
    // Note: EmptyRecordListView requires BuiltInSchemaType, so these are integration tests

    @Test
    func emptyRecordListViewRendersForAllSchemaTypes() {
        for schemaType in BuiltInSchemaType.allCases {
            let view = EmptyRecordListView(schemaType: schemaType) {}
            _ = view.body
        }
    }

    @Test
    func emptyRecordListViewCallbackNotTriggeredOnRender() {
        var wasCallbackCalled = false
        let view = EmptyRecordListView(schemaType: .vaccine) {
            wasCallbackCalled = true
        }

        _ = view.body

        #expect(wasCallbackCalled == false)
    }
}
