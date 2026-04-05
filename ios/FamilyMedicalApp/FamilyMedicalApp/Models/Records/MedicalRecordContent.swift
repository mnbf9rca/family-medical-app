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

    /// The concrete `MedicalRecordContent` type corresponding to this `RecordType`.
    /// Use this to delegate static property lookups to the concrete type instead of
    /// maintaining parallel switches that drift when types are added.
    var contentType: any MedicalRecordContent.Type {
        switch self {
        case .immunization: ImmunizationRecord.self
        case .medicationStatement: MedicationStatementRecord.self
        case .allergyIntolerance: AllergyIntoleranceRecord.self
        case .condition: ConditionRecord.self
        case .observation: ObservationRecord.self
        case .procedure: ProcedureRecord.self
        case .documentReference: DocumentReferenceRecord.self
        case .familyMemberHistory: FamilyMemberHistoryRecord.self
        case .clinicalNote: ClinicalNoteRecord.self
        }
    }

    var fieldMetadata: [FieldMetadata] {
        contentType.fieldMetadata
    }

    var currentSchemaVersion: Int {
        contentType.schemaVersion
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
    let semantic: FieldSemantic?

    init(
        keyPath: String,
        displayName: String,
        fieldType: FieldRenderType,
        isRequired: Bool = false,
        placeholder: String? = nil,
        autocompleteSource: AutocompleteSource? = nil,
        pickerOptions: [String]? = nil,
        displayOrder: Int,
        semantic: FieldSemantic? = nil
    ) {
        self.keyPath = keyPath
        self.displayName = displayName
        self.fieldType = fieldType
        self.isRequired = isRequired
        self.placeholder = placeholder
        self.autocompleteSource = autocompleteSource
        self.pickerOptions = pickerOptions
        self.displayOrder = displayOrder
        self.semantic = semantic
    }
}

extension FieldMetadata {
    /// True if this field stores a UUID referencing any entity type.
    var isEntityReference: Bool {
        if case .entityReference = semantic { true } else { false }
    }

    /// True if this field specifically references a Provider.
    var isProviderReference: Bool {
        semantic == .entityReference(.provider)
    }

    /// True if this field stores a tag list (comma-separated in UI, [String] in storage).
    var isTagList: Bool {
        semantic == .tagList
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

// MARK: - FieldSemantic

/// Declares a field's semantic purpose beyond its render type.
///
/// `FieldRenderType` describes HOW to render a field (text field, date picker, etc).
/// `FieldSemantic` describes WHAT the field represents — a reference to another entity,
/// a tag list, etc. — so the form machinery can dispatch on semantics rather than
/// stringly-typed keyPath matches like `keyPath == "providerId"`.
enum FieldSemantic: Equatable {
    /// This field stores a UUID that references another entity (e.g., Provider).
    /// Used to drive entity-specific autocomplete resolvers and UUID denormalization.
    case entityReference(EntityKind)

    /// This field stores a comma-separated list of tags. In storage: `[String]`.
    /// In the form UI: a comma-separated `String`. Normalize/denormalize convert between them.
    case tagList
}

/// Entity types that FieldSemantic.entityReference can refer to.
enum EntityKind: Equatable {
    case provider
    case pharmacy
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

    /// Parse the envelope's JSON content into a `[String: Any]` dictionary.
    ///
    /// The returned dictionary contains JSON-primitive values (String, Double, Int, Bool,
    /// Array, Dictionary). Dates appear as `Double` (seconds since reference date) and
    /// UUIDs as `String`. Callers that need native Swift types must denormalize per-field.
    func contentAsJSONDict() throws -> [String: Any] {
        guard let dict = try JSONSerialization.jsonObject(with: content) as? [String: Any] else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: [], debugDescription: "Envelope content is not a JSON object")
            )
        }
        return dict
    }

    /// Decode the envelope's content into native Swift values partitioned into known fields
    /// (keyed by `FieldMetadata.keyPath`) and unknown forward-compat fields.
    ///
    /// Known fields are denormalized based on their declared `FieldRenderType` and semantic:
    /// - `.date` → `Date`
    /// - `.autocomplete` with `semantic: .entityReference(...)` → `UUID`
    /// - `.components` → `[ObservationComponent]`
    /// - everything else stays as its JSON-primitive representation
    ///
    /// Unknown fields are returned verbatim (as JSON primitives) so they can be preserved
    /// on re-serialization without loss.
    func decodedFieldValues() throws -> (known: [String: Any], unknown: [String: Any]) {
        let dict = try contentAsJSONDict()
        let metadataByKeyPath = Dictionary(
            uniqueKeysWithValues: recordType.fieldMetadata.map { ($0.keyPath, $0) }
        )
        var known: [String: Any] = [:]
        var unknown: [String: Any] = [:]
        for (key, value) in dict {
            if let metadata = metadataByKeyPath[key] {
                known[key] = FieldValueDenormalizer.denormalize(value, for: metadata)
            } else {
                unknown[key] = value
            }
        }
        return (known, unknown)
    }
}

// MARK: - FieldValueDenormalizer

/// Converts JSON-primitive values to native Swift types based on `FieldMetadata`.
/// Used by the form ViewModel when hydrating existing records and by the detail view
/// when displaying values, so both share one source of truth.
enum FieldValueDenormalizer {
    static func denormalize(_ value: Any, for metadata: FieldMetadata) -> Any {
        switch metadata.fieldType {
        case .date:
            if let double = value as? Double { return Date(timeIntervalSinceReferenceDate: double) }
        case .autocomplete:
            if metadata.isEntityReference, let string = value as? String {
                return UUID(uuidString: string) ?? string
            }
        case .components:
            if let array = value as? [[String: Any]] {
                guard let data = try? JSONSerialization.data(withJSONObject: array),
                      let decoded = try? JSONDecoder().decode([ObservationComponent].self, from: data)
                else {
                    // Preserve the raw JSON array so forward-compat data isn't silently
                    // discarded when decode fails (e.g., newer schema with fields we don't
                    // know). Callers downcast; they'll either handle the raw array or
                    // gracefully ignore a wrong-typed value.
                    return value
                }
                return decoded
            }
        default:
            break
        }
        return value
    }
}

