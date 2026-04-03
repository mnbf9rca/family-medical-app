import Foundation

struct ObservationRecord: MedicalRecordContent {
    static let recordType: RecordType = .observation
    static let schemaVersion: Int = 1
    static let displayName: String = "Observation"
    static let iconSystemName: String = "waveform.path.ecg"

    // Type-specific fields
    var observationType: String
    var components: [ObservationComponent]
    var effectiveDate: Date
    var method: String?
    var referenceRange: String?
    var providerId: UUID?

    // Common fields
    var notes: String?
    var tags: [String]
    var unknownFields: [String: JSONValue]

    init(
        observationType: String,
        components: [ObservationComponent],
        effectiveDate: Date,
        method: String? = nil,
        referenceRange: String? = nil,
        providerId: UUID? = nil,
        notes: String? = nil,
        tags: [String] = [],
        unknownFields: [String: JSONValue] = [:]
    ) {
        self.observationType = observationType
        self.components = components
        self.effectiveDate = effectiveDate
        self.method = method
        self.referenceRange = referenceRange
        self.providerId = providerId
        self.notes = notes
        self.tags = tags
        self.unknownFields = unknownFields
    }

    // MARK: - Known coding keys

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case observationType, components, effectiveDate, method, referenceRange, providerId
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
        observationType = try container.decode(String.self, forKey: .observationType)
        components = try container.decode([ObservationComponent].self, forKey: .components)
        effectiveDate = try container.decode(Date.self, forKey: .effectiveDate)
        method = try container.decodeIfPresent(String.self, forKey: .method)
        referenceRange = try container.decodeIfPresent(String.self, forKey: .referenceRange)
        providerId = try container.decodeIfPresent(UUID.self, forKey: .providerId)
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
        try container.encode(observationType, forKey: .observationType)
        try container.encode(components, forKey: .components)
        try container.encode(effectiveDate, forKey: .effectiveDate)
        try container.encodeIfPresent(method, forKey: .method)
        try container.encodeIfPresent(referenceRange, forKey: .referenceRange)
        try container.encodeIfPresent(providerId, forKey: .providerId)
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
            keyPath: "observationType",
            displayName: "Observation Type",
            fieldType: .autocomplete,
            isRequired: true,
            autocompleteSource: .observationTypes,
            displayOrder: 1
        ),
        FieldMetadata(
            keyPath: "components",
            displayName: "Values",
            fieldType: .components,
            isRequired: true,
            displayOrder: 2
        ),
        FieldMetadata(
            keyPath: "effectiveDate",
            displayName: "Date",
            fieldType: .date,
            isRequired: true,
            displayOrder: 3
        ),
        FieldMetadata(keyPath: "method", displayName: "Method", fieldType: .text, displayOrder: 4),
        FieldMetadata(keyPath: "referenceRange", displayName: "Reference Range", fieldType: .text, displayOrder: 5),
        FieldMetadata(keyPath: "providerId", displayName: "Provider", fieldType: .autocomplete, displayOrder: 6),
        FieldMetadata(keyPath: "notes", displayName: "Notes", fieldType: .multilineText, displayOrder: 100),
        FieldMetadata(keyPath: "tags", displayName: "Tags", fieldType: .text, displayOrder: 101)
    ]
}
