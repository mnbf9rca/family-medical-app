# ADR-0012: JSON Schema Validation for Backup Files

## Status

Accepted

## Context

The backup file format is defined by both a JSON Schema (`docs/schemas/backup-v1.json`) and manually-written Swift models. This dual definition creates risk of drift between schema and code, and provides no runtime validation against malformed or malicious backup files.

Security concerns:

- Attackers could craft malicious `.fmabackup` files with unexpected fields
- Deeply nested structures could cause stack overflow (DoS)
- Type confusion attacks could exploit decoder quirks

## Decision

Adopt a **schema-validated** approach:

1. **JSON Schema defines the contract** - `docs/schemas/backup-v1.json` specifies the backup file format
2. **Swift models implement the contract** - Hand-written models provide Swift-idiomatic types with business logic
3. **Validate imports at runtime** - swift-json-schema validates JSON before decoding
4. **Enforce consistency through tests** - Unit tests serialize Swift models and validate against the schema
5. **Pre-commit hook validates schema** - Ensures the schema file is well-formed JSON Schema

### Why Not Code Generation?

We evaluated using Quicktype to generate Swift types from the schema but rejected this approach:

- **Type conflicts**: Generated types (e.g., `BackupFile`, `FieldValue`) conflict with existing idiomatic models
- **Lost business logic**: Existing models have conversion methods (`toPerson()`, `toRecordContent()`) that generated code lacks
- **Inferior Swift idioms**: Generated code uses `String` for UUIDs, adds unnecessary helper classes (`JSONAny`, `JSONNull`)
- **Quicktype limitations**: Bug #2653 breaks generation with integer const values in Draft 2020-12 schemas

Instead, consistency is enforced through:

1. **Runtime validation** - `BackupSchemaValidator` validates all imports
2. **Test-time validation** - Tests serialize Swift models and validate against the schema
3. **Pre-commit validation** - Schema file structure is validated

### DoS Protection

The validator enforces limits before schema validation:

- Maximum nesting depth: 20 levels (configurable)
- Maximum array size: 100,000 items (configurable)

### Version Strategy

- Schema version in filename: `backup-v1.json`, `backup-v2.json`
- Version also in `$id` URL and `formatVersion` field
- Old schemas kept for migration support

### Updating the Backup Format

When modifying the backup format, update **both** the schema and Swift models manually:

1. **Update the schema** - Edit `docs/schemas/backup-v1.json`:
   - Add/modify properties in the relevant `$defs` section
   - Update `required` arrays if adding required fields
   - Run `./scripts/validate-backup-schema.sh` to verify schema syntax

2. **Update Swift models** - Edit files in `Services/Backup/`:
   - Modify `BackupPayload`, `PersonBackup`, `MedicalRecordBackup`, etc.
   - Ensure `CodingKeys` match the JSON property names in the schema

3. **Run tests** - The schema-model consistency tests will fail if they're out of sync:

   ```bash
   ./scripts/run-tests.sh
   ```

   Look for failures in `BackupSchemaValidatorTests` - specifically:
   - `serializedBackupFileValidatesAgainstSchema`
   - `serializedUnencryptedBackupFileValidatesAgainstSchema`

4. **For breaking changes**, create a new schema version (`backup-v2.json`) and add migration logic.

## Consequences

### Positive

- Runtime validation provides defense-in-depth
- Swift models remain idiomatic with full business logic
- No external code generation dependencies (no Node.js/npm required)
- DoS protection against malicious files
- Tests verify schema-model consistency

### Negative

- Requires manual sync when schema changes
- Two places to update: schema and Swift models

### Neutral

- Schema is the authoritative specification for external consumers
- Swift models are the authoritative implementation for the app
