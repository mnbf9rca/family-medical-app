import Foundation

/// Decrypted backup payload containing all user data
///
/// This is the structure inside the encrypted ciphertext (or in the `data`
/// field for unencrypted backups). All sensitive information is here.
struct BackupPayload: Codable, Equatable {
    /// When this backup was created
    let exportedAt: Date

    /// App version that created this backup
    let appVersion: String

    /// Summary counts (inside encrypted payload for privacy)
    let metadata: BackupMetadata

    /// All persons (family members)
    let persons: [PersonBackup]

    /// All medical records
    let records: [MedicalRecordBackup]

    /// All attachments with file content
    let attachments: [AttachmentBackup]

    /// All custom schemas
    let schemas: [SchemaBackup]

    /// Check if the backup contains no data
    var isEmpty: Bool {
        persons.isEmpty && records.isEmpty && attachments.isEmpty && schemas.isEmpty
    }
}

/// Backup metadata (counts, stored inside encrypted payload)
struct BackupMetadata: Codable, Equatable {
    let personCount: Int
    let recordCount: Int
    let attachmentCount: Int
    let schemaCount: Int
}
