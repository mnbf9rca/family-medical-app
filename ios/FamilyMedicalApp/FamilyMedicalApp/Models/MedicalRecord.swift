import Foundation

/// Container for encrypted medical record data
///
/// Medical records in the schema-overlay architecture store arbitrary field values.
/// - Plaintext metadata (id, personId, schemaId, timestamps) enables sync coordination
/// - Encrypted content blob contains the actual medical data (RecordContent serialized)
struct MedicalRecord: Codable, Equatable, Identifiable {
    // MARK: - Plaintext Properties (sync coordination, routing)

    /// Unique identifier for this record
    let id: UUID

    /// ID of the person this record belongs to
    let personId: UUID

    /// Optional schema ID (e.g., "vaccine", "medication", or custom schema)
    ///
    /// - nil indicates a freeform record (no schema)
    /// - Plaintext to enable server-side filtering/routing (per ADR-0003)
    var schemaId: String?

    /// When this record was created
    let createdAt: Date

    /// When this record was last updated
    var updatedAt: Date

    /// Version number for this record (for future wiki-style history)
    var version: Int

    /// Reference to previous version (for future wiki-style history)
    ///
    /// When a record is updated, a new version can be created with this pointing to the old version.
    /// This enables diff/history tracking without implementing it now.
    var previousVersionId: UUID?

    // MARK: - Encrypted Content

    /// Encrypted content blob
    ///
    /// This contains the serialized RecordContent (field dictionary), encrypted with the
    /// Family Member Key (FMK) for the person this record belongs to.
    ///
    /// Encryption flow:
    /// 1. RecordContent → JSON (JSONEncoder)
    /// 2. JSON Data → Encrypted (EncryptionService with FMK)
    /// 3. Store EncryptedPayload.combined in this field
    var encryptedContent: Data

    // MARK: - Initialization

    /// Initialize a new medical record
    ///
    /// - Parameters:
    ///   - id: Unique identifier (defaults to new UUID)
    ///   - personId: ID of the person this record belongs to
    ///   - schemaId: Optional schema ID (nil for freeform records)
    ///   - encryptedContent: The encrypted content blob
    ///   - createdAt: Creation timestamp (defaults to now)
    ///   - updatedAt: Last update timestamp (defaults to now)
    ///   - version: Version number (defaults to 1)
    ///   - previousVersionId: Optional reference to previous version
    init(
        id: UUID = UUID(),
        personId: UUID,
        schemaId: String? = nil,
        encryptedContent: Data,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        version: Int = 1,
        previousVersionId: UUID? = nil
    ) {
        self.id = id
        self.personId = personId
        self.schemaId = schemaId
        self.encryptedContent = encryptedContent
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.version = version
        self.previousVersionId = previousVersionId
    }

    // MARK: - Helpers

    /// Check if this record uses a built-in schema
    var isBuiltInSchema: Bool {
        guard let schemaId else { return false }
        return BuiltInSchemaType(rawValue: schemaId) != nil
    }

    /// Check if this is a freeform record (no schema)
    var isFreeform: Bool {
        schemaId == nil
    }
}
