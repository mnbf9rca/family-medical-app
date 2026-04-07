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

        unknownFields = try Self.captureUnknownFields(
            from: decoder,
            knownKeys: Set(CodingKeys.allCases.map(\.stringValue))
        )
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

        try emitUnknownFields(to: encoder)
    }

    // MARK: - Field metadata for form rendering

    static let fieldMetadata: [FieldMetadata] = [
        FieldMetadata(
            keyPath: "observationType",
            displayName: "Type",
            fieldType: .autocomplete,
            isRequired: true,
            autocompleteSource: .observationTypes,
            displayOrder: 1
        ),
        FieldMetadata(
            keyPath: "components",
            displayName: "Measurements",
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
        FieldMetadata(
            keyPath: "providerId",
            displayName: "Provider",
            fieldType: .autocomplete,
            displayOrder: 6,
            semantic: .entityReference(.provider)
        ),
        FieldMetadata(keyPath: "notes", displayName: "Notes", fieldType: .multilineText, displayOrder: 100),
        FieldMetadata(keyPath: "tags", displayName: "Tags", fieldType: .text, displayOrder: 101, semantic: .tagList)
    ]
}
