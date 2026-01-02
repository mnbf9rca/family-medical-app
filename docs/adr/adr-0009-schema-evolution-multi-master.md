# Schema Evolution in Multi-Master Replication

## Status

**Status**: Proposed

## Context

The app will support multi-master replication where any device can modify schemas offline. This creates challenges:

- **Version collisions**: Device A and Device B both create "v2" independently - which wins?
- **Field ID collisions**: Two users add field id="notes" with different types - data corruption
- **No provenance**: Can't tell who created which field or when
- **No reversible hiding**: Fields can only be removed, not hidden (what happens to existing data?)

## Decision

### 1. UUID-Based Field IDs

Field IDs are auto-generated UUIDs, not user-provided strings. `displayName` becomes the human-friendly identifier.

**Rationale**: UUIDs are statistically unique across all devices - no coordination needed. Matches ADR-0004's async-first design.

### 2. Hybrid Logical Clock for Versions

Replace sequential `version: Int` with `(timestamp, deviceId, counter)` tuple.

**Rationale**: Sequential integers collide when two devices independently create the same version number. The hybrid clock ensures **uniqueness** - no two versions can ever be identical. Ordering is secondary; the primary goal is collision avoidance.

### 3. Schema Merge is Trivial (Set Union)

Schema merge is just a set union by field UUID:

- Different UUIDs = keep all fields (no conflict)
- Same UUID edited on both devices = pick one (timestamp or ask user)

**Rationale**: With UUID-based field IDs, there are no structural conflicts. Two devices adding fields independently just results in more fields. The only "conflict" is when the same field (same UUID) has different metadata (displayName, etc.) - ask user to pick.

### 4. Field Visibility State

Fields have visibility: `.active`, `.hidden`, `.deprecated`. Hidden fields keep their data in records.

**Rationale**: Users need to "remove" fields without losing existing data. Hidden fields can be restored later.

### 5. Device Identity for Provenance

Each app installation has a unique, persistent device ID (Keychain-stored). Fields track `createdBy` and `updatedBy` device IDs.

**Rationale**: Users need to know "who added this field?" for trust decisions and debugging. Also required for hybrid clock versioning.

---

See: `docs/technical/schema-evolution-design.md` for implementation details.

## Consequences

### Positive

- Collision-free field IDs across all devices
- Concurrent field additions from different devices preserved
- Auditable provenance (who created/modified what)
- Reversible field hiding (data preserved, can restore)
- Consistent with ADR-0004 async-first sync model

### Negative

- Less readable field IDs (UUIDs vs "vaccineName")
- Larger payloads (~100 bytes extra metadata per field)
- Migration complexity for existing string-based field IDs
- displayName collisions require user action to merge

### Neutral

- Device identity service required (useful for future per-device encryption keys)
- Field provenance is informational, not security (revoking device doesn't invalidate fields)

## Related Decisions

- **ADR-0004**: Sync Encryption (async-first, last-write-wins pattern)
- **ADR-0007**: Schema-Overlay Data Model (flexible field structures)
- **Issue #71**: Convert built-in schemas to prebuilt (uses deterministic UUIDs)
- **Issue #72**: Schema migration support (✅ complete - provides local migration capabilities for type conversion, field removal, and field merging that can be used when displayName collisions require consolidation)
