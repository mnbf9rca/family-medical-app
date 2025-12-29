# Access Revocation: Threat Analysis

This document provides a comprehensive threat model for the access revocation mechanism designed in ADR-0005.

## Overview

**Threat Model Scope**: Protect future data against revoked users (not historical data).

The revocation mechanism uses **full FMK re-encryption** to cryptographically prevent revoked users from decrypting records created after revocation.

## Threats Prevented ✅

| Threat | Attack Scenario | Mitigation |
|--------|----------------|------------|
| **Revoked User Decrypts New Records** | Adult C is revoked but attempts to decrypt records created after revocation | FMK rotation ensures new records encrypted with FMK_v2 (Adult C only has FMK_v1) ❌ Cannot decrypt |
| **Revoked User Downloads New Records** | Adult C attempts to sync/download records after revocation | Server-side access control: `403 Forbidden` when Adult C queries for Emma's records (access grant deleted) |
| **Revoked User Re-Uses Cached Keys** | Adult C has wrapped FMK_v1 cached locally, attempts to unwrap and decrypt | Unwrapping succeeds (Adult C has private key), but decryption fails (old FMK doesn't match new records encrypted with FMK_v2) |
| **Revoked User Accesses Cached Records** | Adult C attempts to decrypt cached records downloaded before revocation | **Cryptographic Remote Erasure**: Device receives secure deletion message, re-encrypts cached data with ephemeral key, discards key → data permanently undecryptable (works in most cases if device online) |
| **Server MITM Prevents Revocation** | Malicious server intercepts revocation event, doesn't propagate | Devices detect version mismatch on next sync (local FMK_v1, server records use FMK_v2), self-heal by downloading new FMK |
| **Partial Revocation** | Network failure during re-encryption leaves some records with old FMK | Atomic transactions: All-or-nothing re-encryption (rollback on failure) |
| **Authorized User Loses Access** | Re-encryption accidentally revokes Adult B (authorized user) | New wrapped FMK_v2 generated for all authorized users (Adult A, Adult B), only Adult C excluded |
| **Offline Device Misses Revocation** | Adult A's iPad offline during revocation, syncs later with old FMK | Self-healing: Detects version mismatch, downloads new wrapped FMK_v2, updates Keychain |

## Threats NOT Prevented ⚠️

| Threat | Attack Scenario | Limitation | Accepted Trade-off |
|--------|----------------|------------|-------------------|
| **Historical Data Access** | Adult C retains access to records downloaded before revocation | Adult C can decrypt old records with cached FMK_v1 | **Fundamental E2EE limitation**: Cannot retroactively un-decrypt downloaded data. Mitigation: Future records protected, grant access cautiously |
| **Key Extraction Before Revocation** | Adult C extracts FMK_v1 from Keychain before revocation, stores externally | Adult C can decrypt historical records indefinitely | **Device security limitation**: iOS Keychain is secure, but determined attacker with device access can extract. Mitigation: Rely on iOS security, document limitation |
| **Malicious Server Withholds Revocation** | Server doesn't send Realtime notification to Adult C's device | Adult C's app doesn't know access was revoked (still shows UI) | **UX issue, not cryptographic**: Adult C can't download new data (403), but UI may be stale. Mitigation: Pull-based sync eventually updates UI |
| **Revoked Device Still Has Local Copy** | Adult C's device has full local Core Data database with all records | Adult C can continue viewing old records if offline during revocation | **Mitigated by cryptographic remote erasure**: If device online, cached data is re-encrypted with ephemeral key and made permanently undecryptable (works in most typical scenarios) |
| **Ownership Transfer Snapshot** | Previous owner retains access to records from before transfer | Previous owner has permanent snapshot (pre-transfer records) | **Legitimate owner limitation**: Previous owner had legal access during ownership period. Mitigation: Disclose to both parties, matches real-world expectation |

## Cryptographic Remote Erasure (Phase 4)

**Mechanism**: On revocation, send Realtime secure deletion message that re-encrypts cached data with ephemeral random key, then discards the key.

**Success Rate by Scenario**:

| Scenario | Success Rate | Reasoning |
|----------|-------------|-----------|
| **Normal family member** (divorce, custody) | High | Won't anticipate revocation, device likely online |
| **Tech-savvy user** | Moderate | May understand E2EE, but timing matters |
| **Sophisticated attacker** (premeditated) | Low | Can extract keys prophylactically |
| **Offline device** | Deferred | Message queued, delivered when online |
| **Device backed up before revocation** | None | Restore from backup bypasses erasure |

**Timing Attack**: There's a race between defender sending erasure message (~1 second via Realtime) and attacker extracting FMK from Keychain (~30-60 seconds). Most casual users won't extract keys, so success rate is high for typical scenarios.

**Memory Security Verification** (Issue #46 Research):

The ephemeral key mechanism depends on secure memory deallocation. Verified:

- ✅ CryptoKit's SymmetricKey zeroes memory on deallocation ([source](https://medium.com/swlh/common-cryptographic-operations-in-swift-with-cryptokit-b30a4becc895))
- ✅ libsodium (Swift-Sodium) provides explicit key zeroization via `sodium_memzero()`
- ✅ [Ente's CRYPTO_SPEC](https://github.com/ente-io/ente/blob/main/mobile/native/ios/Packages/EnteCrypto/CRYPTO_SPEC.md) confirms: "Key Zeroization: libsodium handles secure key deletion"

**Threat Window**: Between ephemeral key going out of scope and memory being zeroed is negligible (microseconds on modern iOS devices with ARC).

**Result**: Significant improvement over no erasure for typical cases, but cannot guarantee deletion.

## Attacker Model

### Revoked User Capabilities (Assumed)

The threat model assumes a revoked user has:

- ✅ Cached encrypted records (downloaded before revocation)
- ✅ Wrapped FMK_v1 (stored in Core Data before revocation)
- ✅ Device with iOS Keychain access
- ✅ Technical expertise (can write custom decryption tools)
- ✅ Ability to modify local database

The revoked user can:

- ✅ Unwrap FMK_v1 (using their private key + ECDH)
- ✅ Decrypt old records (encrypted with FMK_v1)
- ✅ Attempt to sync with server (will get 403)
- ✅ Modify local database (but can't upload changes)

The revoked user cannot:

- ❌ Decrypt new records (encrypted with FMK_v2, which they don't have)
- ❌ Download new data (server access control blocks)
- ❌ Derive new FMK (randomly generated, not derivable)

### Out of Scope Threats

The following threats are **not** addressed by this design (out of scope for Phase 0):

- ❌ **Compromised server**: If server is actively malicious (not just breached), it can serve fake data, but cannot decrypt records (zero-knowledge architecture prevents this)
- ❌ **Compromised authorized device**: If Adult A's device is compromised, attacker has FMK_v2 (but this is an active compromise, not a revocation scenario)
- ❌ **Physical device theft with forensics**: iOS Keychain extraction requires sophisticated attack (nation-state level)
- ❌ **Metadata analysis**: Server can see social graph (who shares with whom), but not content

## Security Properties

### Forward Secrecy (Per Family Member)

**Property**: Revoked user cannot decrypt records created after revocation.

**Mechanism**: FMK rotation (FMK_v1 → FMK_v2)

**Guarantee**: ✅ **Strong** - Cryptographically enforced (revoked user has old key, new records use new key)

### Backward Secrecy (Limited)

**Property**: Revoked user CAN decrypt records downloaded before revocation.

**Mechanism**: None (fundamental E2EE limitation)

**Guarantee**: ⚠️ **None** - Historical data remains accessible

**Rationale**: Cannot retroactively un-decrypt data already downloaded. Same limitation as all E2EE systems (Signal, 1Password, etc.)

### Access Enforcement

**Property**: Server cryptographically enforces access (not just UI hiding).

**Mechanism**: Server-side access grants + FMK rotation

**Guarantee**: ✅ **Strong** - Revoked user gets 403 on download attempts + cannot decrypt even if they obtain encrypted blobs

### Auditability

**Property**: All revocation events are logged.

**Mechanism**: Encrypted audit log (encrypted with owner's Primary Key)

**Guarantee**: ✅ **Strong** - Tamper-evident append-only log

### Self-Healing

**Property**: Devices recover from sync failures (e.g., offline during revocation).

**Mechanism**: Version mismatch detection on next sync

**Guarantee**: ✅ **Strong** - Devices automatically download new FMK when version doesn't match

## Comparison to Industry Standards

| System | Forward Secrecy | Backward Secrecy | Revocation Method | Notes |
|--------|----------------|------------------|-------------------|-------|
| **Our App** | ✅ Yes (new FMK) | ⚠️ No (historical data accessible) | Re-encryption with new key | Medical records use case |
| **Signal** | ✅ Yes (ratcheting) | ✅ Yes (ephemeral keys) | Key ratcheting (forward/backward secrecy) | Messaging use case (different threat model) |
| **1Password** | ✅ Yes (vault re-encryption) | ⚠️ No (cached data accessible) | Vault re-encryption | Password manager (similar to our approach) |
| **Shared iCloud Keychain** | ⚠️ Partial | ⚠️ No | Server-side access control (not E2EE) | Apple controls keys (not zero-knowledge) |

## Rationale for Accepted Limitations

1. **Signal-style ratcheting rejected**:
   - Too complex for medical records use case
   - Violates KISS principle (see Issue #40, Options Analysis)
   - Medical records are **static data** (not real-time messaging)

2. **Historical data access acceptable**:
   - Fundamental E2EE limitation (industry-wide)
   - Cannot retroactively un-decrypt downloaded data
   - Matches real-world expectation (previous owner had legitimate access during ownership period)

3. **Encryption protects against**:
   - ✅ Server breaches (zero-knowledge)
   - ✅ Unauthorized third parties
   - ✅ Future access by revoked users

4. **Encryption does NOT protect against**:
   - ⚠️ Historical access by previously legitimate users
   - ⚠️ Active device compromise (malware on authorized device)

## Mitigation Strategies

### For Historical Data Limitation

1. **User Education**: Clearly disclose limitation during sharing flow
2. **Grant Access Cautiously**: Warning before granting access to sensitive records
3. **Revoke Quickly**: Prompt revocation minimizes exposure window
4. **Audit Trail**: Log all access grants/revocations for transparency

### For Key Extraction Risk

1. **Rely on iOS Security**: Keychain is hardware-backed (Secure Enclave)
2. **Document Limitation**: Privacy policy discloses risk
3. **Future Enhancement**: Biometric protection for Primary Key access (Phase 4)

### For Offline Revocation Delay

1. **Queue Revocation**: Offline device queues revocation, processes when online
2. **Self-Healing Sync**: Version mismatch detection ensures eventual consistency
3. **User Notification**: Show status ("Revocation pending - device offline")

## Attack Scenarios

### Scenario 1: Malicious Revoked User

**Setup**: Adult C has Emma's records. Adult A revokes Adult C. Adult C is tech-savvy and motivated.

**Attack**: Adult C extracts FMK_v1 from Keychain, downloads all encrypted records, attempts to decrypt.

**Outcome**:

- ✅ Adult C can decrypt old records (downloaded before revocation)
- ❌ Adult C cannot decrypt new records (encrypted with FMK_v2)
- ❌ Adult C cannot download new encrypted blobs (403 Forbidden)

**Verdict**: ⚠️ **Partial success** - Historical data exposed, future data protected

### Scenario 2: Compromised Server

**Setup**: Server is breached or malicious.

**Attack**: Server attempts to decrypt medical records and FMKs.

**Outcome**:

- ❌ Server cannot decrypt medical records (encrypted with FMK)
- ❌ Server cannot decrypt wrapped FMKs (encrypted with ECDH-derived keys)
- ✅ Server can see metadata (social graph, timestamps, file sizes)

**Verdict**: ✅ **Attack fails** - Zero-knowledge architecture prevents data decryption

### Scenario 3: Stolen Device

**Setup**: Adult B's device is stolen. Adult A revokes Adult B's access.

**Attack**: Thief has Adult B's device with all Emma's records.

**Outcome**:

- ✅ Thief can view old records (if device unlocked, or unlock bypass)
- ❌ Thief cannot sync new records (403 Forbidden)
- ❌ Thief cannot decrypt new records (no FMK_v2)

**Verdict**: ⚠️ **Partial success** - Historical data on device accessible, future data protected

**Mitigation**: Adult A can re-grant access to Adult B on new device

## Recommendations

1. **Phase 3 (Implementation)**:
   - Implement atomic revocation with transactions
   - Add clear user disclosures about historical data limitation
   - Implement audit trail (encrypted log)

2. **Phase 4 (Enhancements)**:
   - Add biometric protection for Primary Key access
   - Implement remote wipe trigger (best-effort, not guaranteed)
   - Add digital signatures to audit log (non-repudiation)

3. **Privacy Policy**:
   - Clearly disclose historical data limitation
   - Explain difference between cryptographic and UI-based revocation
   - Provide examples of what revocation does/doesn't prevent

## Related Documents

- ADR-0005: Access Revocation and Cryptographic Key Rotation
- `/docs/technical/access-revocation-implementation.md` - Implementation guide
- `/docs/privacy/access-revocation-disclosures.md` - Privacy policy implications

---

**Last Updated**: 2025-12-22
**Related ADR**: ADR-0005
