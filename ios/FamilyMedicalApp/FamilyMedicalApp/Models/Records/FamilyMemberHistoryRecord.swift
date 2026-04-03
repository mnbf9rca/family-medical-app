import Foundation

struct FamilyMemberHistoryRecord: MedicalRecordContent {
    static let recordType: RecordType = .familyMemberHistory
    static let schemaVersion: Int = 1
    static let displayName: String = "Family History"
    static let iconSystemName: String = "figure.2.and.child.holdinghands"

    // Type-specific fields
    var relationship: String
    var conditionName: String
    var onsetAge: Int?
    var deceased: Bool?
    var deceasedAge: Int?

    // Common fields
    var notes: String?
    var tags: [String]
    var unknownFields: [String: JSONValue]

    init(
        relationship: String,
        conditionName: String,
        onsetAge: Int? = nil,
        deceased: Bool? = nil,
        deceasedAge: Int? = nil,
        notes: String? = nil,
        tags: [String] = [],
        unknownFields: [String: JSONValue] = [:]
    ) {
        self.relationship = relationship
        self.conditionName = conditionName
        self.onsetAge = onsetAge
        self.deceased = deceased
        self.deceasedAge = deceasedAge
        self.notes = notes
        self.tags = tags
        self.unknownFields = unknownFields
    }

    // MARK: - Known coding keys

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case relationship, conditionName, onsetAge, deceased, deceasedAge
        case notes, tags
    }

    // MARK: - Unknown field preservation

    private struct DynamicKey: CodingKey {
        var stringValue: String
        init(stringValue: String) {
            self.stringValue = stringValue
        }

        var intValue: Int? {
            nil
        }

        init?(intValue: Int) {
            nil
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        relationship = try container.decode(String.self, forKey: .relationship)
        conditionName = try container.decode(String.self, forKey: .conditionName)
        onsetAge = try container.decodeIfPresent(Int.self, forKey: .onsetAge)
        deceased = try container.decodeIfPresent(Bool.self, forKey: .deceased)
        deceasedAge = try container.decodeIfPresent(Int.self, forKey: .deceasedAge)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []

        // Capture unknown fields
        let knownKeys = Set(CodingKeys.allCases.map(\.stringValue))
        let dynamicContainer = try decoder.container(keyedBy: DynamicKey.self)
        var unknown: [String: JSONValue] = [:]
        for key in dynamicContainer.allKeys where !knownKeys.contains(key.stringValue) {
            unknown[key.stringValue] = try dynamicContainer.decode(JSONValue.self, forKey: key)
        }
        unknownFields = unknown
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(relationship, forKey: .relationship)
        try container.encode(conditionName, forKey: .conditionName)
        try container.encodeIfPresent(onsetAge, forKey: .onsetAge)
        try container.encodeIfPresent(deceased, forKey: .deceased)
        try container.encodeIfPresent(deceasedAge, forKey: .deceasedAge)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encode(tags, forKey: .tags)

        // Re-emit unknown fields
        var dynamicContainer = encoder.container(keyedBy: DynamicKey.self)
        for (key, value) in unknownFields {
            try dynamicContainer.encode(value, forKey: DynamicKey(stringValue: key))
        }
    }

    // MARK: - Field metadata for form rendering

    static let fieldMetadata: [FieldMetadata] = [
        FieldMetadata(
            keyPath: "relationship",
            displayName: "Relationship",
            fieldType: .picker,
            isRequired: true,
            pickerOptions: [
                "Mother",
                "Father",
                "Birth mother",
                "Birth father",
                "Sister",
                "Brother",
                "Half-sister",
                "Half-brother",
                "Maternal grandmother",
                "Maternal grandfather",
                "Paternal grandmother",
                "Paternal grandfather",
                "Maternal aunt",
                "Maternal uncle",
                "Paternal aunt",
                "Paternal uncle",
                "Other"
            ],
            displayOrder: 1
        ),
        FieldMetadata(
            keyPath: "conditionName",
            displayName: "Condition",
            fieldType: .text,
            isRequired: true,
            displayOrder: 2
        ),
        FieldMetadata(keyPath: "onsetAge", displayName: "Age at Onset", fieldType: .integer, displayOrder: 3),
        FieldMetadata(keyPath: "deceased", displayName: "Deceased", fieldType: .boolean, displayOrder: 4),
        FieldMetadata(keyPath: "deceasedAge", displayName: "Age at Death", fieldType: .integer, displayOrder: 5),
        FieldMetadata(keyPath: "notes", displayName: "Notes", fieldType: .multilineText, displayOrder: 100),
        FieldMetadata(keyPath: "tags", displayName: "Tags", fieldType: .text, displayOrder: 101)
    ]
}
