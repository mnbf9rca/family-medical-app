import Foundation

// swiftlint:disable force_unwrapping

/// Hardcoded UUIDs for built-in schema fields
///
/// These UUIDs are deterministic and must NEVER change once deployed.
/// They enable stable field identification across app versions and devices.
///
/// UUID Format: `00000001-SSSS-FFFF-0000-000000000000`
/// - `00000001`: Constant prefix indicating built-in field
/// - `SSSS`: Schema index (0001=vaccine, 0002=condition, etc.)
/// - `FFFF`: Field index within schema
///
/// Per ADR-0009 (Schema Evolution in Multi-Master Replication):
/// - Built-in fields use hardcoded UUIDs for baseline interoperability
/// - User-created fields use randomly generated UUIDs
enum BuiltInFieldIds {
    // MARK: - Vaccine Schema (0001)

    /// Field IDs for the Vaccine schema
    enum Vaccine {
        /// Vaccine name (required, string)
        static let name = UUID(uuidString: "00000001-0001-0001-0000-000000000000")!
        /// Date administered (required, date)
        static let dateAdministered = UUID(uuidString: "00000001-0001-0002-0000-000000000000")!
        /// Healthcare provider (optional, string)
        static let provider = UUID(uuidString: "00000001-0001-0003-0000-000000000000")!
        /// Batch/lot number (optional, string)
        static let batchNumber = UUID(uuidString: "00000001-0001-0004-0000-000000000000")!
        /// Dose number (optional, int)
        static let doseNumber = UUID(uuidString: "00000001-0001-0005-0000-000000000000")!
        /// Expiration date (optional, date)
        static let expirationDate = UUID(uuidString: "00000001-0001-0006-0000-000000000000")!
        /// Notes (optional, string, multiline)
        static let notes = UUID(uuidString: "00000001-0001-0007-0000-000000000000")!
        /// Attachment IDs (optional, attachmentIds)
        static let attachmentIds = UUID(uuidString: "00000001-0001-0008-0000-000000000000")!

        /// All field IDs in this schema
        static let allFields: [UUID] = [
            name, dateAdministered, provider, batchNumber,
            doseNumber, expirationDate, notes, attachmentIds
        ]
    }

    // MARK: - Condition Schema (0002)

    /// Field IDs for the Medical Condition schema
    enum Condition {
        /// Condition name (required, string)
        static let name = UUID(uuidString: "00000001-0002-0001-0000-000000000000")!
        /// Date diagnosed (optional, date)
        static let diagnosedDate = UUID(uuidString: "00000001-0002-0002-0000-000000000000")!
        /// Status (optional, string)
        static let status = UUID(uuidString: "00000001-0002-0003-0000-000000000000")!
        /// Severity (optional, string)
        static let severity = UUID(uuidString: "00000001-0002-0004-0000-000000000000")!
        /// Treated by (optional, string)
        static let treatedBy = UUID(uuidString: "00000001-0002-0005-0000-000000000000")!
        /// Notes (optional, string, multiline)
        static let notes = UUID(uuidString: "00000001-0002-0006-0000-000000000000")!
        /// Attachment IDs (optional, attachmentIds)
        static let attachmentIds = UUID(uuidString: "00000001-0002-0007-0000-000000000000")!

        /// All field IDs in this schema
        static let allFields: [UUID] = [
            name, diagnosedDate, status, severity,
            treatedBy, notes, attachmentIds
        ]
    }

    // MARK: - Medication Schema (0003)

    /// Field IDs for the Medication schema
    enum Medication {
        /// Medication name (required, string)
        static let name = UUID(uuidString: "00000001-0003-0001-0000-000000000000")!
        /// Dosage (optional, string)
        static let dosage = UUID(uuidString: "00000001-0003-0002-0000-000000000000")!
        /// Frequency (optional, string)
        static let frequency = UUID(uuidString: "00000001-0003-0003-0000-000000000000")!
        /// Start date (optional, date)
        static let startDate = UUID(uuidString: "00000001-0003-0004-0000-000000000000")!
        /// End date (optional, date)
        static let endDate = UUID(uuidString: "00000001-0003-0005-0000-000000000000")!
        /// Prescribed by (optional, string)
        static let prescribedBy = UUID(uuidString: "00000001-0003-0006-0000-000000000000")!
        /// Pharmacy (optional, string)
        static let pharmacy = UUID(uuidString: "00000001-0003-0007-0000-000000000000")!
        /// Refills remaining (optional, int)
        static let refillsRemaining = UUID(uuidString: "00000001-0003-0008-0000-000000000000")!
        /// Notes (optional, string, multiline)
        static let notes = UUID(uuidString: "00000001-0003-0009-0000-000000000000")!
        /// Attachment IDs (optional, attachmentIds)
        static let attachmentIds = UUID(uuidString: "00000001-0003-000A-0000-000000000000")!

        /// All field IDs in this schema
        static let allFields: [UUID] = [
            name, dosage, frequency, startDate, endDate,
            prescribedBy, pharmacy, refillsRemaining, notes, attachmentIds
        ]
    }

    // MARK: - Allergy Schema (0004)

    /// Field IDs for the Allergy schema
    enum Allergy {
        /// Allergen (required, string)
        static let allergen = UUID(uuidString: "00000001-0004-0001-0000-000000000000")!
        /// Severity (optional, string)
        static let severity = UUID(uuidString: "00000001-0004-0002-0000-000000000000")!
        /// Reaction (optional, string)
        static let reaction = UUID(uuidString: "00000001-0004-0003-0000-000000000000")!
        /// Date diagnosed (optional, date)
        static let diagnosedDate = UUID(uuidString: "00000001-0004-0004-0000-000000000000")!
        /// Notes (optional, string, multiline)
        static let notes = UUID(uuidString: "00000001-0004-0005-0000-000000000000")!
        /// Attachment IDs (optional, attachmentIds)
        static let attachmentIds = UUID(uuidString: "00000001-0004-0006-0000-000000000000")!

        /// All field IDs in this schema
        static let allFields: [UUID] = [
            allergen, severity, reaction, diagnosedDate, notes, attachmentIds
        ]
    }

    // MARK: - Note Schema (0005)

    /// Field IDs for the Note schema
    enum Note {
        /// Title (required, string)
        static let title = UUID(uuidString: "00000001-0005-0001-0000-000000000000")!
        /// Content (optional, string, multiline)
        static let content = UUID(uuidString: "00000001-0005-0002-0000-000000000000")!
        /// Attachment IDs (optional, attachmentIds)
        static let attachmentIds = UUID(uuidString: "00000001-0005-0003-0000-000000000000")!

        /// All field IDs in this schema
        static let allFields: [UUID] = [title, content, attachmentIds]
    }

    // MARK: - All Built-in Field IDs

    /// All built-in field IDs across all schemas (for validation)
    static let allFieldIds: Set<UUID> = {
        var ids = Set<UUID>()
        ids.formUnion(Vaccine.allFields)
        ids.formUnion(Condition.allFields)
        ids.formUnion(Medication.allFields)
        ids.formUnion(Allergy.allFields)
        ids.formUnion(Note.allFields)
        return ids
    }()

    /// Check if a UUID is a built-in field ID
    static func isBuiltIn(_ uuid: UUID) -> Bool {
        allFieldIds.contains(uuid)
    }
}

// swiftlint:enable force_unwrapping
