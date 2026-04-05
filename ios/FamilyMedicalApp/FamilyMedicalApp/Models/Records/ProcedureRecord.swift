import Foundation

struct ProcedureRecord: MedicalRecordContent {
    static let recordType: RecordType = .procedure
    static let schemaVersion: Int = 1
    static let displayName: String = "Procedure"
    static let iconSystemName: String = "cross.case"

    // Type-specific fields
    var procedureName: String
    var performedDate: Date?
    var reason: String?
    var outcome: String?
    var bodySite: String?
    var providerId: UUID?

    // Common fields
    var notes: String?
    var tags: [String]
    var unknownFields: [String: JSONValue]

    init(
        procedureName: String,
        performedDate: Date? = nil,
        reason: String? = nil,
        outcome: String? = nil,
        bodySite: String? = nil,
        providerId: UUID? = nil,
        notes: String? = nil,
        tags: [String] = [],
        unknownFields: [String: JSONValue] = [:]
    ) {
        self.procedureName = procedureName
        self.performedDate = performedDate
        self.reason = reason
        self.outcome = outcome
        self.bodySite = bodySite
        self.providerId = providerId
        self.notes = notes
        self.tags = tags
        self.unknownFields = unknownFields
    }

    // MARK: - Known coding keys

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case procedureName, performedDate, reason, outcome, bodySite, providerId
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
        procedureName = try container.decode(String.self, forKey: .procedureName)
        performedDate = try container.decodeIfPresent(Date.self, forKey: .performedDate)
        reason = try container.decodeIfPresent(String.self, forKey: .reason)
        outcome = try container.decodeIfPresent(String.self, forKey: .outcome)
        bodySite = try container.decodeIfPresent(String.self, forKey: .bodySite)
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
        try container.encode(procedureName, forKey: .procedureName)
        try container.encodeIfPresent(performedDate, forKey: .performedDate)
        try container.encodeIfPresent(reason, forKey: .reason)
        try container.encodeIfPresent(outcome, forKey: .outcome)
        try container.encodeIfPresent(bodySite, forKey: .bodySite)
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
            keyPath: "procedureName",
            displayName: "Procedure Name",
            fieldType: .text,
            isRequired: true,
            displayOrder: 1
        ),
        FieldMetadata(keyPath: "performedDate", displayName: "Date Performed", fieldType: .date, displayOrder: 2),
        FieldMetadata(keyPath: "reason", displayName: "Reason", fieldType: .text, displayOrder: 3),
        FieldMetadata(keyPath: "outcome", displayName: "Outcome", fieldType: .text, displayOrder: 4),
        FieldMetadata(keyPath: "bodySite", displayName: "Body Site", fieldType: .text, displayOrder: 5),
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
