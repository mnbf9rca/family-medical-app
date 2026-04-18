# Logging Privacy and Export

## Status

**Status**: accepted

## Context

The app has centralised logging (LoggingService) but two problems prevent troubleshooting: (1) all error descriptions use `.private` privacy which os.Logger redacts in production, making errors invisible; (2) no mechanism exists for users to extract and share logs with the developer. Additionally, `.private` without hash mask shows as `<private>` in OSLogStore reads, making it useless for any export scenario.

## Decision

1. **Three-tier privacy model:** `.public` for non-PII data including error details, `.hashed` (maps to `.private(mask: .hash)`) for PII and medical content correlation, `.sensitive` for cryptographic material which is never passed to os.Logger. Drop `.private` level entirely.

2. **OSLogStore-based log export** with device metadata, user-selectable time window (1h/6h/24h/7d), presented via share sheet from Settings.

3. **TracingCategoryLogger decorator** for structured entry/exit logging with timing, preserving migration path to Swift macros.

Note: Apple's `.private(mask: .hash)` stores plaintext on disk and hashes at read time using a per-boot salt — hashes are stable within a session but change across reboots.

### Fields that must never be logged

The following field categories must never appear in logs at any privacy level (not even `.hashed`). Logging *metadata about* these items (counts, types, sizes) with `.public`, or hashed *identifiers/references* with `.hashed`, is permitted; logging the actual content is forbidden.

**Cryptographic / auth material** (see ADR-0002 for the key hierarchy):

- **Primary Key** — user Primary Key; device-only, never transmitted.
- **Family Member Key (FMK)** — encrypts medical records.
- **Private Key** — user Curve25519 private key for ECDH key exchange.
- **ECDH shared secret** — ephemeral, never stored.
- **Password** — user password; never transmitted or logged.
- **Password hash** — password hashes or verification tokens.
- **Biometric data** — raw biometric data or templates.

**PII / content** (log metadata only, never raw values):

- **Medical record content** — diagnoses, medications, etc. Log record counts/types with `.public`; never log diagnosis text.
- **Family member name** — encrypted with FMK. Log hashed identifiers with `.hashed`; never log plain names.
- **Attachment content** — document attachments (photos, PDFs of medical records). Log size/MIME type with `.public`; never log raw bytes (too large to hash).

## Consequences

### Positive

- Errors visible in production logs and exports
- Users can share diagnostic logs for support
- Entry/exit tracing enables flow reconstruction

### Negative

- `.public` error descriptions could theoretically expose internal details (file paths, Core Data errors) if device logs are accessed — mitigated by iOS sandboxing and data protection

### Neutral

- Not in scope: crash reporting, remote log collection, Swift macros
