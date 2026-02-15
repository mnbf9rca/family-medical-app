import Foundation

/// Privacy level for logged values
///
/// Determines how os.Logger redacts data in production builds.
/// See ADR-0013 for the three-tier privacy model.
enum LogPrivacyLevel: Sendable {
    /// Value is public and will always appear in logs
    ///
    /// Use for: operation names, states, timestamps, record counts, error types,
    /// error descriptions, file paths, UUIDs
    case `public`

    /// Value will be hashed for correlation without revealing content
    ///
    /// Uses Apple's `.private(mask: .hash)` — stores plaintext on disk,
    /// hashes at read time with a per-boot salt. Hash is stable within a
    /// session for correlation but changes across reboots.
    ///
    /// Use for: person names, email addresses, medical record content,
    /// attachment content — anything that is PII or sensitive content
    /// but needs correlation capability.
    case hashed

    /// Value is sensitive and should NEVER be logged
    ///
    /// A hardcoded "[REDACTED]" placeholder is logged instead.
    /// The actual value is never passed to os.Logger at all.
    ///
    /// Use for: encryption keys, passwords, ECDH secrets, biometric data.
    /// See `NeverLogDataType` for the complete list.
    case sensitive
}

/// Data types whose **raw values** must NEVER be passed to a logger.
///
/// This enum serves as compile-time documentation. Raw values of these
/// types must never appear in log statements — not even with `.hashed`.
///
/// **Permitted:** Logging *metadata about* these items (counts, types, sizes)
/// with `.public`, or hashed *identifiers/references* with `.hashed`.
///
/// **Forbidden:** Logging the actual content (key bytes, password text,
/// diagnosis text, image data, person names).
///
/// Examples:
/// ```swift
/// // OK — metadata about records
/// logger.debug("Imported \(recordCount) records", privacy: .public)
/// // OK — attachment size, not content
/// logger.info("Processing attachment size=\(bytes)B type=\(mimeType)", privacy: .public)
/// // FORBIDDEN — raw content
/// logger.debug("Record content: \(diagnosisText)")
/// // FORBIDDEN — raw binary data
/// logger.debug("Attachment data: \(imageBytes)")
/// ```
///
/// **CRITICAL**: Per ADR-0002 and privacy analysis:
enum NeverLogDataType {
    // MARK: - Cryptographic / Auth Material

    /// User Primary Key (Primary Key) - device-only, never transmitted
    case primaryKey

    /// Family Member Keys (FMKs) - encrypt medical records
    case familyMemberKey

    /// User Private Key (Curve25519) - for ECDH key exchange
    case privateKey

    /// ECDH shared secrets - ephemeral, never stored
    case ecdhSecret

    /// User passwords - never transmitted or logged
    case password

    /// Password hashes or verification tokens
    case passwordHash

    /// Raw biometric data or templates
    case biometricData

    // MARK: - PII / Content (log metadata only, never raw values)

    /// Medical record content (diagnoses, medications, etc.)
    /// Log record counts/types with `.public`; never log diagnosis text.
    case medicalRecordContent

    /// Family member names - encrypted with FMK
    /// Log hashed identifiers with `.hashed`; never log plain names.
    case familyMemberName

    /// Document attachments (photos, PDFs of medical records)
    /// Log size/MIME type with `.public`; never log raw bytes (too large to hash).
    case attachmentContent
}
