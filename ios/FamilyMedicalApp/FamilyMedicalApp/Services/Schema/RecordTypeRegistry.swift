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
///
/// `displayName` and `iconSystemName` delegate to the `RecordType` extension
/// (single source of truth). `fieldMetadata` dispatches through `typeMap`.
/// The init verifies `typeMap` covers every `RecordType` case so missing
/// entries fail at startup instead of silently returning empty metadata.
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

    init() {
        precondition(
            Set(typeMap.keys) == Set(RecordType.allCases),
            "RecordTypeRegistry.typeMap must contain an entry for every RecordType case"
        )
    }

    var allRecordTypes: [RecordType] {
        RecordType.allCases
    }

    func displayName(for recordType: RecordType) -> String {
        recordType.displayName
    }

    func iconSystemName(for recordType: RecordType) -> String {
        recordType.iconSystemName
    }

    func fieldMetadata(for recordType: RecordType) -> [FieldMetadata] {
        guard let type = typeMap[recordType] else {
            preconditionFailure("RecordTypeRegistry missing typeMap entry for \(recordType)")
        }
        return type.fieldMetadata
    }
}
