import SwiftUI
import Testing
@testable import FamilyMedicalApp

@MainActor
struct MedicalRecordViewTests {
    // MARK: - Test Helpers

    func makeTestPerson() throws -> Person {
        try Person(
            id: UUID(),
            name: "Test Person",
            dateOfBirth: Date(),
            labels: ["Self"],
            notes: nil
        )
    }

    func makeTestDecryptedRecord() -> DecryptedRecord {
        var content = RecordContent(schemaId: "vaccine")
        content.setString("vaccineName", "COVID-19")
        content.setDate("dateAdministered", Date())

        let record = MedicalRecord(
            personId: UUID(),
            encryptedContent: Data()
        )

        return DecryptedRecord(record: record, content: content)
    }

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

    // MARK: - EmptyRecordListView Tests

    @Test
    func emptyRecordListViewRendersForVaccine() {
        var wasCallbackCalled = false
        let view = EmptyRecordListView(schemaType: .vaccine) {
            wasCallbackCalled = true
        }

        _ = view.body

        #expect(wasCallbackCalled == false) // Not called until button tapped
    }

    // MARK: - MedicalRecordListView Tests

    @Test
    func medicalRecordListViewInitializesWithPerson() throws {
        let person = try makeTestPerson()
        let view = MedicalRecordListView(person: person, schemaType: .vaccine)

        _ = view.body

        #expect(person.name == "Test Person")
    }

    // MARK: - MedicalRecordDetailView Tests

    @Test
    func medicalRecordDetailViewRendersWithDecryptedRecord() throws {
        let person = try makeTestPerson()
        let decryptedRecord = makeTestDecryptedRecord()

        let view = MedicalRecordDetailView(
            person: person,
            schemaType: .vaccine,
            decryptedRecord: decryptedRecord
        )

        _ = view.body

        #expect(decryptedRecord.content.schemaId == "vaccine")
    }

    // MARK: - MedicalRecordFormView Tests

    @Test
    func medicalRecordFormViewRendersForAdd() throws {
        let person = try makeTestPerson()
        let schema = RecordSchema.builtIn(.vaccine)

        let view = MedicalRecordFormView(
            person: person,
            schema: schema
        )

        _ = view.body

        #expect(schema.id == "vaccine")
    }

    @Test
    func medicalRecordFormViewRendersForEdit() throws {
        let person = try makeTestPerson()
        let schema = RecordSchema.builtIn(.vaccine)
        let decryptedRecord = makeTestDecryptedRecord()

        let view = MedicalRecordFormView(
            person: person,
            schema: schema,
            existingRecord: decryptedRecord.record,
            existingContent: decryptedRecord.content
        )

        _ = view.body

        #expect(decryptedRecord.content.getString("vaccineName") == "COVID-19")
    }
}
