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
/// All dispatch is compile-time — `displayName`/`iconSystemName` delegate to
/// the `RecordType` extension, and `fieldMetadata` switches on `RecordType`
/// directly. Adding a new `RecordType` case is a compile error until every
/// switch is updated, so there are no silent-fallback or runtime-crash paths.
final class RecordTypeRegistry: RecordTypeRegistryProtocol, Sendable {
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
        switch recordType {
        case .immunization: ImmunizationRecord.fieldMetadata
        case .medicationStatement: MedicationStatementRecord.fieldMetadata
        case .allergyIntolerance: AllergyIntoleranceRecord.fieldMetadata
        case .condition: ConditionRecord.fieldMetadata
        case .observation: ObservationRecord.fieldMetadata
        case .procedure: ProcedureRecord.fieldMetadata
        case .documentReference: DocumentReferenceRecord.fieldMetadata
        case .familyMemberHistory: FamilyMemberHistoryRecord.fieldMetadata
        case .clinicalNote: ClinicalNoteRecord.fieldMetadata
        }
    }
}
