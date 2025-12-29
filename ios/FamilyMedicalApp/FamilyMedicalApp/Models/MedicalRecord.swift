import Foundation

/// Container for encrypted medical record data
///
/// Medical records in the schema-overlay architecture store arbitrary field values.
/// - Plaintext metadata (id, personId, timestamps) enables sync coordination
/// - Encrypted content blob contains RecordContent (including schemaId and field values)
///
/// **Zero-Knowledge Privacy**: The schemaId is encrypted inside RecordContent to prevent
/// the server from inferring health information based on record types.
struct MedicalRecord: Codable, Equatable, Identifiable {
    // MARK: - Plaintext Properties (sync coordination only)

    /// Unique identifier for this record
    let id: UUID

    /// ID of the person this record belongs to
    ///
    /// Used for access control - server ensures users can only sync records
    /// for people they have permission to access.
    let personId: UUID

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
    /// This contains the serialized RecordContent (including schemaId and field dictionary),
    /// encrypted with the Family Member Key (FMK) for the person this record belongs to.
    ///
    /// Encryption flow:
    /// 1. RecordContent (with schemaId + fields) → JSON (JSONEncoder)
    /// 2. JSON Data → Encrypted (EncryptionService with FMK)
    /// 3. Store EncryptedPayload.combined in this field
    ///
    /// Decryption flow:
    /// 1. encryptedContent → Decrypted (EncryptionService with FMK)
    /// 2. JSON Data → RecordContent (JSONDecoder)
    /// 3. Access schemaId and fields from RecordContent
    var encryptedContent: Data

    // MARK: - Initialization

    /// Initialize a new medical record
    ///
    /// - Parameters:
    ///   - id: Unique identifier (defaults to new UUID)
    ///   - personId: ID of the person this record belongs to
    ///   - encryptedContent: The encrypted content blob (contains RecordContent with schemaId)
    ///   - createdAt: Creation timestamp (defaults to now)
    ///   - updatedAt: Last update timestamp (defaults to now)
    ///   - version: Version number (defaults to 1)
    ///   - previousVersionId: Optional reference to previous version
    init(
        id: UUID = UUID(),
        personId: UUID,
        encryptedContent: Data,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        version: Int = 1,
        previousVersionId: UUID? = nil
    ) {
        self.id = id
        self.personId = personId
        self.encryptedContent = encryptedContent
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.version = version
        self.previousVersionId = previousVersionId
    }
}