// MARK: - FieldValueNormalizer

/// Converts native Swift values to JSON-serialization-safe representations based on
/// `FieldMetadata`. Inverse of `FieldValueDenormalizer`.
///
/// Returns `nil` when the value should be omitted from the output (e.g., an optional
/// text field with an empty string).
enum FieldValueNormalizer {
    static func normalize(_ value: Any, for metadata: FieldMetadata) -> Any? {
        // Empty strings on optional text-ish fields mean "not set" and should be omitted.
        if !metadata.isRequired, let string = value as? String, string.isEmpty {
            return nil
        }
        switch metadata.fieldType {
        case .date:
            if let date = value as? Date { return date.timeIntervalSinceReferenceDate }
        case .autocomplete:
            if let uuid = value as? UUID { return uuid.uuidString }
        case .components:
            if let components = value as? [ObservationComponent] {
                let data = try? JSONEncoder().encode(components)
                return data.flatMap { try? JSONSerialization.jsonObject(with: $0) }
            }
        case .multilineText, .text:
            if metadata.isTagList, let string = value as? String {
                return string.split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
            }
        default:
            break
        }
        return value
    }
}

// MARK: - AutocompleteSuggestionResolver

/// Unified suggestion for the autocomplete renderer: a human-readable label plus, for
/// provider picks, the Provider UUID to store on save.
struct AutocompleteSuggestion: Identifiable, Equatable {
    let id: String
    let label: String
    let providerId: UUID?
}

/// Pure resolver for autocomplete suggestions and display text.
///
/// Split out of `AutocompleteFieldRenderer` so the catalog/provider dispatch, filtering,
/// and displayText logic can be unit-tested directly without instantiating a SwiftUI view
/// (which would require ViewInspector/ViewHosting just to exercise a switch statement).
struct AutocompleteSuggestionResolver {
    let metadata: FieldMetadata
    let providers: [Provider]
    let autocompleteService: AutocompleteServiceProtocol

    /// Filter suggestions for the current query. Empty query returns the full list.
    /// Returns up to `limit` entries (default 5, matching the renderer's dropdown cap).
    func suggestions(for query: String, limit: Int = 5) -> [AutocompleteSuggestion] {
        Array(allSuggestions(for: query).prefix(limit))
    }

    /// Display text for a stored field value: resolves a provider UUID to its display
    /// string, falls back to the raw string value for catalog autocompletes, returns "" if
    /// the provider UUID doesn't match any loaded Provider.
    func displayText(storedValue: Any?) -> String {
        if metadata.isProviderReference {
            guard let uuid = storedValue as? UUID,
                  let provider = providers.first(where: { $0.id == uuid })
            else { return "" }
            return provider.displayString
        }
        return (storedValue as? String) ?? ""
    }

    // MARK: - Private

    private func allSuggestions(for query: String) -> [AutocompleteSuggestion] {
        if metadata.isProviderReference {
            return providerSuggestions(for: query)
        }
        if let source = metadata.autocompleteSource {
            return autocompleteService
                .suggestions(for: source, query: query)
                .map { AutocompleteSuggestion(id: $0, label: $0, providerId: nil) }
        }
        return []
    }

    private func providerSuggestions(for query: String) -> [AutocompleteSuggestion] {
        let matches: [Provider]
        if query.isEmpty {
            matches = providers
        } else {
            let lowered = query.lowercased()
            matches = providers.filter {
                ($0.name?.lowercased().contains(lowered) ?? false) ||
                    ($0.organization?.lowercased().contains(lowered) ?? false)
            }
        }
        return matches.map {
            AutocompleteSuggestion(id: $0.id.uuidString, label: $0.displayString, providerId: $0.id)
        }
    }
}

// MARK: - RecordContentEnvelope construction helper

extension RecordContentEnvelope {
    /// Construct an envelope by decoding `jsonData` as the concrete type matching `recordType`
    /// and re-wrapping it. The round-trip also populates the concrete struct's `unknownFields`
    /// for any preserved forward-compat keys.
    static func wrap(jsonData: Data, as recordType: RecordType) throws -> RecordContentEnvelope {
        let decoder = JSONDecoder()
        switch recordType {
        case .immunization: return try RecordContentEnvelope(decoder.decode(ImmunizationRecord.self, from: jsonData))
        case .medicationStatement:
            return try RecordContentEnvelope(decoder.decode(MedicationStatementRecord.self, from: jsonData))
        case .allergyIntolerance:
            return try RecordContentEnvelope(decoder.decode(AllergyIntoleranceRecord.self, from: jsonData))
        case .condition: return try RecordContentEnvelope(decoder.decode(ConditionRecord.self, from: jsonData))
        case .observation: return try RecordContentEnvelope(decoder.decode(ObservationRecord.self, from: jsonData))
        case .procedure: return try RecordContentEnvelope(decoder.decode(ProcedureRecord.self, from: jsonData))
        case .documentReference:
            return try RecordContentEnvelope(decoder.decode(DocumentReferenceRecord.self, from: jsonData))
        case .familyMemberHistory:
            return try RecordContentEnvelope(decoder.decode(FamilyMemberHistoryRecord.self, from: jsonData))
        case .clinicalNote: return try RecordContentEnvelope(decoder.decode(ClinicalNoteRecord.self, from: jsonData))
        }
    }
}
