import Foundation

/// Privacy level for logged values
///
/// Determines how os.Logger redacts data in production builds.
/// See ADR-0002 and privacy-and-data-exposure-analysis.md for guidelines.
enum LogPrivacyLevel: Sendable {
    /// Value is public and will always appear in logs
    ///
    /// Use for: operation names, states, timestamps, record counts, error types
    case `public`

    /// Value is private and will be redacted in production builds
    ///
    /// Use for: email addresses, error messages with potential PII
    case `private`

    /// Value is sensitive and should NEVER be logged (placeholder logged instead)
    ///
    /// Use for compile-time safety when handling data that must never appear in logs
    /// even during development. See `SensitiveDataType` for examples.
    case sensitive

    /// Value will be hashed for correlation without revealing content
    ///
    /// Use for: record IDs, session IDs that need correlation but not exposure
    case hashed
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
