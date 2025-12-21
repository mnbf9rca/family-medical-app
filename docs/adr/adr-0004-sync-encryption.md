# Sync Encryption and Multi-Device Support

## Status

**Status**: Accepted

## Context

The Family Medical App must support multi-device synchronization (iPhone, iPad, Mac) while maintaining End-to-End Encryption (E2EE). The core challenge: **How can a user access encrypted medical records on a new device when the Master Key is device-only and never transmitted to the server?**

### Problem Statement

```
User's iPhone                    Server (zero-knowledge)         User's iPad
────────────────                 ───────────────────             ───────────
Master Key ✅                   No Master Key ❌               Master Key ???
Encrypted Records ✅            Encrypted Records ✅            How to decrypt?
```

### Requirements

1. **Zero-Knowledge Server**: Server cannot decrypt medical records or keys
2. **Multi-Device Access**: Same user can access data from multiple devices
3. **Offline-First**: Changes made offline must sync when device comes online
4. **Simple Conflict Resolution**: Avoid over-engineering (KISS principle)
5. **Efficient Attachment Sync**: Medical records include photos (vaccine cards) and PDFs (prescriptions)
6. **CryptoKit Only**: Use exclusively CryptoKit primitives (per AGENTS.md)

## Decision

We will implement a **recovery code-based multi-device system** with **last-write-wins conflict resolution**, **separate attachment storage**, and support for **pure storage backends** (S3/MinIO).

### Key Decisions

#### 1. Master Key Distribution: 24-Word Recovery Code

**Decision**: Use BIP39-style 24-word mnemonic to encrypt Master Key for server storage.

**How it works:**

- Account creation: Generate recovery code → encrypt Master Key with it → upload encrypted blob to server
- New device: User enters recovery code → download encrypted blob → decrypt Master Key → store in Keychain
- User responsibility: Write down recovery code (like hardware wallet seed phrase)

**Rationale:**

- ✅ Zero-knowledge maintained (server has encrypted Master Key, not recovery code)
- ✅ Works even if all devices lost/destroyed
- ✅ Industry standard (1Password, Bitwarden, crypto wallets)
- ⚠️ User must safeguard recovery code (if lost, data unrecoverable)

**Rejected alternatives:**

