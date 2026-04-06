import CryptoKit
import SwiftUI
import Testing
import ViewInspector
@testable import FamilyMedicalApp

/// Tests for MedicalRecordDetailView
/// MedicalRecordFormView and MedicalRecordFormViewModel tests have been removed
/// as those types were deleted during FHIR migration.
@MainActor
struct MedicalRecordFormDetailViewTests {
    // MARK: - Test Data

    let testPrimaryKey = SymmetricKey(size: .bits256)
    let testFMK = SymmetricKey(size: .bits256)

    func makeTestPerson() throws -> Person {
        try PersonTestHelper.makeTestPerson()
    }

    func makeTestDecryptedRecord(
        personId: UUID? = nil,
        recordType: RecordType = .immunization
    ) throws -> DecryptedRecord {
        let envelope: RecordContentEnvelope = switch recordType {
        case .immunization:
            try RecordContentEnvelope(
                ImmunizationRecord(
                    vaccineCode: "Test Vaccine",
                    occurrenceDate: Date(),
                    lotNumber: "EL9262",
                    doseNumber: 2,
                    notes: "Second dose"
                )
            )
        case .condition:
            try RecordContentEnvelope(
                ConditionRecord(conditionName: "Asthma", onsetDate: Date())
            )
        case .medicationStatement:
            try RecordContentEnvelope(
                MedicationStatementRecord(medicationName: "Aspirin")
            )
        default:
            RecordContentEnvelope(
                recordType: recordType,
                schemaVersion: 1,
                content: Data("{\"notes\":null,\"tags\":[]}".utf8)
            )
        }

        let record = MedicalRecord(personId: personId ?? UUID(), encryptedContent: Data())
        return DecryptedRecord(record: record, envelope: envelope)
    }

    // MARK: - MedicalRecordDetailView Tests

