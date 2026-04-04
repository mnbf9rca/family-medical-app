import Foundation

/// Decrypted medical record data for backup.
/// Stores the typed record content as a JSON blob alongside metadata.
struct MedicalRecordBackup: Codable, Equatable {
    let id: UUID
    let personId: UUID
    let recordType: String
    let schemaVersion: Int
    let contentJSON: Data
    let createdAt: Date
    let updatedAt: Date
    let version: Int
    let previousVersionId: UUID?

    /// Create from MedicalRecord and decrypted RecordContentEnvelope
    init(from record: MedicalRecord, envelope: RecordContentEnvelope) {
        self.id = record.id
        self.personId = record.personId
        self.recordType = envelope.recordType.rawValue
        self.schemaVersion = envelope.schemaVersion
        self.contentJSON = envelope.content
        self.createdAt = record.createdAt
        self.updatedAt = record.updatedAt
        self.version = record.version
        self.previousVersionId = record.previousVersionId
    }

    /// Direct initialization for tests and imports
    init(
        id: UUID,
        personId: UUID,
        recordType: String,
        schemaVersion: Int,
        contentJSON: Data,
        createdAt: Date,
        updatedAt: Date,
        version: Int,
        previousVersionId: UUID?
    ) {
        self.id = id
        self.personId = personId
        self.recordType = recordType
        self.schemaVersion = schemaVersion
        self.contentJSON = contentJSON
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.version = version
        self.previousVersionId = previousVersionId
    }

    /// Convert back to RecordContentEnvelope for import
    func toEnvelope() throws -> RecordContentEnvelope {
        guard let type = RecordType(rawValue: recordType) else {
            throw BackupError.corruptedFile
        }
        return RecordContentEnvelope(
            recordType: type,
            schemaVersion: schemaVersion,
            content: contentJSON
        )
    }
}
