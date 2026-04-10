import Foundation

struct DocumentReferenceRecord: MedicalRecordContent {
    static let recordType: RecordType = .documentReference
    static let schemaVersion: Int = 1
    static let displayName: String = "Document"
    static let iconSystemName: String = "doc"

    /// Maximum permitted length for `title`, measured in Swift `Character`s
    /// (extended grapheme clusters). Titles longer than this are silently truncated
    /// by the `title` setter — the common ingestion path is `url.lastPathComponent`
    /// from the document picker, which the user cannot easily shorten, so a throw
    /// would be a dead-end UX.
    ///
    /// This is a *loose* upper bound on the underlying UTF-8 byte count rather
    /// than an exact one: 255 grapheme clusters can be up to roughly 1.5KB for
    /// pathological Unicode (e.g. family emoji with ZWJ sequences). That is still
    /// well within the threat model, which is adversarial bloat of the encrypted
    /// Core Data store, the backup JSON, and the SwiftUI render path — not exact
    /// filesystem conformance.
    static let titleMaxLength = 255

    /// Truncate `raw` to at most `titleMaxLength` characters. Use this at every
    /// ingestion point (init, decode, in-app edit) so an adversarial filename cannot
    /// bloat the encrypted store or the backup file.
    static func normalizedTitle(_ raw: String) -> String {
        String(raw.prefix(titleMaxLength))
    }

    // MARK: - Type-specific fields

    /// Backing storage for `title`. Never mutate this directly — assign through
    /// the computed `title` setter so every mutation routes through
    /// `normalizedTitle(_:)` and the 255-grapheme invariant is preserved.
    private var _title: String

    /// User-visible document title. Every assignment is automatically truncated
    /// to `titleMaxLength` grapheme clusters by the setter; no caller anywhere
    /// in the module can bypass the cap.
    var title: String {
        get { _title }
        set { _title = Self.normalizedTitle(newValue) }
    }

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
        self._title = Self.normalizedTitle(title)
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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        _title = try Self.normalizedTitle(container.decode(String.self, forKey: .title))
        documentType = try container.decodeIfPresent(String.self, forKey: .documentType)
        mimeType = try container.decode(String.self, forKey: .mimeType)
        fileSize = try container.decode(Int.self, forKey: .fileSize)
        contentHMAC = try container.decode(Data.self, forKey: .contentHMAC)
        thumbnailData = try container.decodeIfPresent(Data.self, forKey: .thumbnailData)
        sourceRecordId = try container.decodeIfPresent(UUID.self, forKey: .sourceRecordId)
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
        try container.encodeIfPresent(documentType, forKey: .documentType)
        try container.encode(mimeType, forKey: .mimeType)
        try container.encode(fileSize, forKey: .fileSize)
        try container.encode(contentHMAC, forKey: .contentHMAC)
        try container.encodeIfPresent(thumbnailData, forKey: .thumbnailData)
        try container.encodeIfPresent(sourceRecordId, forKey: .sourceRecordId)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encode(tags, forKey: .tags)

        try emitUnknownFields(to: encoder)
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
