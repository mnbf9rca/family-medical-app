import Foundation

/// Privacy level for logged values
///
/// Determines how os.Logger redacts data in production builds.
/// See ADR-0013 for the three-tier privacy model.
enum LogPrivacyLevel {
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
    /// See ADR-0013 §"Fields that must never be logged" for the complete list.
    case sensitive
}
