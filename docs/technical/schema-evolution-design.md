# Schema Evolution Design for Multi-Master Replication

This document provides implementation details for ADR-0009 (Schema Evolution in Multi-Master Replication).

## Problem Scenarios

### Scenario 1: Version Collision

```
Device A (offline): schema v1 → adds "severity" field → v2
Device B (offline): schema v1 → adds "notes" field → v2
Sync: Both upload v2. Which wins?
Result: Lost changes - one device's field is discarded.
```

**Solution**: Hybrid logical clock versioning + field-level merge.

### Scenario 2: Field ID Collision

```
Device A: adds field id="impact", type=string (for "Impact Zone")
Device B: adds field id="impact", type=int (for "Impact Score")
Sync: Same ID, different types.
Result: Data corruption - records using one type interpreted as the other.
```

**Solution**: UUID-based field IDs - collision impossible.

### Scenario 3: Field Lifecycle

```
User hides "batchNumber" field because it's rarely used.
Questions:
- What happens to records that have batchNumber data?
- Can the field be restored later with its data?
```

**Solution**: Visibility state - hidden fields keep data in records.

---

## Field Definition Changes

### Current Implementation

```swift
struct FieldDefinition {
    let id: String              // User-provided, collision risk
    let displayName: String
    let fieldType: FieldType
    let isRequired: Bool
    // ...
}
```

### New Implementation

```swift
struct FieldDefinition: Codable, Equatable, Hashable, Identifiable {
    // Identity (immutable after creation)
    let id: UUID                    // Auto-generated, globally unique
    let fieldType: FieldType        // Cannot change after creation

    // Display (mutable)
    var displayName: String         // User-visible label
    var isRequired: Bool
    var displayOrder: Int
    var placeholder: String?
    var helpText: String?
    var validationRules: [ValidationRule]
    var isMultiline: Bool
    var capitalizationMode: TextCapitalizationMode

    // Visibility (mutable)
    var visibility: FieldVisibility // .active, .hidden, .deprecated

    // Provenance (immutable after creation)
    let createdBy: UUID             // Device ID that created this field
    let createdAt: Date             // When field was created

    // Update tracking (mutable)
    var updatedBy: UUID             // Device ID that last modified
    var updatedAt: Date             // When last modified
}

enum FieldVisibility: String, Codable {
    case active       // Normal field, shown in UI
    case hidden       // Not shown, data preserved (can be restored)
    case deprecated   // Hidden + warning if old records have data
}
```

### UUID.zero Sentinel

```swift
extension UUID {
    /// Sentinel value for "system" or "unknown" device
    static let zero = UUID(uuid: (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0))
}
```

Used for built-in fields where `createdBy` has no meaningful device.

---

## Schema Version Structure

### Current Implementation

```swift
struct RecordSchema {
    var version: Int  // Sequential - fails in multi-master
}
```

### New Implementation: Hybrid Logical Clock

```swift
struct SchemaVersion: Codable, Comparable, Hashable {
    let timestamp: Date       // Wall clock (human-meaningful ordering)
    let deviceId: UUID        // Tie-breaker for same timestamp
    let counter: UInt64       // Monotonic counter per device

    static func < (lhs: SchemaVersion, rhs: SchemaVersion) -> Bool {
        // Compare by timestamp first (most common case)
        if lhs.timestamp != rhs.timestamp {
            return lhs.timestamp < rhs.timestamp
        }
        // Tie-breaker: device ID (deterministic ordering)
        if lhs.deviceId != rhs.deviceId {
            return lhs.deviceId.uuidString < rhs.deviceId.uuidString
        }
        // Final tie-breaker: counter
        return lhs.counter < rhs.counter
    }

    /// Create a new version for the current device
    static func now(deviceId: UUID, previousCounter: UInt64 = 0) -> SchemaVersion {
        SchemaVersion(
            timestamp: Date(),
            deviceId: deviceId,
            counter: previousCounter + 1
        )
    }
}
```

**Why Hybrid Clock?**

The primary goal is **uniqueness** - no two versions can ever be identical. Ordering is secondary.

