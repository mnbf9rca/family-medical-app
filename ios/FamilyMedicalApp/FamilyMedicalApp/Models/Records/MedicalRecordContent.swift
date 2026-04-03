import Foundation

// MARK: - RecordType Enum

enum RecordType: String, Codable, CaseIterable, Sendable {
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
struct FieldMetadata: Sendable {
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

enum FieldRenderType: Sendable {
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

enum AutocompleteSource: String, Sendable {
    case cvxVaccines = "cvx-vaccines"
    case whoMedications = "who-medications"
    case observationTypes = "observation-types"
}

// MARK: - Record Content Envelope

/// Wraps any MedicalRecordContent for encoding/decoding with type discrimination.
/// Stored inside the encrypted payload of MedicalRecord.
struct RecordContentEnvelope: Codable, Sendable {
    let recordType: RecordType
    let schemaVersion: Int
    let content: Data // JSON-encoded MedicalRecordContent

    init<T: MedicalRecordContent>(_ record: T) throws {
        self.recordType = T.recordType
        self.schemaVersion = T.schemaVersion
        self.content = try JSONEncoder().encode(record)
    }

    func decode<T: MedicalRecordContent>(_ type: T.Type) throws -> T {
        try JSONDecoder().decode(T.self, from: content)
    }
}
