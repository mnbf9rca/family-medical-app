import Foundation

struct AllergyIntoleranceRecord: MedicalRecordContent {
    static let recordType: RecordType = .allergyIntolerance
    static let schemaVersion: Int = 1
    static let displayName: String = "Allergy"
    static let iconSystemName: String = "allergens"

    // Type-specific fields
    var substance: String
    var reaction: String?
    var severity: String?
    var onsetDate: Date?
    var providerId: UUID?

    // Common fields
    var notes: String?
    var tags: [String]
    var unknownFields: [String: JSONValue]

    init(
        substance: String,
        reaction: String? = nil,
        severity: String? = nil,
        onsetDate: Date? = nil,
        providerId: UUID? = nil,
        notes: String? = nil,
        tags: [String] = [],
        unknownFields: [String: JSONValue] = [:]
    ) {
        self.substance = substance
        self.reaction = reaction
        self.severity = severity
        self.onsetDate = onsetDate
        self.providerId = providerId
        self.notes = notes
        self.tags = tags
        self.unknownFields = unknownFields
    }

    // MARK: - Known coding keys

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case substance, reaction, severity, onsetDate, providerId
        case notes, tags
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        substance = try container.decode(String.self, forKey: .substance)
        reaction = try container.decodeIfPresent(String.self, forKey: .reaction)
        severity = try container.decodeIfPresent(String.self, forKey: .severity)
        onsetDate = try container.decodeIfPresent(Date.self, forKey: .onsetDate)
        providerId = try container.decodeIfPresent(UUID.self, forKey: .providerId)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []

        unknownFields = try Self.captureUnknownFields(
            from: decoder,
            knownKeys: Set(CodingKeys.allCases.map(\.stringValue))
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(substance, forKey: .substance)
        try container.encodeIfPresent(reaction, forKey: .reaction)
        try container.encodeIfPresent(severity, forKey: .severity)
        try container.encodeIfPresent(onsetDate, forKey: .onsetDate)
        try container.encodeIfPresent(providerId, forKey: .providerId)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encode(tags, forKey: .tags)

        try emitUnknownFields(to: encoder)
    }

    // MARK: - Field metadata for form rendering

    static let fieldMetadata: [FieldMetadata] = [
        FieldMetadata(
            keyPath: "substance",
            displayName: "Substance",
            fieldType: .text,
            isRequired: true,
            placeholder: "e.g., Penicillin",
            displayOrder: 1
        ),
        FieldMetadata(
            keyPath: "reaction",
            displayName: "Reaction",
            fieldType: .text,
            placeholder: "e.g., Hives, swelling",
            displayOrder: 2
        ),
        FieldMetadata(
            keyPath: "severity",
            displayName: "Severity",
            fieldType: .picker,
            pickerOptions: ["Mild", "Moderate", "Severe"],
            displayOrder: 3
        ),
        FieldMetadata(keyPath: "onsetDate", displayName: "Date Diagnosed", fieldType: .date, displayOrder: 4),
        FieldMetadata(
            keyPath: "providerId",
            displayName: "Provider",
            fieldType: .autocomplete,
            displayOrder: 5,
            semantic: .entityReference(.provider)
        ),
        FieldMetadata(keyPath: "notes", displayName: "Notes", fieldType: .multilineText, displayOrder: 100),
        FieldMetadata(keyPath: "tags", displayName: "Tags", fieldType: .text, displayOrder: 101, semantic: .tagList)
    ]
}
