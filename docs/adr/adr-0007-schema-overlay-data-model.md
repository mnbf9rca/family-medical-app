# Schema-Overlay Data Model for Medical Records

## Status

**Status**: Accepted

## Context

The app needs to store various medical records (vaccines, medications, conditions, etc.). Users may want to track arbitrary medical information beyond predefined types.

Two architectural approaches were considered:

1. **Fixed Content Types**: Define specific structs for each record type (`VaccineContent`, `MedicationContent`, etc.)
2. **Schema-Overlay**: Generic content model with optional schemas for validation

The fixed approach requires code changes for new record types. The schema-overlay approach treats schemas as data, not code - similar to how wikis work (arbitrary content with optional structure).

## Decision

Use a **schema-overlay architecture** where:

- Records store arbitrary `[String: FieldValue]` content
- Schemas define field structure, validation, and display rules as data
- Built-in schemas provided for common types (vaccine, medication, condition, allergy, note)
- Users can create custom schemas or use freeform records (no schema)

Core models:

- `MedicalRecord`: Container with encrypted `data` (opaque to server)
- `RecordContent`: Decrypted payload with `schemaId` and type-safe field wrapper
- `RecordSchema`: Template defining fields and validation
- `FieldValue`: Enum for dynamic types (string, int, date, etc.)

**Person labels** use flexible string arrays instead of fixed relationship enums to avoid encoding nuclear-family assumptions.

## Consequences

### Positive

- Users can track any medical information without app updates
- Custom schemas enable domain-specific structures (sports medicine, chronic conditions, etc.)
- Simpler codebase: one generic model instead of 5+ specific content structs
- Forward-compatible with wiki-style versioning (already has `previousVersionId`)

### Negative

- Dynamic forms are more complex than fixed forms in UI
- Runtime validation instead of compile-time type safety
- Potential for schema drift if users modify custom schemas
- Query complexity increases (can't leverage struct field indexing)

### Neutral

- Encryption boundaries enhanced from ADR-0004: schemaId encrypted inside RecordContent
- Server remains zero-knowledge (sees only opaque blobs, personId for access control)
- Built-in schemas provide sensible defaults while allowing flexibility
