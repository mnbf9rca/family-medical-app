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
        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.List.self)
    }

    @Test
    func medicalRecordDetailViewRendersContent() throws {
        let person = try makeTestPerson()
        let decryptedRecord = try makeTestDecryptedRecord(recordType: .immunization)

        let view = MedicalRecordDetailView(
            person: person,
            decryptedRecord: decryptedRecord
        )

        let inspectedView = try view.inspect()
        _ = try inspectedView.find(ViewType.List.self)
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
        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.List.self)

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
        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.List.self)
    }
}
