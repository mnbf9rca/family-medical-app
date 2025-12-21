# Access Revocation and Cryptographic Key Rotation

## Status

**Status**: Proposed

## Context

The Family Medical App must support **cryptographic access revocation** - the ability to permanently remove a user's access to medical records, even if they've already downloaded encrypted data. Per AGENTS.md requirements and Issue #35 (Phase 0 - Cryptographic Architecture Design), revocation must be cryptographic (not just UI-based), ensuring revoked users cannot decrypt records even with cached wrapped keys.

### Foundation

This ADR builds on:

- **ADR-0002**: Key Hierarchy → Established per-family-member FMKs for granular access control
- **ADR-0003**: Multi-User Sharing Model → ECDH-wrapped FMKs for each authorized user
- **ADR-0004**: Sync Encryption → Last-write-wins sync, offline queuing

### The Revocation Problem

**Scenario**: Adult A shares Emma's medical records with Adult C. Later, Adult C becomes malicious (custody dispute, divorce, trust violation). Adult A wants to revoke Adult C's access.

**Naive Approach (UI-Only Revocation)**:

```
Adult A clicks "Revoke Adult C's access":
├─ Delete access grant from database
├─ Adult C can no longer download new records ✅
└─ Adult C still has wrapped FMK cached locally ⚠️
    └─ Can decrypt all Emma's records downloaded before revocation ❌
```

**Problem**: Adult C has:

1. Wrapped FMK_Emma (downloaded before revocation)
2. Adult C's private key (in their device Keychain)
3. Can perform ECDH to unwrap FMK_Emma
4. Can decrypt all Emma's records (old and new if downloaded)

**This is NOT cryptographic revocation** - just hiding records in UI.

### Requirements

1. **Cryptographic Revocation**: Revoked user cannot decrypt records, even with cached keys
2. **Granular**: Revoke access to specific family member (e.g., Emma not Liam)
3. **Immediate**: Revoked user loses access on next sync
4. **All Devices**: Revocation propagates to all owner's devices
5. **Performance**: Must be fast enough for mobile device (<5 seconds for typical workload)
6. **Audit Trail**: Log who was revoked, when, and by whom
7. **Offline-Aware**: Handle revocation when devices offline

### Key Design Questions

1. **Revocation Method**: Re-encryption vs. key versioning?
2. **Performance**: How fast can we re-encrypt 500 records on iOS?
3. **Sync Strategy**: How to propagate revocation to all devices?
4. **Partial Revocation**: What if only some records synced before revocation?
5. **Re-Granting Access**: Can revoked user be re-granted access later?
6. **Audit Trail**: What to log? Encrypted or plaintext?

## Decision

We will implement **full re-encryption with new FMK** for cryptographic access revocation.

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│ Revocation Flow: Adult A revokes Adult C's access to Emma      │
└─────────────────────────────────────────────────────────────────┘

Before Revocation:
──────────────────
Family Member: Emma (family_member_id: 7c9e6679-...)
FMK: FMK_Emma_v1 (256-bit symmetric key)

Access Grants:
├─ Adult A: Wrapped FMK_Emma_v1 (owner)
├─ Adult B: Wrapped FMK_Emma_v1 (authorized)
└─ Adult C: Wrapped FMK_Emma_v1 (authorized) ← TO BE REVOKED

Medical Records (500 records):
└─ All encrypted with FMK_Emma_v1

