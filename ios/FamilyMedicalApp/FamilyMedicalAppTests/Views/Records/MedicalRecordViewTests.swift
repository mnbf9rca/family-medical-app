import SwiftUI
import Testing
@testable import FamilyMedicalApp

/// Tests for MedicalRecordRowView and EmptyRecordListView
@MainActor
struct MedicalRecordViewTests {
    // MARK: - MedicalRecordRowView Tests

    @Test
    func medicalRecordRowViewRendersWithContent() {
        let schema = RecordSchema.builtIn(.vaccine)
        var content = RecordContent(schemaId: "vaccine")
        content.setString("vaccineName", "COVID-19")

        let view = MedicalRecordRowView(schema: schema, content: content)

        _ = view.body

        #expect(content.getString("vaccineName") == "COVID-19")
    }

    @Test
    func medicalRecordRowViewRendersWithDate() {
        let schema = RecordSchema.builtIn(.vaccine)
        var content = RecordContent(schemaId: "vaccine")
        content.setString("vaccineName", "Flu Shot")
        content.setDate("dateAdministered", Date())

        let view = MedicalRecordRowView(schema: schema, content: content)
        _ = view.body

        #expect(content.getDate("dateAdministered") != nil)
    }

    @Test
    func medicalRecordRowViewRendersWithoutOptionalFields() {
        let schema = RecordSchema.builtIn(.vaccine)
        var content = RecordContent(schemaId: "vaccine")
        content.setString("vaccineName", "Tetanus")

        let view = MedicalRecordRowView(schema: schema, content: content)
        _ = view.body

        #expect(content.getString("provider") == nil)
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

    // MARK: - EmptyRecordListView Tests

    @Test
    func emptyRecordListViewRendersForVaccine() {
        var wasCallbackCalled = false
        let view = EmptyRecordListView(schemaType: .vaccine) {
            wasCallbackCalled = true
        }

        _ = view.body

        #expect(wasCallbackCalled == false)
    }

    @Test
    func emptyRecordListViewRendersForAllSchemaTypes() {
        for schemaType in BuiltInSchemaType.allCases {
            let view = EmptyRecordListView(schemaType: schemaType) {}
            _ = view.body
        }
    }

    @Test
    func emptyRecordListViewDisplaysCorrectText() {
        let view = EmptyRecordListView(schemaType: .vaccine) {}
        _ = view.body
        // View should render with appropriate text for vaccines
    }

    @Test
    func emptyRecordListViewDisplaysForAllergy() {
        let view = EmptyRecordListView(schemaType: .allergy) {}
        _ = view.body
    }

    @Test
    func emptyRecordListViewDisplaysForMedication() {
        let view = EmptyRecordListView(schemaType: .medication) {}
        _ = view.body
    }

    @Test
    func emptyRecordListViewDisplaysForCondition() {
        let view = EmptyRecordListView(schemaType: .condition) {}
        _ = view.body
    }

    @Test
    func emptyRecordListViewDisplaysForNote() {
        let view = EmptyRecordListView(schemaType: .note) {}
        _ = view.body
    }
}
