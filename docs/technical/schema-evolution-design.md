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

### Migration from String to UUID

For backward compatibility:

```swift
extension FieldDefinition {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Try UUID first (new format)
        if let uuid = try? container.decode(UUID.self, forKey: .id) {
            self.id = uuid
        } else {
            // Fall back to string (old format) - generate deterministic UUID
            let stringId = try container.decode(String.self, forKey: .id)
            self.id = Self.deterministicUUID(from: stringId)
            // Use stringId as displayName if not already set
            self.displayName = (try? container.decode(String.self, forKey: .displayName)) ?? stringId
        }

        // Provenance defaults for migrated fields
        self.createdBy = (try? container.decode(UUID.self, forKey: .createdBy)) ?? UUID.zero
        self.createdAt = (try? container.decode(Date.self, forKey: .createdAt)) ?? Date.distantPast
        self.updatedBy = (try? container.decode(UUID.self, forKey: .updatedBy)) ?? UUID.zero
        self.updatedAt = (try? container.decode(Date.self, forKey: .updatedAt)) ?? Date.distantPast
        self.visibility = (try? container.decode(FieldVisibility.self, forKey: .visibility)) ?? .active

        // ... other properties
    }

    /// Generate deterministic UUID from string (for migration and built-in fields)
    static func deterministicUUID(from string: String) -> UUID {
        let hash = SHA256.hash(data: Data(string.utf8))
        let bytes = Array(hash.prefix(16))
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}

extension UUID {
    /// Sentinel value for "system" or "unknown" device
    static let zero = UUID(uuid: (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0))
}
```

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

| Approach | Pros | Cons |
|----------|------|------|
| Sequential Int | Simple | Fails in multi-master |
| Timestamp only | Human readable | Clock skew causes incorrect ordering |
| Vector clock | Correct | Complex, grows with devices |
| Hybrid clock | Correct + readable | Slightly larger (~24 bytes vs 4 bytes) |

---

## Merge Algorithm

### Field-Level Union

When syncing two versions of the same schema:

```swift
func mergeSchemas(_ local: RecordSchema, _ remote: RecordSchema) -> RecordSchema {
    var mergedFields: [UUID: FieldDefinition] = [:]

    // Add all local fields
    for field in local.fields {
        mergedFields[field.id] = field
    }

    // Merge remote fields
    for field in remote.fields {
        if let existing = mergedFields[field.id] {
            // Same UUID: last-write-wins on this field
            if field.updatedAt > existing.updatedAt {
                mergedFields[field.id] = field
            }
        } else {
            // New field from remote: add it
            mergedFields[field.id] = field
        }
    }

    // Schema-level metadata: use newer version
    let newerVersion = local.version > remote.version ? local : remote

    return RecordSchema(
        id: local.id,  // Schema ID doesn't change
        displayName: newerVersion.displayName,
        iconSystemName: newerVersion.iconSystemName,
        fields: Array(mergedFields.values).sorted { $0.displayOrder < $1.displayOrder },
        isBuiltIn: local.isBuiltIn,
        description: newerVersion.description,
        version: max(local.version, remote.version)
    )
}
```

### displayName Collision Detection

After merge, detect and warn about fields with same displayName:

```swift
func detectDisplayNameCollisions(_ schema: RecordSchema) -> [(FieldDefinition, FieldDefinition)] {
    var collisions: [(FieldDefinition, FieldDefinition)] = []
    var byName: [String: FieldDefinition] = [:]

    for field in schema.fields where field.visibility == .active {
        if let existing = byName[field.displayName] {
            collisions.append((existing, field))
        } else {
            byName[field.displayName] = field
        }
    }

    return collisions
}
```

UI shows warning: "Two fields named 'Notes' exist (from iPad and iPhone)". User can:

1. Rename one field
2. Merge fields (triggers migration - see Issue #72)

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

            // Generate new ID on first launch
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

Synced to server for device list UI:

```swift
struct DeviceRegistry: Codable {
    var devices: [UUID: DeviceInfo]
}

struct DeviceInfo: Codable {
    let id: UUID
    var name: String?
    let firstSeen: Date
    var lastSeen: Date
    var isRevoked: Bool  // Soft-delete
}
```

**Device Revocation**:

- Marks device as revoked in registry
- Shows "(revoked)" in provenance UI
- Does NOT affect field validity or data access (that's ADR-0004/0005)
- Purely informational for audit trail

---

## Migration Path

### Phase 1: Add New Properties (Backward Compatible)

1. Add new optional properties with defaults in decoder
2. Existing schemas decode successfully
3. New saves include full metadata

### Phase 2: Built-In Schema UUIDs

Built-in field IDs use deterministic UUIDs:

```swift
// Old: FieldDefinition(id: "vaccineName", ...)
// New: FieldDefinition(id: deterministicUUID("vaccine:vaccineName"), ...)

static func builtInFieldId(schemaId: String, fieldId: String) -> UUID {
    deterministicUUID(from: "\(schemaId):\(fieldId)")
}
```

This ensures:

- Same UUID across all app versions
- Records created with old field IDs still match

### Phase 3: First Sync After Upgrade

When syncing after upgrade:

1. Detect old-format schema (version: Int instead of SchemaVersion)
2. Migrate to new format
3. Upload migrated schema
4. Remote devices receive new format

---

## Record Storage Impact

Records store field values by field ID:

```swift
struct RecordContent {
    var fields: [String: FieldValue]  // Currently String keys
}
```

After migration to UUID:

```swift
struct RecordContent {
    var fields: [UUID: FieldValue]  // UUID keys
}
```

**Migration**:

1. On decode, if key is String, convert using `deterministicUUID(from:)`
2. On encode, always use UUID
3. Records remain compatible because same string → same UUID

---

## Test Scenarios

1. **Concurrent field addition**: Device A adds "Notes", Device B adds "Severity" → both preserved
2. **Same-field edit**: Device A and B both edit field X → newer timestamp wins
3. **displayName collision**: Both add "Notes" with different UUIDs → warning shown
4. **Field hiding**: Hide field → data preserved → restore field → data visible
5. **Device provenance**: New field shows "Created by iPad on Jan 2"
6. **Migration**: Old string-ID schema → new UUID schema → records still work
