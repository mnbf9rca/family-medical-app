import SwiftUI
import Testing
@testable import FamilyMedicalApp

@MainActor
struct FieldDisplayViewTests {
    // MARK: - String Value Tests

    @Test
    func fieldDisplayViewDisplaysStringValue() {
        let field = FieldDefinition(
            id: "vaccineName",
            displayName: "Vaccine Name",
            fieldType: .string
        )
        let value: FieldValue? = .string("COVID-19")
        let view = FieldDisplayView(field: field, value: value)

        _ = view.body

        #expect(value?.stringValue == "COVID-19")
    }

    // MARK: - Int Value Tests

    @Test
    func fieldDisplayViewDisplaysIntValue() {
        let field = FieldDefinition(
            id: "doseNumber",
            displayName: "Dose Number",
            fieldType: .int
        )
        let value: FieldValue? = .int(2)
        let view = FieldDisplayView(field: field, value: value)

        _ = view.body

        #expect(value?.intValue == 2)
    }

    // MARK: - Double Value Tests

    @Test
    func fieldDisplayViewDisplaysDoubleValue() {
        let field = FieldDefinition(
            id: "temperature",
            displayName: "Temperature",
            fieldType: .double
        )
        let value: FieldValue? = .double(98.6)
        let view = FieldDisplayView(field: field, value: value)

        _ = view.body

        #expect(value?.doubleValue == 98.6)
    }

    // MARK: - Bool Value Tests

    @Test
    func fieldDisplayViewDisplaysBoolValueTrue() {
        let field = FieldDefinition(
            id: "isActive",
            displayName: "Is Active",
            fieldType: .bool
        )
        let value: FieldValue? = .bool(true)
        let view = FieldDisplayView(field: field, value: value)

        _ = view.body

        #expect(value?.boolValue == true)
    }

    @Test
    func fieldDisplayViewDisplaysBoolValueFalse() {
        let field = FieldDefinition(
            id: "isActive",
            displayName: "Is Active",
            fieldType: .bool
        )
        let value: FieldValue? = .bool(false)
        let view = FieldDisplayView(field: field, value: value)

        _ = view.body

        #expect(value?.boolValue == false)
    }

    // MARK: - Date Value Tests

    @Test
    func fieldDisplayViewDisplaysDateValue() {
        let field = FieldDefinition(
            id: "dateAdministered",
            displayName: "Date Administered",
            fieldType: .date
        )
        let testDate = Date()
        let value: FieldValue? = .date(testDate)
        let view = FieldDisplayView(field: field, value: value)

        _ = view.body

        #expect(value?.dateValue == testDate)
    }

    // MARK: - Attachment IDs Tests

    @Test
    func fieldDisplayViewDisplaysAttachmentCount() {
        let field = FieldDefinition(
            id: "attachmentIds",
            displayName: "Attachments",
            fieldType: .attachmentIds
        )
        let ids = [UUID(), UUID(), UUID()]
        let value: FieldValue? = .attachmentIds(ids)
        let view = FieldDisplayView(field: field, value: value)

        _ = view.body

        #expect(value?.attachmentIdsValue?.count == 3)
    }

    @Test
    func fieldDisplayViewDisplaysEmptyAttachments() {
        let field = FieldDefinition(
            id: "attachmentIds",
            displayName: "Attachments",
            fieldType: .attachmentIds
        )
        let value: FieldValue? = .attachmentIds([])
        let view = FieldDisplayView(field: field, value: value)

        _ = view.body

        #expect(value?.attachmentIdsValue?.isEmpty == true)
    }

    // MARK: - String Array Tests

    @Test
    func fieldDisplayViewDisplaysStringArray() {
        let field = FieldDefinition(
            id: "tags",
            displayName: "Tags",
            fieldType: .stringArray
        )
        let value: FieldValue? = .stringArray(["Important", "Follow-up"])
        let view = FieldDisplayView(field: field, value: value)

        _ = view.body

        #expect(value?.stringArrayValue == ["Important", "Follow-up"])
    }

    @Test
    func fieldDisplayViewDisplaysEmptyStringArray() {
        let field = FieldDefinition(
            id: "tags",
            displayName: "Tags",
            fieldType: .stringArray
        )
        let value: FieldValue? = .stringArray([])
        let view = FieldDisplayView(field: field, value: value)

        _ = view.body

        #expect(value?.stringArrayValue?.isEmpty == true)
    }

    // MARK: - Nil Value Tests

    @Test
    func fieldDisplayViewHandlesNilValue() {
        let field = FieldDefinition(
            id: "notes",
            displayName: "Notes",
            fieldType: .string
        )
        let value: FieldValue? = nil
        let view = FieldDisplayView(field: field, value: value)

        _ = view.body

        #expect(value == nil)
    }

    // MARK: - Field Definition Tests

    @Test
    func fieldDisplayViewUsesFieldDisplayName() {
        let field = FieldDefinition(
            id: "testId",
            displayName: "Test Display Name",
            fieldType: .string
        )
        let view = FieldDisplayView(field: field, value: nil)

        _ = view.body

        #expect(field.displayName == "Test Display Name")
    }
}
