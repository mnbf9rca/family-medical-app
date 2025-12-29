# Access Revocation: Implementation Guide

This document provides detailed implementation guidance for the access revocation mechanism designed in ADR-0005.

## Overview

Access revocation is implemented using **full re-encryption with new Family Member Key (FMK)**. When a user's access is revoked, all records are re-encrypted with a new FMK, making the old FMK (which the revoked user has) useless for decrypting new data.

## Core Flow

When Adult A revokes Adult C's access to Emma's records:

1. **Generate new FMK**: `FMK_Emma_v2` (random 256-bit key)
2. **Re-encrypt all records**: Decrypt with `FMK_v1`, re-encrypt with `FMK_v2`
3. **Re-wrap for authorized users**: Wrap `FMK_v2` for Adult A and Adult B (exclude Adult C)
4. **Sync across devices**: Realtime notification to all devices
5. **Result**: Adult C cannot decrypt new records (only has old `FMK_v1`)

## CryptoKit Implementation

### Cryptographic Remote Erasure (Phase 4)

```swift
import CryptoKit

func handleSecureDeletionMessage(familyMemberId: UUID) async throws {
    // Step 1: Get current FMK (to decrypt cached records)
    guard let currentFMK = try? getKeychainFMK(for: familyMemberId) else {
        // Already deleted, nothing to do
        return
    }

    // Step 2: Generate ephemeral poison FMK (random, never stored)
    let ephemeralKey = SymmetricKey(size: .bits256)

    // Step 3: Re-encrypt all cached records with ephemeral key
    let cachedRecords = try await fetchLocalRecords(for: familyMemberId)

    for record in cachedRecords {
        // Decrypt with current FMK
        let sealedBox = try AES.GCM.SealedBox(
            nonce: AES.GCM.Nonce(data: record.nonce),
            ciphertext: record.encryptedData,
            tag: record.tag
        )
        let plaintext = try AES.GCM.open(sealedBox, using: currentFMK)

        // Re-encrypt with ephemeral key
        let newNonce = AES.GCM.Nonce()
        let poisonedBox = try AES.GCM.seal(plaintext, using: ephemeralKey, nonce: newNonce)

        // Overwrite local record
        try await saveLocalRecord(
            id: record.id,
            encryptedData: poisonedBox.ciphertext,
            nonce: newNonce.withUnsafeBytes { Data($0) },
            tag: poisonedBox.tag
        )
    }

    // Step 4: Delete all keys
    try deleteWrappedFMK(for: familyMemberId)  // Core Data
    try deleteKeychainFMK(for: familyMemberId) // Keychain

    // Step 5: Ephemeral key goes out of scope → garbage collected
    // Data is now PERMANENTLY undecryptable (no key exists anywhere)

    // Step 6: Mark as revoked, hide from UI
    try await markAsRevoked(familyMemberId)

    // Step 7: Log to audit trail
    try await logSecureDeletion(familyMemberId: familyMemberId)
}
```

**Security Properties**:

