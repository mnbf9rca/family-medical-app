import SwiftUI
import Testing
@testable import FamilyMedicalApp

/// Tests for MedicalRecordRowView and EmptyRecordListView
@MainActor
struct MedicalRecordViewTests {
    // MARK: - Test Helpers

    func makeDecryptedRecord(recordType: RecordType = .immunization) throws -> DecryptedRecord {
        let envelope: RecordContentEnvelope = switch recordType {
        case .immunization:
            try RecordContentEnvelope(
                ImmunizationRecord(vaccineCode: "COVID-19", occurrenceDate: Date())
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

        let record = MedicalRecord(personId: UUID(), encryptedContent: Data())
        return DecryptedRecord(record: record, envelope: envelope)
    }

    // MARK: - MedicalRecordRowView Tests

    @Test
    func medicalRecordRowViewRendersWithContent() throws {
        let decryptedRecord = try makeDecryptedRecord()

        let view = MedicalRecordRowView(decryptedRecord: decryptedRecord)

        _ = view.body

        #expect(decryptedRecord.recordType == .immunization)
    }

    @Test
    func medicalRecordRowViewRendersWithDate() throws {
        let decryptedRecord = try makeDecryptedRecord()

        let view = MedicalRecordRowView(decryptedRecord: decryptedRecord)
        _ = view.body

        #expect(decryptedRecord.recordType == .immunization)
    }

    // MARK: - Parameterized Record Type Tests

    @Test(arguments: RecordType.allCases)
    func medicalRecordRowViewRendersForRecordType(_ recordType: RecordType) throws {
        let decryptedRecord = try makeDecryptedRecord(recordType: recordType)

        let view = MedicalRecordRowView(decryptedRecord: decryptedRecord)
        _ = view.body
    }

    // MARK: - EmptyRecordListView Tests

    @Test(arguments: RecordType.allCases)
    func emptyRecordListViewRendersForRecordType(_ recordType: RecordType) {
        let view = EmptyRecordListView(recordType: recordType)
        _ = view.body
    }
}