- iCloud Keychain sync (not zero-knowledge, Apple can access)
- Device-to-device transfer only (doesn't work if old device unavailable)

#### 2. Sync Protocol: Pull-Based with Realtime Notifications

**Decision**: Pull-based sync (client polls server) with optional Realtime WebSocket notifications for instant updates.

**Rationale:**

- ✅ Simple (no complex bidirectional sync protocol)
- ✅ Offline-friendly (queue changes locally, sync when online)
- ✅ Realtime feels instant (like iCloud) but gracefully degrades to polling
- ✅ Supports pure storage backends (polling works with S3, Realtime doesn't)

#### 3. Conflict Resolution: Last-Write-Wins

**Decision**: Use timestamp-based last-write-wins (not CRDTs, not manual merge).

**Rationale:**

- ✅ Medical records are mostly append-only (adding vaccine records, not collaborative editing)
- ✅ Conflicts are rare (different family members' records don't conflict)
- ✅ KISS: Avoids complexity of CRDTs or manual merge UI
- ⚠️ Rare data loss if simultaneous edits (acceptable for use case)

#### 4. Attachment Sync: Separate Storage with HMAC Deduplication

**Decision**: Store attachments separately from medical record metadata, using **HMAC-SHA256** for content-addressed deduplication.

**Why separate storage:**

- Editing a note field uploads ~500 bytes (not 2 MB photo) → 99.975% bandwidth savings
- Same photo attached to multiple records → stored once → storage efficiency

**Why HMAC (not plain SHA256):**

- Plain hash vulnerable to rainbow tables (attacker pre-computes hashes of common vaccine cards)
- HMAC keyed with FMK prevents rainbow tables (attacker doesn't know FMK)
- Deduplication still works (same photo + FMK → same HMAC)

**Schema:** Three tables (medical_records, attachments, record_attachments) instead of monolithic blobs.

#### 5. Metadata Encryption: Server Sees Structure, Not Content

**Decision**: Sync metadata (timestamps, IDs, versions) is plaintext; content and attachment filenames/types are encrypted.

**What server sees:**

- ✅ Record IDs, timestamps, update versions (required for sync coordination)
- ✅ Encrypted sizes (for storage allocation)
- ✅ Attachment content HMACs (for deduplication, opaque without FMK)

**What server cannot see:**

- ❌ Medical record content (encrypted with FMK)
- ❌ Attachment file types (encrypted in metadata blob)
- ❌ Attachment filenames (encrypted in metadata blob)
- ❌ Family member names (encrypted in profiles)

**Rationale:**

- Server needs timestamps for last-write-wins and IDs for routing
- Encrypting MIME types prevents server from profiling health data patterns ("50 PDFs → lab results?")
- Accepted trade-off: Structural metadata (social graph) vs. content zero-knowledge

#### 6. Alternative Backend: Pure Storage (S3/MinIO)

**Decision**: Design supports both "smart" backends (Supabase/Postgres with Realtime) and "dumb" backends (S3/MinIO with polling).

**Pure storage model:**

- Server is just key-value blob storage (S3, Cloudflare R2, self-hosted MinIO)
- No database, no queries, no server logic
- Keys are deterministic: `/users/{id}/attachments/{fm-id}/{hmac}.blob`
- Deduplication via HEAD requests (not queries)
- Sync via polling manifest file every 30-60 seconds (not Realtime)

**Benefits:**

- ✅ Extremely low maintenance (just run MinIO in Docker)
- ✅ Self-hosted friendly (no database setup)
- ✅ Cheap (S3/R2 pricing is pennies per GB)
- ✅ No server bugs (no code to maintain)

**Trade-offs:**

- ⚠️ Polling instead of instant (30-60 sec delay, acceptable for medical records)
- ⚠️ More complex client logic (client does sync coordination)

## Consequences

### Positive

1. **Multi-Device Support**: Seamless access from iPhone, iPad, Mac
2. **Zero-Knowledge Maintained**: Server never sees Master Key or plaintext data
3. **Offline-First**: Changes queue locally, sync when online
4. **Simple Conflict Resolution**: Last-write-wins avoids complex merge logic
5. **Efficient Attachment Sync**: 99.975% bandwidth savings when editing notes
6. **Content Deduplication**: Same photo stored once, even if attached to multiple records
7. **Rainbow Table Protection**: HMAC prevents known-plaintext attacks on attachments
8. **MIME Type Privacy**: Server cannot infer health data patterns from file types
9. **Flexible Deployment**: Works with Supabase (rich features) or MinIO (self-hosted simplicity)
10. **Low Maintenance Option**: Pure S3 backend requires no server code

### Negative

1. **Recovery Code Responsibility**: If user loses recovery code, data is permanently unrecoverable
   - **Severity**: High (permanent data loss)
   - **Mitigation**: Clear instructions during setup, multiple backup options (paper, password manager)
   - **Trade-off**: Zero-knowledge requires user-controlled secrets

2. **Last-Write-Wins Data Loss**: Simultaneous edits on different devices → one edit discarded
   - **Severity**: Low (rare for medical records)
   - **Mitigation**: Timestamp display ("Last edited on iPad 5 min ago")
   - **Trade-off**: Simplicity over complex conflict resolution

3. **Encrypted Master Key on Server**: Server breach + recovery code leak = full data access
   - **Risk**: Requires both server compromise AND recovery code compromise
   - **Mitigation**: 256-bit recovery code (strong), PBKDF2 100k iterations
   - **Trade-off**: Necessary for multi-device without iCloud Keychain

4. **Device Revocation Not Cryptographic**: Revoked device can still decrypt local data
   - **Severity**: Medium (stolen device retains access to old data, but can't sync new data)
   - **Mitigation**: User can change recovery code → force all devices to re-authenticate
   - **Future**: Per-device encryption keys (Phase 4)

5. **Sync Metadata Plaintext**: Server sees record IDs, timestamps, social graph
   - **Impact**: Metadata leakage (who shares with whom), not content
   - **Trade-off**: Required for efficient sync coordination
   - **Note**: Same limitation as Signal, WhatsApp (content E2EE, routing metadata exposed)

6. **S3 Backend Lacks Instant Sync**: Polling-based (30-60 sec delay)
   - **Severity**: Low (medical records aren't time-sensitive like messaging)
   - **Trade-off**: Server simplicity over instant UX

### Neutral

1. **BIP39 Dependency**: Requires BIP39 library for mnemonic generation
   - Standard library, well-vetted (Bitcoin ecosystem since 2013)

2. **Pull-Based Sync**: Not true peer-to-peer (requires server)
   - Consistent with zero-knowledge server model (server as mailbox)

3. **More Complex Schema**: Attachments require 3 tables (vs. monolithic blobs)
   - Standard relational design, justified by 99.975% bandwidth savings

## Related Decisions

- **ADR-0001**: Crypto Architecture First (establishes zero-knowledge requirement)
- **ADR-0002**: Key Hierarchy (defines Master Key, FMKs used for encryption)
- **ADR-0003**: Multi-User Sharing Model (server as mailbox for async operations)
- **ADR-0005**: Access Revocation (syncs revocation events across devices)

## References

- Issue #39: Design sync encryption and blob format
- `docs/technical/sync-implementation-details.md` (full schemas, code examples)
- `docs/technical/sync-attachment-deduplication-security.md` (HMAC security analysis)
- `docs/technical/s3-backend-design.md` (pure storage backend design)
- AGENTS.md: Cryptography specifications
- [BIP39](https://github.com/bitcoin/bips/blob/master/bip-0039.mediawiki): Mnemonic code specification
- [1Password Security Design](https://support.1password.com/secret-key-security/): Recovery code approach

---

**Decision Date**: 2025-12-21
**Author**: Claude Code
**Reviewers**: [To be assigned]
