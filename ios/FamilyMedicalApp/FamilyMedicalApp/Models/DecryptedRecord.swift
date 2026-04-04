import Foundation

/// Wrapper holding a decrypted medical record with its typed content envelope
///
/// Pairs the encrypted container (`MedicalRecord`) with the decrypted
/// `RecordContentEnvelope` for UI display. Avoids re-decrypting the same record.
struct DecryptedRecord: Identifiable, Hashable {
    // MARK: - Properties

    /// The encrypted record container with metadata
    let record: MedicalRecord

    /// The decrypted content envelope containing the typed record data
    let envelope: RecordContentEnvelope

    /// Convenience: the record type from the envelope
    var recordType: RecordType {
        envelope.recordType
    }

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
