import Foundation

/// Wrapper holding a decrypted medical record with its content
///
/// This type pairs the encrypted container (`MedicalRecord`) with its decrypted payload
/// (`RecordContent`) for UI display. It avoids re-decrypting the same record multiple times.
struct DecryptedRecord: Identifiable, Hashable {
    // MARK: - Properties

    /// The encrypted record container with metadata
    let record: MedicalRecord

    /// The decrypted content with field values
    let content: RecordContent

    // MARK: - Identifiable

    var id: UUID {
        record.id
    }

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine(record.id)
    }

    static func == (lhs: DecryptedRecord, rhs: DecryptedRecord) -> Bool {
        lhs.record.id == rhs.record.id
    }
}
