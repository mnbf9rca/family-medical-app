import Foundation

/// Protocol for record type metadata access
protocol RecordTypeRegistryProtocol: Sendable {
    func displayName(for recordType: RecordType) -> String
    func iconSystemName(for recordType: RecordType) -> String
    func fieldMetadata(for recordType: RecordType) -> [FieldMetadata]
    var allRecordTypes: [RecordType] { get }
}

/// Simple registry that returns static metadata from record type structs.
/// Replaces the old SchemaService which fetched per-person encrypted schemas.
final class RecordTypeRegistry: RecordTypeRegistryProtocol, Sendable {
    private let typeMap: [RecordType: any MedicalRecordContent.Type] = [
        .immunization: ImmunizationRecord.self,
        .medicationStatement: MedicationStatementRecord.self,
        .allergyIntolerance: AllergyIntoleranceRecord.self,
        .condition: ConditionRecord.self,
        .observation: ObservationRecord.self,
        .procedure: ProcedureRecord.self,
        .documentReference: DocumentReferenceRecord.self,
        .familyMemberHistory: FamilyMemberHistoryRecord.self,
        .clinicalNote: ClinicalNoteRecord.self
    ]

    var allRecordTypes: [RecordType] {
        RecordType.allCases
    }

    func displayName(for recordType: RecordType) -> String {
        typeMap[recordType]?.displayName ?? recordType.rawValue
    }

    func iconSystemName(for recordType: RecordType) -> String {
        typeMap[recordType]?.iconSystemName ?? "doc"
    }

    func fieldMetadata(for recordType: RecordType) -> [FieldMetadata] {
        typeMap[recordType]?.fieldMetadata ?? []
    }
}