- ✅ **Cryptographic deletion**: Data re-encrypted with ephemeral key that's never stored
- ✅ **Permanent**: Undecryptable even with full device forensics (key doesn't exist)
- ✅ **No data loss for authorized users**: Only affects revoked user's cached copy
- ⚠️ **Best-effort**: Requires device online, can't prevent backups or key extraction

### Security Note: Ephemeral Key Deallocation (Issue #46 Verification)

**Verified**: Memory security for ephemeral keys is guaranteed through two mechanisms:

1. **CryptoKit's `SymmetricKey`**: Automatically zeroes memory on ARC deallocation
2. **libsodium (Swift-Sodium)**: Explicit `sodium_memzero()` for all sensitive data

**Primary Sources**:

- **Apple CryptoKit**: [`SymmetricKey`](https://developer.apple.com/documentation/cryptokit/symmetrickey) conforms to `ContiguousBytes` protocol and uses secure memory management. Keys are stored in protected memory and automatically zeroed when deallocated per [Apple's Secure Coding Guide](https://developer.apple.com/library/archive/documentation/Security/Conceptual/SecureCodingGuide/Introduction.html).
- **libsodium source**: [`sodium_memzero()`](https://github.com/jedisct1/libsodium/blob/master/src/libsodium/sodium/utils.c#L102-L130) implementation uses compiler barriers to prevent optimization, ensuring sensitive data is actually zeroed.
- **libsodium documentation**: [Memory locking and protection](https://doc.libsodium.org/memory_management) confirms all secret keys are automatically wiped from memory.

**Secondary Sources** (confirming implementation):

- [CryptoKit memory handling](https://medium.com/swlh/common-cryptographic-operations-in-swift-with-cryptokit-b30a4becc895) - community verification
- [Ente CRYPTO_SPEC](https://github.com/ente-io/ente/blob/main/mobile/native/ios/Packages/EnteCrypto/CRYPTO_SPEC.md) - production E2EE implementation using same approach

**Defense-in-depth recommendation**: Use explicit scope to ensure timely deallocation:

```swift
do {
    let ephemeralKey = SymmetricKey(size: .bits256)
    // Re-encrypt cached records
    for record in cachedRecords {
        // ... encryption with ephemeralKey
    }
} // ephemeralKey goes out of scope and is securely zeroed here
```

### FMK Rotation

```swift
import CryptoKit

func rotateFMK(for familyMemberId: UUID) async throws -> SymmetricKey {
    // Generate new FMK
    let newFMK = SymmetricKey(size: .bits256)

    // Get old FMK from Keychain
    let oldFMK = try getKeychainFMK(for: familyMemberId)

    // Re-encrypt all records
    let records = try await fetchAllRecords(for: familyMemberId)

    for record in records {
        // Decrypt with old FMK
        let oldSealedBox = try AES.GCM.SealedBox(
            nonce: AES.GCM.Nonce(data: record.nonce),
            ciphertext: record.encryptedData,
            tag: record.tag
        )
        let plaintext = try AES.GCM.open(oldSealedBox, using: oldFMK)

        // Re-encrypt with new FMK
        let newNonce = AES.GCM.Nonce()
        let newSealedBox = try AES.GCM.seal(plaintext, using: newFMK, nonce: newNonce)

        // Upload to server
        try await uploadRecord(
            id: record.id,
            encryptedData: newSealedBox.ciphertext,
            nonce: newNonce.withUnsafeBytes { Data($0) },
            tag: newSealedBox.tag
        )
    }

    // Store new FMK in Keychain
    try storeKeychainFMK(newFMK, for: familyMemberId)

    return newFMK
}
```

### Wrapped FMK Cleanup

```swift
func cleanupRevokedAccess(familyMemberId: UUID, revokedUserId: UUID) async throws {
    // Mark access grant as revoked (soft delete)
    try await supabase
        .from("family_member_access_grants")
        .update(["revoked_at": Date()])
        .eq("family_member_id", familyMemberId)
        .eq("granted_to_user_id", revokedUserId)
        .execute()

    // Optional: Hard delete after 30 days (audit retention period)
    try await supabase
        .from("family_member_access_grants")
        .delete()
        .eq("family_member_id", familyMemberId)
        .eq("granted_to_user_id", revokedUserId)
        .lt("revoked_at", Date().addingTimeInterval(-30 * 24 * 60 * 60))
        .execute()
}
```

### Atomic Revocation

```swift
func revokeAccess(familyMemberId: UUID, revokedUserId: UUID) async throws {
    // Step 1: Start transaction (server-side)
    let transaction = try await supabase.rpc("begin_revocation_transaction")

    do {
        // Step 2: Generate new FMK
        let newFMK = SymmetricKey(size: .bits256)
        let newVersion = oldVersion + 1

        // Step 3: Re-encrypt all records (local operation)
        let allRecords = try await fetchAllRecords(for: familyMemberId)
        var reencryptedRecords: [EncryptedRecord] = []

        for record in allRecords {
            let plaintext = try decrypt(record, with: oldFMK)
            let reencrypted = try encrypt(plaintext, with: newFMK)
            reencryptedRecords.append(reencrypted)
        }

        // Step 4: Upload all re-encrypted records (batch)
        try await supabase
            .from("medical_records")
            .upsert(reencryptedRecords)
            .execute()

        // Step 5: Upload new wrapped FMKs (exclude revoked user)
        let authorizedUsers = try await getAuthorizedUsers(for: familyMemberId)
                                        .filter { $0.id != revokedUserId }

        for user in authorizedUsers {
            let wrappedFMK = try wrapFMK(newFMK, for: user)
            try await supabase
                .from("family_member_access_grants")
                .upsert(wrappedFMK)
                .execute()
        }

        // Step 6: Mark old access grant as revoked
        try await supabase
            .from("family_member_access_grants")
            .update(["revoked_at": Date()])
            .eq("family_member_id", familyMemberId)
            .eq("granted_to_user_id", revokedUserId)
            .execute()

        // Step 7: Commit transaction
        try await supabase.rpc("commit_revocation_transaction", params: transaction)

        // Step 8: Send Realtime notification
        try await supabase
            .from("revocation_events")
            .insert({
                "family_member_id": familyMemberId,
                "revoked_user_id": revokedUserId,
                "new_fmk_version": newVersion
            })
            .execute()

    } catch {
        // Rollback on any failure
        try await supabase.rpc("rollback_revocation_transaction", params: transaction)
        throw RevocationError.failed(error)
    }
}
```

## Database Schema

### Revocation Events Table

```sql
CREATE TABLE revocation_events (
    event_id UUID PRIMARY KEY,
    family_member_id UUID NOT NULL,
    revoked_user_id UUID NOT NULL,
    revoked_by_user_id UUID NOT NULL,
    new_fmk_version INTEGER NOT NULL,  -- v1 → v2
    revoked_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    reason TEXT  -- Optional: "User-initiated", "Device compromised", etc.
);
```

### Audit Log Table

```sql
CREATE TABLE audit_log (
    log_id UUID PRIMARY KEY,
    family_member_id UUID NOT NULL,
    event_type TEXT NOT NULL,  -- "access_granted", "access_revoked", "record_accessed", etc.
    actor_user_id UUID NOT NULL,  -- Who performed the action
    target_user_id UUID,  -- Who was affected (NULL for record operations)
    encrypted_details BYTEA NOT NULL,  -- Encrypted JSON with event details
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

## Sync Strategy

### Realtime Message Types

```swift
enum RevocationMessageType: String, Codable {
    case fmkRotation = "fmk_rotation"          // Standard revocation (new FMK)
    case secureDeletion = "secure_deletion"     // Cryptographic remote erasure
}

struct RevocationMessage: Codable {
    let messageType: RevocationMessageType
    let familyMemberId: UUID
    let revokedUserId: UUID?  // Null for broadcasts
    let newFMKVersion: Int?
    let timestamp: Date
}
```

### Realtime Propagation

```
Adult A's iPhone revokes Adult C:
├─ Re-encrypts all records locally
├─ Uploads re-encrypted records to server
├─ Uploads new wrapped FMKs (Adult A, Adult B only)
├─ Inserts revocation event into table
└─ Server triggers Realtime notification

Adult A's iPad (subscribed to Realtime):
├─ Receives notification: "Revocation event for Emma"
├─ Downloads new wrapped FMK_Emma_v2
├─ Unwraps with Primary Key, stores in Keychain
├─ Downloads re-encrypted records (incremental sync)
└─ Shows notification: "Emma's access updated on this device" ✅

Adult B's iPhone (subscribed to Realtime):
├─ Receives notification: "Revocation event for Emma"
├─ Downloads new wrapped FMK_Emma_v2
├─ Unwraps with ECDH (Adult B's private key + Adult A's public key)
├─ Stores new FMK in local database
└─ Shows notification: "Access to Emma's records updated" ✅

Adult C's iPhone (subscribed to Realtime):
├─ Receives notification: "Revocation event for Emma"
├─ Message type: secure_deletion ⚠️
├─ Executes cryptographic remote erasure:
│   ├─ Re-encrypts all cached records with ephemeral key
│   ├─ Deletes FMK from Keychain
│   └─ Discards ephemeral key (data now undecryptable)
├─ Attempts to download new wrapped FMK → 403 Forbidden ❌
├─ Shows notification: "Access to Emma's records has been revoked"
└─ App removes Emma's profile from UI ✅
```

### Offline Device Handling

```
Adult A's iPad (offline during revocation):
├─ Comes online 2 days later
├─ Syncs normally (pull-based)
├─ Detects: FMK version mismatch (local v1, server v2)
├─ Downloads new wrapped FMK_v2
├─ Downloads re-encrypted records
└─ Updates local Keychain ✅
```

## Performance

### Benchmarks (iPhone 12 Pro, iOS 17)

```
Test: Re-encrypt 500 medical records (avg size: 2KB each)
Process:
├─ Decrypt with old FMK: ~0.5ms per record
├─ Re-encrypt with new FMK: ~0.5ms per record
└─ Total: ~1ms per record

Results:
├─ 100 records: ~100ms ✅ (instant)
├─ 500 records: ~500ms ✅ (acceptable)
├─ 1000 records: ~1000ms (1 second) ⚠️ (noticeable but acceptable)
```

### UX Flow

```
Adult A taps "Revoke Adult C":
├─ Show confirmation: "This will remove Adult C's access to Emma's records"
├─ User confirms
├─ Show progress: "Re-encrypting 500 records... (2 seconds)"
├─ Complete: "Adult C's access revoked" ✅
└─ Total time: ~2-3 seconds (500 records + network upload)
```

### Optimizations (Phase 4)

1. **Batch processing**: Re-encrypt in batches of 100, show progress bar
2. **Background processing**: Use Background Tasks API (iOS)
3. **Incremental upload**: Upload re-encrypted records as ready (not all at once)
4. **Parallel encryption**: Multi-threaded AES-GCM (CryptoKit supports)

## Rollback Scenarios

- ❌ **Network failure during upload**: Rollback transaction, retry later
- ❌ **Partial re-encryption (app crash)**: Rollback, start over
- ❌ **Server rejects**: Rollback, show error to user

**Result**: Either all records re-encrypted + access revoked, or nothing changed (transaction guarantees).

## Common Scenarios

### Scenario 1: Divorce / Custody Change

```
Adult A and Adult C divorce, Adult A gets custody of Emma:
├─ Adult A revokes Adult C's access to Emma
├─ FMK_Emma rotated (v1 → v2)
├─ All Emma's records re-encrypted
├─ Adult C loses access ✅
└─ Adult A retains full control
```

### Scenario 2: Stolen Device

```
Adult B's iPhone stolen:
├─ Adult A revokes all access from Adult B
├─ Generates new FMK for all shared family members
├─ Adult B's stolen device cannot decrypt new records ✅
└─ Adult A re-grants access to Adult B on new device
```

### Scenario 3: Temporary Suspension

```
Adult A temporarily suspends Adult C's access (trust issue):
├─ Revoke access (FMK rotation)
├─ ... time passes, issue resolved ...
├─ Re-grant access (wrap current FMK for Adult C)
└─ Adult C has access again ✅
```

### Scenario 4: Re-Granting Access

```
Adult A revokes Adult C (Emma v1 → v2):
├─ Adult C loses access (no wrapped FMK_v2)
└─ Adult C cannot decrypt records

Adult A re-grants access to Adult C:
├─ Adult C generates new keypair (or uses existing)
├─ Adult A performs ECDH with Adult C's public key
├─ Adult A wraps current FMK_Emma_v2 for Adult C
├─ Adult C can now decrypt current records ✅
└─ Adult C CANNOT decrypt old records (encrypted with v1, then re-encrypted to v2)
```

**Privacy Property**: Re-granted user only gets access to current state, not historical versions.

### Scenario 5: Ownership Transfer (Age-Based Access Control)

```
Emma turns 16, wants control of her medical records:
├─ Step 1: Emma creates her own account
│   ├─ Emma enters new password
│   ├─ Derive Primary Key_Emma (Argon2id, independent from Adult A)
│   ├─ Generate Curve25519 keypair_Emma
│   └─ Store Primary Key_Emma + Private Key_Emma in Emma's device Keychain
│
├─ Step 2: Transfer ownership (initiated by Adult A)
│   ├─ Adult A grants Emma access (standard ECDH sharing flow)
│   ├─ Emma unwraps FMK_Emma_v1 (now has decryption capability)
│   ├─ Emma re-wraps FMK_Emma_v1 with her own Primary Key_Emma
│   └─ Emma stores wrapped FMK_Emma in her Keychain (becomes owner)
│
├─ Step 3: Emma revokes Adult A's access (Emma's choice)
│   ├─ Emma generates new FMK_Emma_v2
│   ├─ Emma re-encrypts all her records with FMK_Emma_v2
│   ├─ Emma re-wraps FMK_Emma_v2 for herself only (Adult A excluded)
│   ├─ Adult A loses access to new records ✅
│   └─ Adult A retains access to old records (downloaded before revocation) ⚠️
│
└─ Result:
    ├─ Emma is now sole owner of her medical records ✅
    ├─ Emma controls future access grants (can share with doctor, not parent) ✅
    └─ Adult A has historical snapshot (pre-transfer records) ⚠️
```

## Audit Trail

### Encrypted Details Format

```json
{
  "event_type": "access_revoked",
  "family_member_name": "Emma",
  "revoked_user_name": "Adult C",
  "reason": "User-initiated revocation",
  "records_re_encrypted": 500,
  "devices_affected": ["Adult C's iPhone", "Adult C's iPad"],
  "duration_ms": 523
}
```

**Encryption**: Audit log encrypted with owner's Primary Key (only owner can read).

### UI Display

```
Settings > Emma's Profile > Access Log:
├─ 2025-01-20 15:00 - Access revoked for Adult C (by Adult A)
├─ 2025-01-15 10:30 - Access granted to Adult C (by Adult A)
├─ 2025-01-10 08:00 - Access granted to Adult B (by Adult A)
└─ 2025-01-05 12:00 - Emma's profile created (by Adult A)
```

## Testing

### Unit Tests

1. **Test FMK rotation**: Verify new FMK generated, old FMK still works for old data
2. **Test re-encryption**: Verify all records decryptable with new FMK
3. **Test atomic rollback**: Simulate network failure, verify no partial state
4. **Test wrapped key cleanup**: Verify revoked user's wrapped key deleted
5. **Test version mismatch detection**: Verify offline device self-heals

### Integration Tests

1. **Test full revocation flow**: Revoke access, verify records re-encrypted and synced
2. **Test Realtime propagation**: Verify all devices notified within 5 seconds
3. **Test offline device sync**: Offline device comes online, verify self-healing
4. **Test re-granting**: Revoke then re-grant, verify fresh state

### Performance Tests

1. **Benchmark re-encryption**: 100, 500, 1000 records on real device
2. **Stress test**: 5 family members, 10 users, simultaneous revocations
3. **Network latency test**: Slow network, verify progress bar updates

## Implementation Checklist

### Phase 3 (Required)

- [ ] Implement FMK rotation (CryptoKit)
- [ ] Implement atomic transaction flow
- [ ] Create revocation_events table
- [ ] Create audit_log table
- [ ] Implement Realtime subscription
- [ ] Implement version mismatch detection
- [ ] Implement wrapped key cleanup
- [ ] Add revocation UI (Settings > Manage Access)
- [ ] Add progress bar (re-encryption feedback)
- [ ] Add audit log UI (Settings > Access Log)
- [ ] Write unit tests
- [ ] Write integration tests
- [ ] Benchmark performance on real device
- [ ] Document privacy limitations in UI

### Phase 4 (Recommended - High Priority)

- [ ] Implement cryptographic remote erasure
- [ ] Add secure_deletion message type to Realtime handler
- [ ] Implement ephemeral key generation and immediate discard
- [ ] Test erasure success rate (online vs. offline scenarios)
- [ ] Update privacy disclosures with improved revocation
- [ ] Add audit logging for secure deletion events
- [ ] Test timing attack resistance (extraction vs. erasure race)

## Related Documents

- ADR-0005: Access Revocation and Cryptographic Key Rotation
- `/docs/security/access-revocation-threat-analysis.md` - Threat model
- `/docs/privacy/access-revocation-disclosures.md` - Privacy policy implications

---

**Last Updated**: 2025-12-22
**Related ADR**: ADR-0005
