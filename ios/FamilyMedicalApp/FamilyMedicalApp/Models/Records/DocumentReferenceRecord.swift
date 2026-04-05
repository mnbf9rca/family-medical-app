import Foundation

struct DocumentReferenceRecord: MedicalRecordContent {
    static let recordType: RecordType = .documentReference
    static let schemaVersion: Int = 1
    static let displayName: String = "Document"
    static let iconSystemName: String = "doc"

    // Type-specific fields
    var title: String
    var documentType: String?
    var mimeType: String
    var fileSize: Int
    var contentHMAC: Data // HMAC-SHA256(plaintext, FMK) — storage key for encrypted blob on disk
    var thumbnailData: Data? // Inline thumbnail bytes, decrypted alongside the envelope
    var sourceRecordId: UUID? // Parent MedicalRecord.id this is attached to, nil if standalone

    // Common fields
    var notes: String?
    var tags: [String]
    var unknownFields: [String: JSONValue]

    init(
        title: String,
        documentType: String? = nil,
        mimeType: String,
        fileSize: Int,
        contentHMAC: Data,
        thumbnailData: Data? = nil,
        sourceRecordId: UUID? = nil,
        notes: String? = nil,
        tags: [String] = [],
        unknownFields: [String: JSONValue] = [:]
    ) {
        self.title = title
        self.documentType = documentType
        self.mimeType = mimeType
        self.fileSize = fileSize
        self.contentHMAC = contentHMAC
        self.thumbnailData = thumbnailData
        self.sourceRecordId = sourceRecordId
        self.notes = notes
        self.tags = tags
        self.unknownFields = unknownFields
    }

    // MARK: - Known coding keys

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case title, documentType, mimeType, fileSize, contentHMAC, thumbnailData, sourceRecordId
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
        title = try container.decode(String.self, forKey: .title)
        documentType = try container.decodeIfPresent(String.self, forKey: .documentType)
        mimeType = try container.decode(String.self, forKey: .mimeType)
        fileSize = try container.decode(Int.self, forKey: .fileSize)
        contentHMAC = try container.decode(Data.self, forKey: .contentHMAC)
        thumbnailData = try container.decodeIfPresent(Data.self, forKey: .thumbnailData)
        sourceRecordId = try container.decodeIfPresent(UUID.self, forKey: .sourceRecordId)
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
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(documentType, forKey: .documentType)
        try container.encode(mimeType, forKey: .mimeType)
        try container.encode(fileSize, forKey: .fileSize)
        try container.encode(contentHMAC, forKey: .contentHMAC)
        try container.encodeIfPresent(thumbnailData, forKey: .thumbnailData)
        try container.encodeIfPresent(sourceRecordId, forKey: .sourceRecordId)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encode(tags, forKey: .tags)

        // Re-emit unknown fields
        var dynamicContainer = encoder.container(keyedBy: DynamicKey.self)
        for (key, value) in unknownFields {
            try dynamicContainer.encode(value, forKey: DynamicKey(stringValue: key))
        }
    }

    // MARK: - Field metadata for form rendering

    /// Only user-editable fields get metadata. contentHMAC, thumbnailData, mimeType, fileSize,
    /// and sourceRecordId are set by the picker flow, not form input.
    static let fieldMetadata: [FieldMetadata] = [
        FieldMetadata(keyPath: "title", displayName: "Title", fieldType: .text, isRequired: true, displayOrder: 1),
        FieldMetadata(
            keyPath: "documentType",
            displayName: "Document Type",
            fieldType: .picker,
            pickerOptions: ["Photo", "PDF", "Scan", "Letter", "Other"],
            displayOrder: 2
        ),
        FieldMetadata(keyPath: "notes", displayName: "Notes", fieldType: .multilineText, displayOrder: 100),
        FieldMetadata(keyPath: "tags", displayName: "Tags", fieldType: .text, displayOrder: 101, semantic: .tagList)
    ]
}
