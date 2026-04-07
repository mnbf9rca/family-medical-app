import Foundation

struct ClinicalNoteRecord: MedicalRecordContent {
    static let recordType: RecordType = .clinicalNote
    static let schemaVersion: Int = 1
    static let displayName: String = "Note"
    static let iconSystemName: String = "note.text"

    // Type-specific fields
    var title: String
    var body: String?

    // Common fields (notes is unused for ClinicalNote — body IS the notes)
    var notes: String?
    var tags: [String]
    var unknownFields: [String: JSONValue]

    init(
        title: String,
        body: String? = nil,
        notes: String? = nil,
        tags: [String] = [],
        unknownFields: [String: JSONValue] = [:]
    ) {
        self.title = title
        self.body = body
        self.notes = notes
        self.tags = tags
        self.unknownFields = unknownFields
    }

    // MARK: - Known coding keys

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case title, body
        case notes, tags
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        body = try container.decodeIfPresent(String.self, forKey: .body)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []

        unknownFields = try Self.captureUnknownFields(
            from: decoder,
            knownKeys: Set(CodingKeys.allCases.map(\.stringValue))
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(body, forKey: .body)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encode(tags, forKey: .tags)

        try emitUnknownFields(to: encoder)
    }

    // MARK: - Field metadata for form rendering

    static let fieldMetadata: [FieldMetadata] = [
        FieldMetadata(keyPath: "title", displayName: "Title", fieldType: .text, isRequired: true, displayOrder: 1),
        FieldMetadata(keyPath: "body", displayName: "Content", fieldType: .multilineText, displayOrder: 2),
        FieldMetadata(keyPath: "tags", displayName: "Tags", fieldType: .text, displayOrder: 100, semantic: .tagList)
    ]
}