    @Test(arguments: RecordType.allCases)
    func medicalRecordDetailViewRendersForRecordType(_ recordType: RecordType) throws {
        let person = try makeTestPerson()
        let decryptedRecord = try makeTestDecryptedRecord(recordType: recordType)

        let view = MedicalRecordDetailView(
            person: person,
            decryptedRecord: decryptedRecord
        )
        // Use find() for deterministic coverage
        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            _ = try inspected.find(ViewType.List.self)
        }
    }

    @Test
    func medicalRecordDetailViewRendersContent() throws {
        let person = try makeTestPerson()
        let decryptedRecord = try makeTestDecryptedRecord(recordType: .immunization)

        let view = MedicalRecordDetailView(
            person: person,
            decryptedRecord: decryptedRecord
        )

        try HostedInspection.inspect(view) { view in
            let inspectedView = try view.inspect()
            _ = try inspectedView.find(ViewType.List.self)
        }
    }

    @Test
    func medicalRecordDetailViewRendersWithCallbacks() throws {
        let person = try makeTestPerson()
        let decryptedRecord = try makeTestDecryptedRecord()

        var deleteCallbackProvided = false
        var updateCallbackProvided = false

        let view = MedicalRecordDetailView(
            person: person,
            decryptedRecord: decryptedRecord,
            onDelete: {
                deleteCallbackProvided = true
            },
            onRecordUpdated: {
                updateCallbackProvided = true
            }
        )

        // Use find() for deterministic coverage
        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            _ = try inspected.find(ViewType.List.self)
        }

        // Callbacks are provided but not triggered during render
        #expect(deleteCallbackProvided == false)
        #expect(updateCallbackProvided == false)
    }

    @Test
    func medicalRecordDetailViewRendersWithoutCallbacks() throws {
        let person = try makeTestPerson()
        let decryptedRecord = try makeTestDecryptedRecord()

        // View should render without callbacks (nil defaults)
        let view = MedicalRecordDetailView(
            person: person,
            decryptedRecord: decryptedRecord
        )

        // Use find() for deterministic coverage
        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            _ = try inspected.find(ViewType.List.self)
        }
    }

    // MARK: - Extra coverage tests

    @Test
    func viewRendersUnknownFieldsSection() throws {
        let person = try makeTestPerson()
        // Craft content JSON with an unrecognized key for forward compatibility
        let json = "{\"vaccineCode\":\"X\",\"occurrenceDate\":0,\"tags\":[],\"futureField\":\"xx\"}"
        let envelope = RecordContentEnvelope(
            recordType: .immunization,
            schemaVersion: 1,
            content: Data(json.utf8)
        )
        let record = MedicalRecord(personId: person.id, encryptedContent: Data())
        let decrypted = DecryptedRecord(record: record, envelope: envelope)
        let view = MedicalRecordDetailView(person: person, decryptedRecord: decrypted)

        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            _ = try inspected.find(text: "Additional Fields")
            _ = try inspected.find(text: "futureField")
        }
    }

    @Test
    func viewRendersEditToolbarButton() throws {
        let person = try makeTestPerson()
        let decryptedRecord = try makeTestDecryptedRecord(recordType: .immunization)
        let view = MedicalRecordDetailView(person: person, decryptedRecord: decryptedRecord)

        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            _ = try inspected.find(button: "Edit")
        }
    }

    @Test
    func viewRendersDeleteToolbarButton() throws {
        let person = try makeTestPerson()
        let decryptedRecord = try makeTestDecryptedRecord(recordType: .immunization)
        let view = MedicalRecordDetailView(person: person, decryptedRecord: decryptedRecord)

        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            _ = try inspected.find(button: "Delete")
        }
    }

    @Test
    func viewRendersDetailRowForDateField() throws {
        let person = try makeTestPerson()
        let fixedDate = Date(timeIntervalSinceReferenceDate: 600_000_000)
        let envelope = try RecordContentEnvelope(
            ImmunizationRecord(
                vaccineCode: "Pfizer",
                occurrenceDate: fixedDate,
                lotNumber: "LOT123"
            )
        )
        let record = MedicalRecord(personId: person.id, encryptedContent: Data())
        let decrypted = DecryptedRecord(record: record, envelope: envelope)
        let view = MedicalRecordDetailView(person: person, decryptedRecord: decrypted)

        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            // Ensure the typed fields section rendered
            _ = try inspected.find(text: "Date Administered")
            _ = try inspected.find(text: "Lot Number")
            _ = try inspected.find(text: "LOT123")
        }
    }

    @Test
    func viewRendersDetailRowForComponentsField() throws {
        let person = try makeTestPerson()
        let envelope = try RecordContentEnvelope(
            ObservationRecord(
                observationType: "Blood Pressure",
                components: [
                    ObservationComponent(name: "Systolic", value: 120, unit: "mmHg"),
                    ObservationComponent(name: "Diastolic", value: 80, unit: "mmHg")
                ],
                effectiveDate: Date()
            )
        )
        let record = MedicalRecord(personId: person.id, encryptedContent: Data())
        let decrypted = DecryptedRecord(record: record, envelope: envelope)
        let view = MedicalRecordDetailView(person: person, decryptedRecord: decrypted)

        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            _ = try inspected.find(text: "Measurements")
            // A row combining the two components should contain both names
            _ = try inspected.find { view in
                guard let text = try? view.text().string() else { return false }
                return text.contains("Systolic: 120.0 mmHg") && text.contains("Diastolic: 80.0 mmHg")
            }
        }
    }

    @Test
    func viewRendersDetailRowForTagsField() throws {
        let person = try makeTestPerson()
        let envelope = try RecordContentEnvelope(
            ImmunizationRecord(
                vaccineCode: "Pfizer",
                occurrenceDate: Date(),
                tags: ["covid", "booster"]
            )
        )
        let record = MedicalRecord(personId: person.id, encryptedContent: Data())
        let decrypted = DecryptedRecord(record: record, envelope: envelope)
        let view = MedicalRecordDetailView(person: person, decryptedRecord: decrypted)

        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            _ = try inspected.find(text: "covid, booster")
        }
    }
}