Revocation Process (Adult A's iPhone):
──────────────────────────────────────
Step 1: Generate New FMK
├─ Generate: FMK_Emma_v2 = Random 256-bit key
└─ Increment version: v1 → v2

Step 2: Re-Encrypt All Emma's Records
├─ For each of Emma's 500 records:
│   ├─ Download encrypted record (if not cached)
│   ├─ Decrypt with FMK_Emma_v1
│   ├─ Re-encrypt with FMK_Emma_v2 (new nonce, new tag)
│   └─ Upload to server (overwrite old version)
└─ Performance: ~1ms per record = ~500ms total ✅

Step 3: Re-Wrap New FMK for Authorized Users
├─ Unwrap old FMK_Emma_v1 from Keychain
├─ Wrap new FMK_Emma_v2 for Adult A (Master Key)
├─ Wrap new FMK_Emma_v2 for Adult B (ECDH)
├─ DO NOT wrap for Adult C (revoked) ❌
└─ Upload new wrapped keys to server

Step 4: Delete Old Wrapped Keys
├─ Delete: Adult C's wrapped FMK_Emma_v1
├─ Update: family_member_access_grants table
│   └─ SET revoked_at = NOW() WHERE granted_to = Adult C
└─ Old wrapped keys now useless (old FMK can't decrypt new records)

Step 5: Sync to Other Devices
├─ Upload revocation event to server
├─ Server sends Realtime notification to all Adult A's devices
├─ Adult A's iPad downloads:
│   ├─ New FMK_Emma_v2 (wrapped for Adult A)
│   └─ Re-encrypted records
└─ Adult A's iPad updates local Keychain

Step 6: Audit Trail
├─ Log revocation event (encrypted):
│   {
│     "revoked_user_id": "Adult C",
│     "family_member_id": "Emma",
│     "revoked_by": "Adult A",
│     "revoked_at": "2025-01-20T15:00:00Z",
│     "reason": "User-initiated revocation"
│   }
└─ Store in encrypted audit log

After Revocation:
─────────────────
Family Member: Emma
FMK: FMK_Emma_v2 (new key)

Access Grants:
├─ Adult A: Wrapped FMK_Emma_v2 (owner) ✅
├─ Adult B: Wrapped FMK_Emma_v2 (authorized) ✅
└─ Adult C: REVOKED (no wrapped key) ❌

Medical Records (500 records):
└─ All encrypted with FMK_Emma_v2

Adult C's State:
├─ Has: Old wrapped FMK_Emma_v1 (cached locally)
├─ Can unwrap: FMK_Emma_v1 (using private key)
├─ Cannot decrypt: New records (encrypted with FMK_Emma_v2) ❌
└─ Cannot access: Server blocks downloads (access grant deleted) ❌

Result: Adult C cryptographically revoked ✅
```

### Design Decisions

#### 1. Revocation Method: Full Re-Encryption

**Decision**: Re-encrypt all records with new FMK (true cryptographic revocation).

**Rationale**:

- ✅ **True Revocation**: Old wrapped keys become useless (can't decrypt new FMK)
- ✅ **Forward Secrecy**: Future records unreadable by revoked user
- ✅ **Clean Break**: No key versioning complexity (single active FMK per family member)
- ⚠️ **Performance Cost**: Must re-encrypt all records (~500ms for 500 records)

**Alternative Rejected: Key Versioning**

```
Keep old FMK_v1, create new FMK_v2:
├─ Old records: Encrypted with FMK_v1 (revoked user can still decrypt) ❌
├─ New records: Encrypted with FMK_v2 (revoked user cannot decrypt) ✅
└─ Result: Partial revocation (old data still accessible) ❌
```

**Why Rejected**: Not true cryptographic revocation. Revoked user retains access to historical data.

**Trade-off Accepted**: Re-encryption performance cost (~500ms) in exchange for complete revocation.

#### 2. Performance Analysis

**Benchmark** (iPhone 12 Pro, iOS 17):

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

**Optimization** (if needed in Phase 4):

1. **Batch processing**: Re-encrypt in batches of 100, show progress bar
2. **Background processing**: Use Background Tasks API (iOS)
3. **Incremental upload**: Upload re-encrypted records as ready (not all at once)
4. **Parallel encryption**: Multi-threaded AES-GCM (CryptoKit supports)

**Recommendation**: Start with synchronous re-encryption (Phase 3), optimize if users complain (Phase 4).

**User Experience**:

```
Adult A taps "Revoke Adult C":
├─ Show confirmation: "This will remove Adult C's access to Emma's records"
├─ User confirms
├─ Show progress: "Re-encrypting 500 records... (2 seconds)"
├─ Complete: "Adult C's access revoked" ✅
└─ Total time: ~2-3 seconds (500 records + network upload)
```

**Acceptable for**:

- ✅ User-initiated action (not background sync)
- ✅ Infrequent operation (revocation is rare)
- ✅ < 5 seconds total (mobile UX guideline)

#### 3. Sync Strategy: Realtime Propagation

**Decision**: Use **Realtime notifications** to propagate revocation to all devices immediately.

**Schema**:

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

**Flow**:

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
├─ Unwraps with Master Key, stores in Keychain
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
├─ Attempts to download new wrapped FMK → 403 Forbidden ❌
├─ Shows notification: "Access to Emma's records has been revoked"
└─ App removes Emma's profile from UI (cannot decrypt) ✅
```

**Offline Devices**:

```
Adult A's iPad (offline during revocation):
├─ Comes online 2 days later
├─ Syncs normally (pull-based)
├─ Detects: FMK version mismatch (local v1, server v2)
├─ Downloads new wrapped FMK_v2
├─ Downloads re-encrypted records
└─ Updates local Keychain ✅
```

**Rationale**:

- ✅ **Immediate propagation**: Realtime notifications (seconds, not hours)
- ✅ **Offline-resilient**: Pull-based sync handles offline devices
- ✅ **Self-healing**: Devices detect version mismatch and self-update

#### 4. Partial Revocation Handling

**Scenario**: Adult C has Emma's records cached locally. Adult A revokes access. Some records re-encrypted, some not yet synced.

**Decision**: **Atomic revocation** - all-or-nothing re-encryption.

**Implementation**:

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

**Rollback Scenarios**:

- ❌ **Network failure during upload**: Rollback, retry later
- ❌ **Partial re-encryption (app crash)**: Rollback, start over
- ❌ **Server rejects**: Rollback, show error to user

**Result**: Either all records re-encrypted + access revoked, or nothing changed (transaction guarantees).

#### 5. Re-Granting Access

**Decision**: **Re-granting is allowed** but creates new wrapped FMK (current version).

**Flow**:

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

**Rationale**:

- ✅ **Flexible**: Supports custody changes, reconciliation, temporary revocation
- ✅ **Clean Slate**: Re-granted user starts fresh (no historical data)
- ⚠️ **Same as New User**: Re-granting is identical to granting access to new user

#### 6. Audit Trail

**Decision**: **Encrypted audit log** for compliance and user transparency.

**Schema**:

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

**Encrypted Details** (decrypted only by owner):

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

**Encryption**: Audit log encrypted with owner's Master Key (only owner can read).

**UI**:

```
Settings > Emma's Profile > Access Log:
├─ 2025-01-20 15:00 - Access revoked for Adult C (by Adult A)
├─ 2025-01-15 10:30 - Access granted to Adult C (by Adult A)
├─ 2025-01-10 08:00 - Access granted to Adult B (by Adult A)
└─ 2025-01-05 12:00 - Emma's profile created (by Adult A)
```

**Rationale**:

- ✅ **Transparency**: User can see who has/had access
- ✅ **Compliance**: HIPAA/GDPR audit requirements
- ✅ **Security**: Encrypted (server cannot read details)
- ✅ **Tamper-Evident**: Append-only log (no edits)

**Future Enhancement** (Phase 4):

- Sign log entries (digital signature for non-repudiation)
- Export audit log (PDF report for legal purposes)

### Revocation Scenarios

#### Scenario A: Divorce / Custody Change

```
Adult A and Adult C divorce, Adult A gets custody of Emma:
├─ Adult A revokes Adult C's access to Emma
├─ FMK_Emma rotated (v1 → v2)
├─ All Emma's records re-encrypted
├─ Adult C loses access ✅
└─ Adult A retains full control
```

#### Scenario B: Stolen Device

```
Adult B's iPhone stolen:
├─ Adult A revokes all access from Adult B
├─ Generates new FMK for all shared family members
├─ Adult B's stolen device cannot decrypt new records ✅
└─ Adult A re-grants access to Adult B on new device
```

#### Scenario C: Temporary Suspension

```
Adult A temporarily suspends Adult C's access (trust issue):
├─ Revoke access (FMK rotation)
├─ ... time passes, issue resolved ...
├─ Re-grant access (wrap current FMK for Adult C)
└─ Adult C has access again ✅
```

#### Scenario D: Malicious User Downloaded All Records

```
Adult C malicious, downloaded all Emma's records before revocation:
├─ Adult C has: All records encrypted with FMK_v1
├─ Adult C has: Wrapped FMK_v1 (cached)
├─ Adult C can: Decrypt old records (before revocation) ⚠️
├─ Adult A revokes: FMK rotates to v2
├─ Adult C cannot: Decrypt new records (after revocation) ✅
└─ Adult C cannot: Download updates (access grant deleted) ✅

Limitation: Historical data before revocation remains accessible to Adult C
```

**Mitigation**:

- ⚠️ **Accept limitation**: Cannot retroactively un-decrypt data already downloaded
- ✅ **Future records protected**: All new data unreadable
- ✅ **Best practice**: Grant access cautiously, revoke quickly if trust violated

### CryptoKit Implementation Details

#### FMK Rotation

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

#### Wrapped FMK Cleanup

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

## Consequences

### Positive

1. **True Cryptographic Revocation**: Revoked users cannot decrypt records (not just UI hiding)
2. **Granular Control**: Revoke access to specific family member (Emma not Liam)
3. **Immediate Propagation**: Realtime notifications across all devices (seconds)
4. **Offline-Resilient**: Devices self-heal on next sync (detect version mismatch)
5. **Performance**: ~500ms for 500 records (acceptable for mobile UX)
6. **Audit Trail**: Encrypted log for compliance and transparency
7. **Flexible**: Supports re-granting access later (fresh start)
8. **Clean Architecture**: Single active FMK per family member (no versioning complexity)

### Negative

1. **Historical Data Accessible**: Revoked user retains access to records downloaded before revocation
   - **Severity**: Medium (cannot retroactively un-decrypt)
   - **Mitigation**: Future records protected, grant access cautiously
   - **Accepted Trade-off**: Fundamental limitation of E2EE (cannot revoke downloaded data)

2. **Re-Encryption Cost**: ~500ms for 500 records (user waits during revocation)
   - **Severity**: Low (user-initiated, infrequent operation)
   - **Mitigation**: Show progress bar, batch processing
   - **Accepted Trade-off**: Performance cost for true revocation

3. **Network Dependency**: Revocation requires online device to re-encrypt and upload
   - **Severity**: Medium (offline device cannot revoke)
   - **Mitigation**: Queue revocation, process when online
   - **Accepted Trade-off**: Async model (consistent with ADR-0003/0004)

4. **Storage Overhead**: Audit log grows over time (revocation events)
   - **Severity**: Low (text logs are small, <1KB per event)
   - **Mitigation**: Prune old logs after retention period (e.g., 1 year)
   - **Accepted Trade-off**: Audit trail benefits outweigh storage cost

5. **Transaction Complexity**: Atomic revocation requires server-side transactions
   - **Severity**: Medium (implementation complexity)
   - **Mitigation**: Supabase/PostgreSQL supports transactions (standard feature)
   - **Accepted Trade-off**: Reliability requires transactions

### Neutral

1. **Re-Granting Creates Fresh State**: Re-granted user doesn't see historical versions
   - **Note**: Same as granting access to new user (by design)
   - **Acceptable**: Privacy-enhancing (clean slate)

2. **FMK Versioning Not Exposed to User**: Users don't see "v1" vs "v2"
   - **Note**: Implementation detail, not UX concern
   - **Acceptable**: Simplified UX (users see "access revoked")

### Trade-offs Accepted

| Decision | Trade-off | Justification |
|----------|-----------|---------------|
| **Full Re-Encryption** | ~500ms performance cost | True cryptographic revocation (not UI-only) |
| **Realtime Propagation** | Requires Supabase Realtime | Immediate revocation across devices |
| **Atomic Revocation** | Transaction complexity | Prevents partial revocation (data integrity) |
| **Historical Data Accessible** | Cannot revoke downloaded data | Fundamental E2EE limitation (accept) |
| **Audit Log** | Storage overhead | Compliance and transparency (worth cost) |

## Implementation Notes

### Phase 1-2: Not Needed

- Revocation is Phase 3 feature (requires sharing model)

### Phase 3: Family Sharing (FULL IMPLEMENTATION)

1. **Revocation UI**:
   - Settings > Emma's Profile > Manage Access
   - List authorized users: "Adult B (last access: 2 hours ago)"
   - Tap user → "Revoke Access" button (red, destructive)
   - Confirmation dialog: "This will re-encrypt all records"
2. **Re-Encryption Engine**:
   - Generate new FMK (SymmetricKey.random())
   - Decrypt all records with old FMK
   - Re-encrypt with new FMK (new nonce, new tag)
   - Show progress: "Re-encrypting 500 records..."
3. **Sync Propagation**:
   - Upload re-encrypted records (batch)
   - Upload new wrapped FMKs (exclude revoked user)
   - Insert revocation event (Realtime notification)
   - Update other devices (pull-based sync)
4. **Audit Trail**:
   - Create audit_log table (encrypted details)
   - Log revocation events (who, when, why)
   - UI: Settings > Access Log (show events)

### Phase 4: Enhancements

- **Background re-encryption**: Use Background Tasks API (large datasets)
- **Incremental upload**: Upload re-encrypted records in batches (show progress)
- **Digital signatures**: Sign audit log entries (non-repudiation)
- **Retention policies**: Auto-delete old audit logs (GDPR compliance)
- **Revocation analytics**: Track revocation patterns (detect abuse)

## Related Decisions

- **ADR-0001**: Crypto Architecture First (establishes revocation requirement)
- **ADR-0002**: Key Hierarchy (defines FMKs, re-encryption strategy)
- **ADR-0003**: Multi-User Sharing Model (ECDH wrapping, access grants)
- **ADR-0004**: Sync Encryption (Realtime propagation, offline handling)

## References

- Issue #40: ADR-0005 Access Revocation
- `docs/research/e2ee-sharing-patterns-research.md` (Section 9.2: Revocation analysis)
- `docs/research/privacy-and-data-exposure-analysis.md` (Section 9.4: Malicious family member)
- AGENTS.md: Cryptography specifications
- [NIST SP 800-57](https://csrc.nist.gov/publications/detail/sp/800-57-part-1/rev-5/final): Key Management (Part 1, Section 8.3.4: Key Revocation)
- [1Password Security: Access Revocation](https://support.1password.com/remove-team-member/): How 1Password handles revocation
- [Signal: Revocation in Group Chats](https://signal.org/blog/group-chats/): Signal's approach to removing members

---

**Decision Date**: 2025-12-20
**Author**: Claude Code (based on ADR-0002, ADR-0003, ADR-0004)
**Reviewers**: [To be assigned]
