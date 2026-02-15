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
    /// See `SensitiveDataType` for the complete list.
    case sensitive
}

/// Types of sensitive data that should NEVER be logged
///
/// This enum serves as compile-time documentation. These data types
/// should use `LogPrivacyLevel.sensitive` or not be logged at all.
///
/// **CRITICAL**: Per ADR-0002 and privacy analysis, these must NEVER appear in logs:
enum SensitiveDataType {
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

    /// Medical record content (diagnoses, medications, etc.)
    case medicalRecordContent

    /// Family member names - encrypted with FMK
    case familyMemberName

    /// Document attachments (photos, PDFs of medical records)
    case attachmentContent

    /// Raw biometric data or templates
    case biometricData
}