| Approach | Pros | Cons |
|----------|------|------|
| Sequential Int | Simple | Collides in multi-master (both create v2) |
| Timestamp only | Human readable | Collides if same millisecond |
| Hybrid clock | Unique + readable | Slightly larger (~24 bytes vs 4 bytes) |

---

## Schema Merge is Trivial

Schema merge is just a **set union by field UUID**. No complex conflict resolution needed.

### The Algorithm

```swift
func mergeSchemas(_ local: RecordSchema, _ remote: RecordSchema) -> RecordSchema {
    // Set union by UUID - that's it
    var mergedFields: [UUID: FieldDefinition] = [:]

    for field in local.fields {
        mergedFields[field.id] = field
    }

    for field in remote.fields {
        if let existing = mergedFields[field.id] {
            // Same UUID edited on both devices - ask user to pick
            // Or use timestamp if non-interactive sync
            if field.updatedAt > existing.updatedAt {
                mergedFields[field.id] = field
            }
        } else {
            // Different UUID = different field, keep both
            mergedFields[field.id] = field
        }
    }

    return RecordSchema(
        id: local.id,
        fields: Array(mergedFields.values).sorted { $0.displayOrder < $1.displayOrder },
        // ... other metadata uses newer version
    )
}
```

### Why It's Simple

| Scenario | What Happens |
|----------|--------------|
| Device A adds "Notes", Device B adds "Severity" | Both kept (different UUIDs) |
| Both devices add "Notes" independently | Both kept (different UUIDs, same displayName is fine) |
| Both edit the SAME field's displayName | Only true conflict: ask user to pick |

### displayName Duplicates Are Not Conflicts

Two fields can have the same displayName - they're still different fields with different UUIDs. The UI just shows both.

If user wants to consolidate them into one field, that's a **data migration** (Issue #72), not a schema merge. Migration would remap record data from one field UUID to another.

---

## Device Identity

### DeviceIdentityService

```swift
protocol DeviceIdentityServiceProtocol: Sendable {
    var currentDeviceId: UUID { get async throws }
    var currentDeviceName: String? { get async }
    func updateDeviceName(_ name: String) async throws
}

final class DeviceIdentityService: DeviceIdentityServiceProtocol {
    private let keychain: KeychainServiceProtocol

    private static let deviceIdKey = "device-identity-id"
    private static let deviceNameKey = "device-identity-name"

    var currentDeviceId: UUID {
        get async throws {
            // Try to load from Keychain
            if let data = try? await keychain.load(key: Self.deviceIdKey),
               let uuid = UUID(data: data) {
                return uuid
            }

            // Generate new ID on first launch (or after reinstall - iOS 10.3+ clears Keychain on uninstall)
            let newId = UUID()
            try await keychain.save(key: Self.deviceIdKey, data: newId.data)
            return newId
        }
    }

    var currentDeviceName: String? {
        get async {
            // Try stored name first
            if let data = try? await keychain.load(key: Self.deviceNameKey),
               let name = String(data: data, encoding: .utf8) {
                return name
            }

            // Fall back to system device name
            #if os(iOS)
            return await UIDevice.current.name
            #elseif os(macOS)
            return Host.current().localizedName
            #endif
        }
    }
}
```

### Device Registry

Synced to server **encrypted** (like all user data per ADR-0004):

```swift
struct DeviceRegistry: Codable {
    var devices: [UUID: DeviceInfo]
}

struct DeviceInfo: Codable {
    let id: UUID
    var name: String?           // PII - must be encrypted
    let firstSeen: Date
    var lastSeen: Date
    var isRevoked: Bool         // Soft-delete
}
```

Server sees only the encrypted blob - cannot see device names or count.

**Device Revocation**:

- Marks device as revoked in registry
- Shows "(revoked)" in provenance UI
- Does NOT affect field validity or data access (that's ADR-0004/0005)
- Purely informational for audit trail

---

## Test Scenarios

1. **Concurrent field addition**: Device A adds "Notes", Device B adds "Severity" → both preserved
2. **Same-field edit**: Device A and B both edit field X → newer timestamp wins
3. **displayName collision**: Both add "Notes" with different UUIDs → warning shown
4. **Field hiding**: Hide field → data preserved → restore field → data visible
5. **Device provenance**: New field shows "Created by iPad on Jan 2"
