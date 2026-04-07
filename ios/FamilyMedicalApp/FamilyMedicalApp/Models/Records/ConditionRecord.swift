import Foundation

struct ConditionRecord: MedicalRecordContent {
    static let recordType: RecordType = .condition
    static let schemaVersion: Int = 1
    static let displayName: String = "Condition"
    static let iconSystemName: String = "heart.text.clipboard"

    // Type-specific fields
    var conditionName: String
    var onsetDate: Date?
    var resolutionDate: Date?
    var severity: String?
    var status: String?
    var providerId: UUID?

    // Common fields
    var notes: String?
    var tags: [String]
    var unknownFields: [String: JSONValue]

    init(
        conditionName: String,
        onsetDate: Date? = nil,
        resolutionDate: Date? = nil,
        severity: String? = nil,
        status: String? = nil,
        providerId: UUID? = nil,
        notes: String? = nil,
        tags: [String] = [],
        unknownFields: [String: JSONValue] = [:]
    ) {
        self.conditionName = conditionName
        self.onsetDate = onsetDate
        self.resolutionDate = resolutionDate
        self.severity = severity
        self.status = status
        self.providerId = providerId
        self.notes = notes
        self.tags = tags
        self.unknownFields = unknownFields
    }

    // MARK: - Known coding keys

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case conditionName, onsetDate, resolutionDate, severity, status, providerId
        case notes, tags
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        conditionName = try container.decode(String.self, forKey: .conditionName)
        onsetDate = try container.decodeIfPresent(Date.self, forKey: .onsetDate)
        resolutionDate = try container.decodeIfPresent(Date.self, forKey: .resolutionDate)
        severity = try container.decodeIfPresent(String.self, forKey: .severity)
        status = try container.decodeIfPresent(String.self, forKey: .status)
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
        try container.encode(conditionName, forKey: .conditionName)
        try container.encodeIfPresent(onsetDate, forKey: .onsetDate)
        try container.encodeIfPresent(resolutionDate, forKey: .resolutionDate)
        try container.encodeIfPresent(severity, forKey: .severity)
        try container.encodeIfPresent(status, forKey: .status)
        try container.encodeIfPresent(providerId, forKey: .providerId)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encode(tags, forKey: .tags)

        try emitUnknownFields(to: encoder)
    }

    // MARK: - Field metadata for form rendering

    static let fieldMetadata: [FieldMetadata] = [
        FieldMetadata(
            keyPath: "conditionName",
            displayName: "Condition Name",
            fieldType: .text,
            isRequired: true,
            displayOrder: 1
        ),
        FieldMetadata(keyPath: "onsetDate", displayName: "Onset Date", fieldType: .date, displayOrder: 2),
        FieldMetadata(keyPath: "resolutionDate", displayName: "Resolution Date", fieldType: .date, displayOrder: 3),
        FieldMetadata(
            keyPath: "severity",
            displayName: "Severity",
            fieldType: .picker,
            pickerOptions: ["Mild", "Moderate", "Severe"],
            displayOrder: 4
        ),
        FieldMetadata(
            keyPath: "status",
            displayName: "Status",
            fieldType: .picker,
            pickerOptions: ["Active", "Resolved", "Recurring", "In remission"],
            displayOrder: 5
        ),
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
