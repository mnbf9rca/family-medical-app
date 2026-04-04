import Foundation

// MARK: - RecordType Enum

enum RecordType: String, Codable, CaseIterable {
    case immunization
    case medicationStatement
    case allergyIntolerance
    case condition
    case observation
    case procedure
    case documentReference
    case familyMemberHistory
    case clinicalNote
}

// MARK: - RecordType Display Properties

extension RecordType {
    var displayName: String {
        switch self {
        case .immunization: "Immunization"
        case .medicationStatement: "Medication"
        case .allergyIntolerance: "Allergy"
        case .condition: "Condition"
        case .observation: "Observation"
        case .procedure: "Procedure"
        case .documentReference: "Document"
        case .familyMemberHistory: "Family History"
        case .clinicalNote: "Note"
        }
    }

    var iconSystemName: String {
        switch self {
        case .immunization: "syringe"
        case .medicationStatement: "pills"
        case .allergyIntolerance: "allergens"
        case .condition: "heart.text.clipboard"
        case .observation: "waveform.path.ecg"
        case .procedure: "cross.case"
        case .documentReference: "doc"
        case .familyMemberHistory: "figure.2.and.child.holdinghands"
        case .clinicalNote: "note.text"
        }
    }
}

// MARK: - MedicalRecordContent Protocol

/// All 9 record types conform to this protocol.
/// Provides static metadata for form rendering and common fields.
protocol MedicalRecordContent: Codable, Sendable {
    static var recordType: RecordType { get }
    static var schemaVersion: Int { get }
    static var displayName: String { get }
    static var iconSystemName: String { get }
    static var fieldMetadata: [FieldMetadata] { get }

    var notes: String? { get set }
    var tags: [String] { get set }
    var unknownFields: [String: JSONValue] { get set }
}

// MARK: - FieldMetadata

/// Describes a single field for the generic form renderer.
struct FieldMetadata: Equatable {
    let keyPath: String
    let displayName: String
    let fieldType: FieldRenderType
    let isRequired: Bool
    let placeholder: String?
    let autocompleteSource: AutocompleteSource?
    let pickerOptions: [String]?
    let displayOrder: Int

    init(
        keyPath: String,
        displayName: String,
        fieldType: FieldRenderType,
        isRequired: Bool = false,
        placeholder: String? = nil,
        autocompleteSource: AutocompleteSource? = nil,
        pickerOptions: [String]? = nil,
        displayOrder: Int
    ) {
        self.keyPath = keyPath
        self.displayName = displayName
        self.fieldType = fieldType
        self.isRequired = isRequired
        self.placeholder = placeholder
        self.autocompleteSource = autocompleteSource
        self.pickerOptions = pickerOptions
        self.displayOrder = displayOrder
    }
}

// MARK: - FieldRenderType

enum FieldRenderType {
    case text
    case multilineText
    case date
    case integer
    case number
    case picker
    case autocomplete
    case components
    case boolean
}

// MARK: - AutocompleteSource

enum AutocompleteSource: String {
    case cvxVaccines = "cvx-vaccines"
    case whoMedications = "who-medications"
    case observationTypes = "observation-types"
}

// MARK: - Record Content Envelope

/// Wraps any MedicalRecordContent for encoding/decoding with type discrimination.
/// Stored inside the encrypted payload of MedicalRecord.
struct RecordContentEnvelope: Codable {
    let recordType: RecordType
    let schemaVersion: Int
    let content: Data // JSON-encoded MedicalRecordContent

    init<T: MedicalRecordContent>(_ record: T) throws {
        self.recordType = T.recordType
        self.schemaVersion = T.schemaVersion
        self.content = try JSONEncoder().encode(record)
    }

    /// Direct initialization for backup import and testing
    init(recordType: RecordType, schemaVersion: Int, content: Data) {
        self.recordType = recordType
        self.schemaVersion = schemaVersion
        self.content = content
    }

    func decode<T: MedicalRecordContent>(_ type: T.Type) throws -> T {
        guard recordType == T.recordType else {
            throw DecodingError.typeMismatch(
                T.self,
                DecodingError.Context(
                    codingPath: [],
                    debugDescription: "Envelope recordType '\(recordType.rawValue)'"
                        + " does not match requested type '\(T.recordType.rawValue)'"
                )
            )
        }
        return try JSONDecoder().decode(T.self, from: content)
    }

    /// Decode the envelope content to the appropriate typed record.
    func decodeAny() throws -> any MedicalRecordContent {
        switch recordType {
        case .immunization: try decode(ImmunizationRecord.self)
        case .medicationStatement: try decode(MedicationStatementRecord.self)
        case .allergyIntolerance: try decode(AllergyIntoleranceRecord.self)
        case .condition: try decode(ConditionRecord.self)
        case .observation: try decode(ObservationRecord.self)
        case .procedure: try decode(ProcedureRecord.self)
        case .documentReference: try decode(DocumentReferenceRecord.self)
        case .familyMemberHistory: try decode(FamilyMemberHistoryRecord.self)
        case .clinicalNote: try decode(ClinicalNoteRecord.self)
        }
    }
}
