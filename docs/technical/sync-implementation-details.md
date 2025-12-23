# Sync Encryption and Multi-Device Support

## Status

**Status**: Accepted

## Context

The Family Medical App must support **multi-device synchronization** while maintaining End-to-End Encryption (E2EE). Per AGENTS.md requirements and Issue #35 (Phase 0 - Cryptographic Architecture Design), users should be able to access their medical records from multiple devices (e.g., iPhone and iPad) without compromising zero-knowledge properties.

### Foundation

This ADR builds on:

- **ADR-0002**: Key Hierarchy → Established Master Key (device-only) and FMKs (per-family-member)
- **ADR-0003**: Multi-User Sharing Model → Server as persistent mailbox for async operations

### The Multi-Device Challenge

**Core Problem**: How can Adult A access medical records on both iPhone and iPad when the Master Key is device-only (never transmitted to server)?

```
Adult A's iPhone                     Server                   Adult A's iPad
─────────────────                    ──────                   ──────────────
Master Key ✅                     No Master Key ❌         Master Key ???
Private Key ✅                    No Private Key ❌        Private Key ???
FMKs ✅                           Wrapped FMKs ✅          FMKs ???

Medical Records ✅                Encrypted Records ✅      Medical Records ???
```

**The Dilemma**:

- ✅ Server has encrypted records (can sync them)
- ❌ Server doesn't have Master Key (can't decrypt)
- ❌ iPad doesn't have Master Key (can't derive FMKs)
- ❓ How does iPad get Master Key without server seeing it?

### Requirements

1. **Zero-Knowledge Server**: Server cannot decrypt medical records or keys
2. **Multi-Device Access**: Same user can access data from iPhone, iPad, Mac
3. **Offline-First**: Changes made offline must sync when device comes online
4. **Conflict Resolution**: Handle simultaneous edits on different devices
5. **New Device Setup**: User can add new device to account
6. **Device Revocation**: User can remove compromised device from account
7. **CryptoKit Only**: Use exclusively CryptoKit primitives (per AGENTS.md)
8. **KISS Principle**: Avoid over-engineering conflict resolution

### Key Design Questions

1. **Master Key Distribution**: How to get Master Key on new device without server?
2. **Sync Protocol**: Real-time push vs. pull-based polling?
3. **Conflict Resolution**: Last-write-wins, CRDTs, or manual merge?
4. **Metadata for Sync**: What must be plaintext for sync coordination?
5. **Offline Behavior**: How to handle offline edits?
6. **Device Management**: How to list/revoke devices?

## Decision

We will implement a **recovery code-based multi-device system** with **last-write-wins conflict resolution** and **pull-based sync with real-time notifications**.

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│ Multi-Device Sync Flow                                          │
└─────────────────────────────────────────────────────────────────┘

Setup: Adult A's iPhone (Primary Device)
────────────────────────────────────────
1. User creates account with password
2. App derives Master Key (Argon2id via Swift-Sodium)
3. App generates Curve25519 keypair
4. App generates random Recovery Code (256-bit)
5. App encrypts Master Key with Recovery Code
6. App stores:
   - Keychain: Master Key, Private Key (encrypted with Master Key)
   - Server: Encrypted Master Key blob, Public Key
   - User shown: Recovery Code (write it down!)

Setup: Adult A's iPad (New Device)
───────────────────────────────────
1. User installs app, signs in with password
2. App prompts: "Enter Recovery Code to access encrypted data"
3. User enters Recovery Code (from paper)
4. App downloads encrypted Master Key blob from server
5. App decrypts Master Key using Recovery Code
6. App stores Master Key in Keychain (device-only)
7. App can now decrypt FMKs and medical records ✅

Sync: Changes on iPhone → iPad
───────────────────────────────
1. iPhone: User adds vaccine record for Emma
2. iPhone: Encrypt with FMK_Emma (AES-256-GCM)
3. iPhone: Upload encrypted record to server
4. Server: Stores encrypted blob, sends Realtime notification
5. iPad: Receives notification "New record for Emma"
6. iPad: Downloads encrypted record from server
7. iPad: Decrypts with FMK_Emma (already in Keychain)
8. iPad: Displays vaccine record ✅

Conflict: Simultaneous Edits
─────────────────────────────
1. iPhone (offline): Edits Emma's allergy record → version A
2. iPad (offline): Edits same record → version B
3. iPhone comes online: Uploads version A (updated_at: T1)
4. iPad comes online: Uploads version B (updated_at: T2)
5. Server: Compares timestamps, keeps version B (T2 > T1)
6. iPhone: Downloads version B, overwrites local version A
7. Result: Last-write-wins (version B wins)
```

### Design Decisions

#### 1. Master Key Distribution: Recovery Code

**Decision**: Use a **256-bit recovery code** (24-word mnemonic) to encrypt Master Key for server storage.

**Flow**:

```
Account Creation (iPhone):
├─ Generate recovery code: 24 random words from BIP39 wordlist
├─ Derive recovery key: Argon2id(recovery code, salt, 64MB memory, 3 iterations)
├─ Encrypt Master Key: AES-256-GCM(Master Key, recovery key)
├─ Upload to server: { user_id, encrypted_master_key, salt }
├─ Show recovery code to user: "Write this down! Store securely!"
└─ User stores recovery code (paper, password manager, etc.)

New Device Setup (iPad):
├─ User signs in (Supabase auth)
├─ App prompts: "Enter Recovery Code"
├─ User enters 24 words
├─ App derives recovery key: Argon2id(recovery code, salt, 64MB memory, 3 iterations)
├─ App downloads encrypted Master Key from server
├─ App decrypts: Master Key = AES-256-GCM Decrypt(encrypted blob, recovery key)
├─ App stores Master Key in Keychain (device-only)
└─ App can now decrypt all FMKs and medical records ✅
```

**Recovery Code Format** (BIP39-style):

```
abandon ability able about above absent absorb abstract
absurd abuse access accident account accuse achieve acid
acoustic acquire across act action actor actress actual
```

**Why 24 words?**

- 24 words × 11 bits = 264 bits entropy (256 bits + 8-bit checksum)
- Industry standard (hardware wallets: Ledger, Trezor)
- Easy to write down, hard to mistype (BIP39 wordlist has error detection)
- More user-friendly than "AgK3jD9mP2xL7nF4sB1qW9vR8cT5yH6z" (random string)

**Rationale**:

- ✅ **Zero-Knowledge Maintained**: Server has encrypted Master Key, but no recovery code
- ✅ **User-Controlled**: Only user knows recovery code (written down)
- ✅ **Industry Standard**: Same approach as 1Password, Bitwarden, crypto wallets
- ✅ **Future-Proof**: Works even if all devices lost/destroyed
- ⚠️ **User Responsibility**: If recovery code lost, data unrecoverable (acceptable trade-off)

**Alternatives Considered**:

- ❌ **iCloud Keychain Sync**: Not zero-knowledge (Apple can access)
- ❌ **PAKE Protocol**: Too complex for hobby app
- ⚠️ **Device-to-Device Transfer**: Great UX, but only works if old device available (complementary, not primary)

**Security Properties**:

- If attacker steals server database: Has encrypted Master Key, but no recovery code (useless)
- If attacker steals recovery code: Has recovery code, but no encrypted Master Key from server (useless)
- If attacker steals BOTH: Can decrypt Master Key → Full access ⚠️ (same as stealing device password)

#### 2. Sync Protocol: Pull-Based with Realtime Notifications

**Decision**: Use **pull-based sync** (client polls server) with **Realtime notifications** for instant updates.

**Implementation** (Supabase):

```swift
// On app launch / foreground
func syncData() async {
    // 1. Pull latest changes from server
    let latestRecords = try await supabase
        .from("medical_records")
        .select()
        .gt("updated_at", lastSyncTimestamp)
        .execute()

    // 2. Merge with local database
    for record in latestRecords {
        await mergeRecord(record, strategy: .lastWriteWins)
    }

    // 3. Push local changes to server
    let localChanges = await getLocalChanges(since: lastSyncTimestamp)
    for change in localChanges {
        try await supabase
            .from("medical_records")
            .upsert(change)
            .execute()
    }

    // 4. Update last sync timestamp
    lastSyncTimestamp = Date()
}

// Real-time notifications (Supabase Realtime)
let channel = supabase.channel("medical_records")
channel.on(.insert) { message in
    // New record inserted by another device
    await downloadAndDecrypt(recordId: message.payload["id"])
}
channel.on(.update) { message in
    // Record updated by another device
    await downloadAndDecrypt(recordId: message.payload["id"])
}
channel.subscribe()
```

**Sync Triggers**:

1. **App launch**: Full sync
2. **App foreground**: Quick sync (changes since last sync)
3. **Realtime notification**: Instant download of specific record
4. **Manual pull-to-refresh**: User-initiated sync
5. **After local edit**: Push change to server immediately

**Rationale**:

- ✅ **Simple**: Pull-based is easier than bidirectional sync protocols
- ✅ **Offline-Friendly**: Works even if server unreachable (queue changes)
- ✅ **Real-Time UX**: Realtime notifications feel instant (like iCloud)
- ✅ **Battery-Efficient**: Realtime uses WebSockets (less battery than polling)
- ⚠️ **Not True P2P**: Requires server (acceptable for zero-knowledge model)

#### 3. Conflict Resolution: Last-Write-Wins

**Decision**: Use **timestamp-based last-write-wins** for conflict resolution.

**Schema**:

```sql
CREATE TABLE medical_records (
    record_id UUID PRIMARY KEY,
    family_member_id UUID NOT NULL,
    encrypted_data BYTEA NOT NULL,

    -- Sync metadata (plaintext)
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    device_id UUID,  -- Which device made last edit

    -- Version for conflict detection
    version INTEGER NOT NULL DEFAULT 1
);
```

**Conflict Resolution Flow**:

```
Scenario: iPhone and iPad both edit Emma's allergy record offline

iPhone (offline):
├─ Edits record (version 5 → version 6)
├─ Sets updated_at: 2025-01-20 14:30:00
└─ Queues for upload

iPad (offline):
├─ Edits same record (version 5 → version 6)
├─ Sets updated_at: 2025-01-20 14:32:00
└─ Queues for upload

iPhone comes online first:
├─ Uploads version 6 (updated_at: 14:30:00)
└─ Server stores (current version: 6, updated_at: 14:30:00)

iPad comes online later:
├─ Uploads version 6 (updated_at: 14:32:00)
├─ Server compares: 14:32:00 > 14:30:00 → iPad wins
├─ Server updates record (version 6 → version 7, updated_at: 14:32:00)
└─ Server sends notification to iPhone: "Record updated"

iPhone receives notification:
├─ Downloads version 7
├─ Compares: Server version 7 > Local version 6
├─ Overwrites local version with server version
└─ User sees iPad's changes (last write wins)
```

**User Experience**:

- ✅ **No manual merge**: System automatically picks latest version
- ⚠️ **Data Loss Possible**: iPhone's edits discarded (rare for medical records)
- ⚠️ **No conflict UI**: Users don't see "Conflict detected, choose version"

**Why Last-Write-Wins is Acceptable**:

1. **Medical Records Are Append-Only (Mostly)**:
   - Adding vaccine record: No conflict (new record)
   - Editing allergy note: Rare simultaneous edits
   - Deleting record: Infrequent operation

2. **Conflict Frequency is Low**:
   - Different family members' records don't conflict (separate FMKs)
   - Same user rarely edits same record on two devices simultaneously
   - Most edits are additions (vaccines, visits), not modifications

3. **KISS Principle**:
   - CRDTs are complex (operational transforms, vector clocks)
   - Manual merge UI is poor UX for family health app
   - Last-write-wins is understood ("latest version wins")

**Trade-off Accepted**: Rare data loss in exchange for simplicity.

**Future Enhancement** (Phase 4):

- Audit trail: Show "This record was edited on iPad at 14:32, overwrote iPhone edit"
- Conflict log: Let user review lost edits (if they care)

**Alternatives Considered**:

- ❌ **CRDTs**: Too complex for hobby app, overkill for medical records
- ❌ **Manual Merge UI**: Poor UX, intimidating for non-technical users
- ⚠️ **Append-Only Log**: Good for audit trail, but doesn't solve conflict (complementary)

#### 4. Metadata for Sync

**Decision**: Sync metadata is **plaintext** for coordination, content is **encrypted**.

**Plaintext Metadata** (Required for Sync):

```json
{
  "record_id": "f47ac10b-...",
  "family_member_id": "7c9e6679-...",
  "record_type": "vaccine",  // Optional (for filtering)
  "created_at": "2025-01-20T14:30:00Z",
  "updated_at": "2025-01-20T14:32:00Z",
  "device_id": "550e8400-...",
  "version": 7,
  "size_bytes": 2048
}
```

**Encrypted Content**:

```json
{
  "encrypted_data": "AQAAAACAAABZwg...",  // AES-256-GCM ciphertext
  "nonce": "base64-encoded-nonce",       // 96-bit IV for AES-GCM
  "tag": "base64-encoded-auth-tag"       // 128-bit authentication tag
}
```

**Why Metadata is Plaintext**:

1. **Sync Coordination**: Server needs `updated_at` to determine "latest version"
2. **Efficient Queries**: `WHERE family_member_id = X AND updated_at > Y`
3. **Realtime Notifications**: Server sends "Record X updated" (need ID)

**Privacy Impact**: See `docs/research/privacy-and-data-exposure-analysis.md` Section 1.4.

**Design Choice**: If `record_type` is plaintext, server knows health categories ("vaccine", "allergy"). If encrypted, all filtering is client-side.

**Recommendation**: Start with plaintext `record_type` (better UX), can encrypt later if needed.

#### 5. Offline Behavior: Queue and Sync

**Decision**: **Queue local changes** in Core Data, sync when online.

**Schema**:

```swift
// Core Data entity: PendingSyncOperation
entity PendingSyncOperation {
    operation_id: UUID
    operation_type: String  // "insert", "update", "delete"
    record_id: UUID
    encrypted_payload: Data  // Encrypted record data
    created_at: Date
    retry_count: Int
}
```

**Flow**:

```
User edits record (offline):
├─ Save to local Core Data (encrypted with FMK)
├─ Create PendingSyncOperation(type: "update", record_id, payload)
└─ Show success to user ("Saved locally, will sync when online")

Network comes online:
├─ Detect network availability (Reachability)
├─ Fetch all PendingSyncOperation records
├─ For each operation:
│   ├─ Attempt upload to server
│   ├─ If success: Delete PendingSyncOperation
│   └─ If failure: Increment retry_count, retry later
└─ Show notification: "Synced 3 changes"

Error Handling:
├─ If retry_count > 5: Show user "Sync failed, check connection"
├─ If conflict (version mismatch): Apply last-write-wins
└─ If network unreachable: Keep queued (retry when online)
```

**Rationale**:

- ✅ **Offline-First UX**: User can edit records on airplane, subway
- ✅ **No Data Loss**: Changes queued locally until successfully synced
- ✅ **Background Sync**: iOS background tasks can sync opportunistically
- ⚠️ **Storage Overhead**: Pending operations consume local storage (acceptable for <1000 records)

#### 6. Attachment Sync Strategy

**Decision**: Use **separate attachment blobs with content-addressed deduplication** for efficient delta sync.

**Problem Statement** (from Issue #39):

Medical records often include large binary attachments:

- Photos of vaccine cards (1-5 MB per photo)
- Scanned prescription PDFs (500 KB - 10 MB)
- Lab result images

**Inefficient approach**: Embed attachments in medical record encrypted blob

- Editing a note field → re-upload entire record including all photos
- 50 vaccine records with photos → re-upload 50+ MB for minor edit ❌

**Efficient approach**: Separate attachment storage with delta sync

- Attachments stored separately from record metadata
- Only sync changed attachments, not all attachments ✅

**Schema Design**:

```sql
-- Medical records (metadata only, small blobs)
CREATE TABLE medical_records (
    record_id UUID PRIMARY KEY,
    family_member_id UUID NOT NULL,

    -- Encrypted metadata (date, provider, notes, etc.)
    encrypted_data BYTEA NOT NULL,
    nonce BYTEA NOT NULL,
    tag BYTEA NOT NULL,

    -- Sync metadata (plaintext)
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL,
    device_id UUID,
    version INTEGER NOT NULL DEFAULT 1,

    -- Reference to attachments (encrypted list of attachment IDs)
    encrypted_attachment_refs BYTEA  -- Encrypted JSON array: ["att-uuid-1", "att-uuid-2"]
);

-- Attachments (binary blobs, stored separately)
CREATE TABLE attachments (
    attachment_id UUID PRIMARY KEY,
    family_member_id UUID NOT NULL,  -- Which patient this belongs to

    -- Encrypted binary content
    encrypted_data BYTEA NOT NULL,
    nonce_data BYTEA NOT NULL,
    tag_data BYTEA NOT NULL,

    -- Encrypted metadata (MIME type, filename, original size)
    encrypted_metadata BYTEA NOT NULL,
    nonce_metadata BYTEA NOT NULL,
    tag_metadata BYTEA NOT NULL,

    -- Content-addressed deduplication
    content_hmac TEXT NOT NULL,  -- HMAC-SHA256(attachment, FMK)

    -- Sync metadata (plaintext, minimal)
    encrypted_size_bytes INTEGER NOT NULL,  -- Size of encrypted blob (for storage allocation)
    created_at TIMESTAMPTZ NOT NULL,
    uploaded_by_device_id UUID NOT NULL,

    -- Index for deduplication
    UNIQUE(family_member_id, content_hmac)
);

-- Attachment references (many-to-many: records can share attachments)
CREATE TABLE record_attachments (
    record_id UUID REFERENCES medical_records(record_id),
    attachment_id UUID REFERENCES attachments(attachment_id),
    attachment_order INTEGER NOT NULL,  -- Display order in UI
    PRIMARY KEY (record_id, attachment_id)
);
```

**Why Separate Tables?**

1. **Delta Sync**: Attachments sync independently from records
   - Edit record note → sync only `medical_records` row (few KB)
   - Add new photo → sync only new `attachments` row (1-5 MB)
   - No unnecessary data transfer ✅

2. **Content Deduplication**: Same photo in multiple records → stored once
   - Example: "Vaccine card for Emma" scanned twice by accident
   - `content_hmac` = HMAC-SHA256(plaintext photo, FMK_Emma)
   - If same HMAC exists → reuse existing attachment (no upload) ✅

3. **Many-to-Many Relationships**: One attachment can belong to multiple records
   - Example: Insurance card photo attached to multiple visit records
   - Stored once, referenced many times ✅

**Sync Flow Example**:

```
Scenario: User adds vaccine record with photo

iPhone (offline):
├─ User adds vaccine record for Emma
├─ User attaches photo (vaccine_card.jpg, 2.3 MB)
├─ App encrypts photo with FMK_Emma
│  └─ AES-256-GCM(photo, FMK_Emma) → encrypted_photo
├─ App computes content HMAC: HMAC-SHA256(plaintext photo, FMK_Emma) → "a3f2b9..."
├─ App creates record:
│  ├─ Medical record (encrypted: date, provider, notes)
│  └─ Attachment (encrypted photo, content_hmac, size_bytes)
├─ Queues for sync:
│  ├─ PendingSyncOperation(type: "insert", table: "medical_records")
│  └─ PendingSyncOperation(type: "insert", table: "attachments")
└─ Shows success to user

iPhone comes online:
├─ Syncs medical record (uploads ~500 bytes encrypted metadata)
├─ Checks if attachment exists: Query attachments WHERE content_hmac = "a3f2b9..."
│  └─ Not found → Upload attachment (2.3 MB)
├─ Creates record_attachment link
└─ Deletes PendingSyncOperation entries

iPad (syncing later):
├─ Receives Realtime notification: "New medical record for Emma"
├─ Downloads medical record metadata (500 bytes)
├─ Reads encrypted_attachment_refs → ["att-uuid-123"]
├─ Checks local database: Does attachment att-uuid-123 exist?
│  └─ Not found → Download attachment (2.3 MB)
├─ Decrypts with FMK_Emma
└─ Displays vaccine record with photo ✅

Scenario: User edits note field (no photo change)

iPhone:
├─ User edits "Notes" field in vaccine record
├─ App updates encrypted_data (new notes)
├─ App does NOT touch attachments (same photo)
└─ Uploads only medical_records row (500 bytes, not 2.3 MB) ✅

iPad:
├─ Receives notification: "Record updated"
├─ Downloads new medical_records row (500 bytes)
├─ Attachments already exist locally → no download ✅
└─ Displays updated notes with existing photo
```

**Content Deduplication Flow**:

```
Scenario: User accidentally attaches same photo twice

iPhone:
├─ Record 1: Attach vaccine_card.jpg → content_hmac = "a3f2b9..."
│  └─ Uploads attachment (att-uuid-123)
├─ Record 2: Attach same vaccine_card.jpg → content_hmac = "a3f2b9..."
│  └─ Checks: SELECT * FROM attachments WHERE content_hmac = "a3f2b9..." AND family_member_id = emma_id
│  └─ Found! → Reuse att-uuid-123 (no upload) ✅
└─ Both records reference same attachment (stored once, 2.3 MB saved)
```

**Security Considerations**:

**Q: Does `content_hmac` leak information?**

A: Minimal privacy impact due to HMAC:

- ✅ **Server cannot see photo content** (encrypted with FMK)
- ✅ **Server cannot identify specific photos** (HMAC is keyed, prevents rainbow tables)
- ⚠️ **Server can detect duplicate photos within same patient** (same HMAC → same image for that patient)
- ⚠️ **Server can infer relationships** ("Record A and Record B have same attachment")

**Why HMAC is better than plain hashing**: HMAC is keyed by the FMK, so:

- Deduplication works within same patient's records (Emma's photos)
- Different patients have different HMACs even for identical photos (Emma's vaccine card ≠ Liam's vaccine card HMAC)
- Server cannot pre-compute known medical document HMACs (rainbow table resistance)

**Alternatives Considered:**

1. **Bloom Filters for Privacy-Preserving Deduplication**:

   **How it would work:**
   - Server maintains bloom filter of existing content hashes
   - Client queries: "Does this hash exist?" without sending hash
   - Bloom filter returns: "Definitely not" or "Possibly yes"
   - On "possibly yes", client sends hash to confirm (server sees hash)
   - On "definitely not", client uploads (server sees hash)

   **Why rejected:**
   - ❌ **False positives leak hashes anyway**: Client must send hash to confirm matches
   - ❌ **Deletions problem** (excellent observation!): Standard bloom filters don't support deletions
     - When attachment deleted, can't remove from bloom filter
     - Counting bloom filters support deletions but have increasing false positive rates
     - False positives accumulate over time, degrading performance
   - ❌ **Limited privacy gain**: Server still learns "duplicate exists" (structural information)
   - ❌ **Complexity**: Violates KISS principle, adds implementation complexity

   **Conclusion**: Bloom filters don't provide meaningful privacy improvement because:
   - Server learns about duplicates either way (the structural leak)
   - Hash eventually revealed on confirmation or upload
   - Deletion support is problematic

2. **Private Set Intersection (PSI)**:
   - Cryptographic protocol for finding set intersection without revealing full sets
   - Client and server compute common hashes without exposing non-matching hashes
   - ❌ **Too complex**: Multi-round cryptographic protocol, significant overhead
   - ❌ **Not in CryptoKit**: Requires third-party crypto libraries
   - ❌ **Overkill**: Medical records don't justify this complexity

3. **Homomorphic Equality for Encrypted Hashes**:
   - Encrypt hashes with deterministic encryption (same hash → same ciphertext)
   - Server can match duplicates without seeing plaintext hashes
   - ❌ **Not in CryptoKit**: Requires specialized crypto (deterministic encryption or order-preserving encryption)
   - ❌ **Security risks**: Deterministic encryption leaks equality (reveals duplicates, same structural leak)
   - ⚠️ **Future option**: Could explore in Phase 4 with vetted library

4. **Client-Side Only Deduplication**:

   ```swift
   // Local Core Data entity
   entity LocalAttachmentHash {
       content_hash: String
       attachment_id: UUID
       uploaded_at: Date
   }

   // Check local database only
   func checkDuplicate(data: Data) -> UUID? {
       let hash = SHA256.hash(data: data).hexString
       return localDB.findAttachment(hash: hash)  // Server never sees hash
   }
   ```

   **Pros:**
   - ✅ **Perfect privacy**: Server never sees any hashes
   - ✅ **Simple**: Just local SQLite query
   - ✅ **No deletion problem**: Local database supports deletions trivially

   **Cons:**
   - ❌ **No cross-device deduplication**: Each device uploads same attachment independently
   - ❌ **Bandwidth waste**: User with iPhone + iPad pays 2× upload cost
   - ❌ **Storage waste**: Server stores same attachment twice

   **Why rejected:** Users frequently sync across multiple devices (iPhone, iPad, Mac), cross-device deduplication is valuable

5. **Plaintext Hash (Chosen Approach)**:
   - ✅ **Simple**: Standard SQL query, easy to implement
   - ✅ **Cross-device deduplication**: Upload once, use everywhere
   - ✅ **Scoped to family_member_id**: Server can't correlate across families
   - ✅ **Deletion-friendly**: Standard SQL DELETE, no false positive accumulation
   - ⚠️ **Server sees duplicates**: Acceptable trade-off (minimal new information)

**Why Plaintext Hash Privacy Cost is Acceptable:**

Server **already knows** from other metadata:

- Attachment size (2,348,192 bytes)
- MIME type (image/jpeg)
- Upload timestamp (2025-01-20 14:32:00)
- Which records reference which attachments (`record_attachments` table)

Adding content hash reveals:

- "Record A and Record B have same photo" (structural relationship)
- But server **cannot see photo content** (encrypted with FMK)
- And hash is scoped to `family_member_id` (can't correlate across families)

**Minimal new information leaked** compared to massive efficiency gain (99.975% bandwidth savings).

**Why Server Doesn't Need MIME Type:**

**Question**: Why not store `mime_type` as plaintext metadata for server-side validation or filtering?

**Answer**: Server doesn't need it because:

1. **No Server-Side Validation Needed**:
   - Client validates file types before encryption (iOS checks MIME type)
   - Server treats all attachments as opaque encrypted blobs
   - Malicious client can't exploit server (encrypted executables can't run on server)

2. **No Server-Side Filtering Needed**:
   - Client filters locally (already has attachment metadata in Core Data)
   - No API endpoint needs "get all image attachments" (client decides what to display)

3. **No Server-Side Transcoding**:
   - Attachments are encrypted (server can't transcode encrypted JPEGs to WebP)
   - Client must download and decrypt regardless of format

4. **Zero-Knowledge Principle**:
   - Server knowing "image/jpeg" vs "application/pdf" reveals health data patterns
   - Example: "User uploaded 50 PDFs" → might indicate lab results or prescriptions
   - Better: Server only knows "User uploaded 50 encrypted blobs of various sizes"

**Privacy Gain**: Server cannot infer "this family uses lots of images (vaccine cards?) vs PDFs (lab results)"

**Attachment Encryption**:

```swift
// Metadata structure (encrypted separately from binary data)
struct AttachmentMetadata: Codable {
    let mimeType: String       // "image/jpeg", "application/pdf"
    let filename: String       // "vaccine_card.jpg"
    let originalSizeBytes: Int // Original file size (before encryption)
}

// Encrypt attachment with FMK
func encryptAttachment(data: Data, metadata: AttachmentMetadata, fmk: SymmetricKey) throws -> EncryptedAttachment {
    // Compute content hash BEFORE encryption (for deduplication)
    let contentHash = SHA256.hash(data: data)
    let contentHashString = contentHash.compactMap { String(format: "%02x", $0) }.joined()

    // Encrypt binary data
    let nonceData = AES.GCM.Nonce()
    let sealedData = try AES.GCM.seal(data, using: fmk, nonce: nonceData)

    // Encrypt metadata separately (allows decrypting metadata without full binary)
    let metadataJSON = try JSONEncoder().encode(metadata)
    let nonceMetadata = AES.GCM.Nonce()
    let sealedMetadata = try AES.GCM.seal(metadataJSON, using: fmk, nonce: nonceMetadata)

    return EncryptedAttachment(
        attachmentId: UUID(),
        contentHash: contentHashString,
        encryptedData: sealedData.ciphertext,
        nonceData: nonceData.withUnsafeBytes { Data($0) },
        tagData: sealedData.tag,
        encryptedMetadata: sealedMetadata.ciphertext,
        nonceMetadata: nonceMetadata.withUnsafeBytes { Data($0) },
        tagMetadata: sealedMetadata.tag,
        encryptedSizeBytes: sealedData.ciphertext.count  // Server only sees encrypted size
    )
}

// Decrypt metadata only (for displaying file list without downloading full binary)
func decryptAttachmentMetadata(encrypted: EncryptedAttachment, fmk: SymmetricKey) throws -> AttachmentMetadata {
    let nonce = try AES.GCM.Nonce(data: encrypted.nonceMetadata)
    let sealedBox = try AES.GCM.SealedBox(nonce: nonce,
                                          ciphertext: encrypted.encryptedMetadata,
                                          tag: encrypted.tagMetadata)
    let metadataJSON = try AES.GCM.open(sealedBox, using: fmk)
    return try JSONDecoder().decode(AttachmentMetadata.self, from: metadataJSON)
}

// Decrypt full attachment (binary data)
func decryptAttachment(encrypted: EncryptedAttachment, fmk: SymmetricKey) throws -> Data {
    let nonce = try AES.GCM.Nonce(data: encrypted.nonceData)
    let sealedBox = try AES.GCM.SealedBox(nonce: nonce,
                                          ciphertext: encrypted.encryptedData,
                                          tag: encrypted.tagData)
    return try AES.GCM.open(sealedBox, using: fmk)
}
```

**Bonus Optimization**: Encrypting metadata separately allows:

- Download metadata for all attachments (small, < 1 KB each)
- Display file list with names, types, sizes
- Download full binary only when user taps to view (lazy loading)
- Example: "10 attachments = 10 KB metadata vs 20 MB binaries"

**Performance Analysis**:

| Scenario | Without Separate Attachments | With Separate Attachments | Savings |
|----------|------------------------------|---------------------------|---------|
| Add record with 1 photo (2 MB) | Upload 2 MB | Upload 2 MB | 0% (same) |
| Edit note (no photo change) | Upload 2 MB | Upload 500 bytes | **99.975%** ✅ |
| Add 10 records with same photo | Upload 20 MB | Upload 2 MB + (10 × 500 bytes) | **90%** ✅ |
| Sync to new device (50 records, 25 photos) | Download 50 MB | Download 25 MB + (50 × 500 bytes) | **50%** ✅ |

**Trade-offs Accepted**:

| Decision | Trade-off | Justification |
|----------|-----------|---------------|
| **Separate attachment storage** | More complex schema (3 tables vs 1) | Massive bandwidth savings, essential for photos/PDFs |
| **HMAC-based content_hmac** | Server can detect duplicate photos within same patient | Enables efficient deduplication with rainbow table resistance |
| **Encrypted metadata separately** | Two encryption operations per attachment | Allows lazy loading (metadata without full binary download) |
| **No chunking** | Can't resume interrupted uploads | Photos are small (<5 MB), chunking is overkill |

**Future Enhancements** (Phase 4):

- **Thumbnail generation**: Generate small encrypted thumbnails for list views
- **Progressive loading**: Download low-res version first, full-res on demand
- **Chunked uploads**: For very large PDFs (>10 MB), implement chunking
- **Client-side compression**: Compress photos before encryption (WebP, HEIC)

**Rationale**:

- ✅ **Solves Issue #39 Question #5**: Efficient delta sync for attachments
- ✅ **KISS Principle**: Separate tables, no complex chunking
- ✅ **Zero-Knowledge**: Server stores encrypted attachments (can't see photos/PDFs)
- ✅ **Bandwidth Efficient**: 99.975% savings when editing notes
- ✅ **Storage Efficient**: Deduplication prevents storing same photo multiple times
- ✅ **Scalable**: Works for 50+ vaccine records with photos

#### 7. Device Management

**Decision**: Track devices in server database for audit and revocation.

**Schema**:

```sql
CREATE TABLE user_devices (
    device_id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES user_profiles(user_id),
    device_name TEXT NOT NULL,  // "Alice's iPhone", "Alice's iPad"
    device_type TEXT,  // "iPhone 15 Pro", "iPad Air"
    first_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_active BOOLEAN NOT NULL DEFAULT TRUE
);
```

**Device Registration** (Automatic):

```swift
// On first launch
func registerDevice() async {
    let deviceId = UUID()  // Generate new device ID
    let deviceName = UIDevice.current.name  // "Alice's iPhone"

    try await supabase
        .from("user_devices")
        .insert({
            "device_id": deviceId,
            "user_id": currentUserId,
            "device_name": deviceName,
            "device_type": UIDevice.current.model
        })
        .execute()

    // Store device ID locally
    UserDefaults.standard.set(deviceId, forKey: "device_id")
}

// On every sync
func updateLastSeen() async {
    let deviceId = UserDefaults.standard.string(forKey: "device_id")
    try await supabase
        .from("user_devices")
        .update(["last_seen_at": Date()])
        .eq("device_id", deviceId)
        .execute()
}
```

**Device Revocation**:

```
User goes to Settings > Devices:
├─ Sees list: "iPhone (last seen: 2 min ago)", "iPad (last seen: 3 days ago)"
├─ Taps "Remove iPad"
├─ App updates: is_active = false
├─ Next time iPad syncs: Server rejects (401 Unauthorized)
└─ iPad shows: "This device has been removed. Sign in again."

iPad re-setup:
├─ User enters recovery code
├─ App re-registers as new device
└─ Access restored ✅
```

**Rationale**:

- ✅ **Audit Trail**: User can see "I don't recognize that iPad → revoke"
- ✅ **Security**: Stolen device can be remotely disabled
- ⚠️ **Not Cryptographic Revocation**: Device can still decrypt local data (only blocks sync)

**Future Enhancement** (Phase 4):

- Per-device encryption keys (rotate keys on revocation)
- Remote wipe (delete local Keychain via server command)

### CryptoKit Implementation Details

#### Recovery Code Generation

```swift
import CryptoKit
import Foundation

// Generate 24-word BIP39 recovery code
func generateRecoveryCode() -> [String] {
    // Generate 256 bits of entropy
    var entropy = Data(count: 32)
    _ = entropy.withUnsafeMutableBytes {
        SecRandomCopyBytes(kSecRandomDefault, 32, $0.baseAddress!)
    }

    // Convert to BIP39 mnemonic (24 words)
    return BIP39.encode(entropy: entropy)  // Use vetted BIP39 library
}

// Encrypt Master Key with recovery code
func encryptMasterKey(masterKey: SymmetricKey, recoveryCode: [String], userId: UUID) throws -> (encryptedMasterKey: Data, salt: Data) {
    let sodium = Sodium()
    let recoveryPhrase = recoveryCode.joined(separator: " ")

    // Generate random salt per user (prevents precomputation attacks)
    guard let salt = sodium.randomBytes.buf(length: 32) else {
        throw CryptoError.randomGenerationFailed
    }

    // Derive recovery key using Argon2id
    guard let recoveryKey = sodium.pwHash.hash(
        outputLength: 32,
        passwd: recoveryPhrase.bytes,
        salt: salt,
        opsLimit: sodium.pwHash.OpsLimitModerate,    // ~3 iterations
        memLimit: sodium.pwHash.MemLimitModerate,    // ~64 MB
        alg: .Argon2ID13
    ) else {
        throw CryptoError.keyDerivationFailed
    }

    // Encrypt Master Key with AES-GCM using the derived recovery key
    let symmetricKey = SymmetricKey(data: Data(recoveryKey))
    let nonce = AES.GCM.Nonce()
    let sealedBox = try AES.GCM.seal(
        masterKey.withUnsafeBytes { Data($0) },
        using: symmetricKey,
        nonce: nonce
    )

    // Return: encrypted master key and salt
    // Salt must be stored alongside encrypted_master_key on server
    // Server stores: { encrypted_master_key: Data, recovery_salt: Data }
    return (encryptedMasterKey: sealedBox.combined!, salt: Data(salt))
}

// Decrypt Master Key on new device
func decryptMasterKey(encryptedBlob: Data, recoveryCode: [String], salt: Data) throws -> SymmetricKey {
    let sodium = Sodium()
    let recoveryPhrase = recoveryCode.joined(separator: " ")

    // Derive same recovery key using the stored salt
    // Client fetches salt from server: GET /auth/recovery-salt?userId={userId}
    guard let recoveryKey = sodium.pwHash.hash(
        outputLength: 32,
        passwd: recoveryPhrase.bytes,
        salt: salt.bytes,
        opsLimit: sodium.pwHash.OpsLimitModerate,    // Same as encryption
        memLimit: sodium.pwHash.MemLimitModerate,    // Same as encryption
        alg: .Argon2ID13
    ) else {
        throw CryptoError.keyDerivationFailed
    }

    // Decrypt Master Key using AES-GCM
    let symmetricKey = SymmetricKey(data: Data(recoveryKey))
    let sealedBox = try AES.GCM.SealedBox(combined: encryptedBlob)
    let masterKeyData = try AES.GCM.open(sealedBox, using: symmetricKey)

    return SymmetricKey(data: masterKeyData)
}
```

#### Sync Encryption (AES-GCM)

```swift
// Encrypt medical record for sync
func encryptRecord(record: MedicalRecord, fmk: SymmetricKey) throws -> EncryptedRecord {
    let plaintext = try JSONEncoder().encode(record)
    let nonce = AES.GCM.Nonce()

    let sealedBox = try AES.GCM.seal(plaintext, using: fmk, nonce: nonce)

    return EncryptedRecord(
        recordId: record.id,
        familyMemberId: record.familyMemberId,
        encryptedData: sealedBox.ciphertext,
        nonce: nonce.withUnsafeBytes { Data($0) },
        tag: sealedBox.tag,
        updatedAt: Date()
    )
}

// Decrypt medical record on sync
func decryptRecord(encrypted: EncryptedRecord, fmk: SymmetricKey) throws -> MedicalRecord {
    let nonce = try AES.GCM.Nonce(data: encrypted.nonce)
    let sealedBox = try AES.GCM.SealedBox(nonce: nonce,
                                          ciphertext: encrypted.encryptedData,
                                          tag: encrypted.tag)

    let plaintext = try AES.GCM.open(sealedBox, using: fmk)
    return try JSONDecoder().decode(MedicalRecord.self, from: plaintext)
}
```

## Consequences

### Positive

1. **Multi-Device Support**: User can access data from iPhone, iPad, Mac seamlessly
2. **Zero-Knowledge Maintained**: Server never sees Master Key (encrypted with recovery code)
3. **Offline-First**: Changes work offline, sync when network available
4. **Simple Conflict Resolution**: Last-write-wins avoids complex merge logic
5. **Industry-Standard Recovery**: 24-word recovery code (BIP39) is familiar to crypto users
6. **Real-Time UX**: Realtime notifications make sync feel instant
7. **Device Management**: User can audit and revoke devices
8. **Future-Proof**: Recovery code works even if all devices lost
9. **Efficient Attachment Sync**: Separate storage enables delta sync (99.975% bandwidth savings when editing notes)
10. **Content Deduplication**: Same photo stored once, even if attached to multiple records
11. **Scalable for Photos/PDFs**: Designed for medical records with large attachments (vaccine cards, prescriptions)
12. **MIME Type Privacy**: Server cannot see file types (images vs PDFs), preventing health data pattern inference
13. **Lazy Loading Support**: Separate metadata encryption enables previewing attachment lists without downloading full binaries

### Negative

1. **Recovery Code Responsibility**: If user loses recovery code, data is unrecoverable
   - **Severity**: High (permanent data loss)
   - **Mitigation**: Clear instructions during setup, multiple backup options (paper, password manager)
   - **Accepted Trade-off**: Zero-knowledge requires user responsibility

2. **Last-Write-Wins Data Loss**: Simultaneous edits on different devices → one edit discarded
   - **Severity**: Low (rare for medical records)
   - **Mitigation**: Timestamp display ("Last edited on iPad 5 min ago")
   - **Accepted Trade-off**: Simplicity over complex conflict resolution

3. **Master Key on Server (Encrypted)**: Encrypted Master Key stored on server
   - **Risk**: If recovery code is weak/leaked + server breached → data decryptable
   - **Mitigation**: 256-bit recovery code (strong), Argon2id memory-hard derivation
   - **Accepted Trade-off**: Necessary for multi-device without iCloud Keychain

4. **Device Revocation Not Cryptographic**: Revoked device can still decrypt local data
   - **Severity**: Medium (stolen device retains access to old data)
   - **Mitigation**: User can change recovery code → force all devices to re-auth
   - **Future**: Per-device encryption keys (Phase 4)

5. **Sync Metadata Plaintext**: Server sees record IDs, timestamps, family member IDs
   - **Impact**: Same metadata leakage as ADR-0003
   - **Accepted Trade-off**: Required for efficient sync coordination

6. **Attachment Content Hash Exposed**: Server can detect duplicate photos within family member
   - **Severity**: Low (hash scoped to family member, server can't see photo content)
   - **Risk**: Server knows "Record A and Record B have same attachment"
   - **Mitigation**: Deduplication scoped to family member (not across all users)
   - **Accepted Trade-off**: Deduplication efficiency > minor metadata leak

7. **More Complex Schema**: Attachments require 3 tables (medical_records, attachments, record_attachments)
   - **Severity**: Low (standard relational design)
   - **Impact**: More complex sync logic (must sync attachments separately from records)
   - **Accepted Trade-off**: Complexity justified by 99.975% bandwidth savings

### Neutral

1. **BIP39 Dependency**: Requires third-party BIP39 library (or implement ourselves)
   - **Note**: BIP39 is well-vetted (Bitcoin standard since 2013)
   - **Alternative**: Use vetted library like [NBKBip39](https://github.com/SebastianBoldt/NBKBip39)

2. **Pull-Based Sync**: Not true P2P (requires server)
   - **Note**: Consistent with ADR-0003 (server as mailbox)
   - **Acceptable**: Zero-knowledge server model

3. **Supabase Realtime**: Locks us into Supabase (or compatible backend)
   - **Note**: Can implement with other backends (WebSockets, Server-Sent Events)
   - **Acceptable**: Supabase is free tier, open source

### Trade-offs Accepted

| Decision | Trade-off | Justification |
|----------|-----------|---------------|
| **Recovery Code** | User responsibility for backup | Zero-knowledge requires user-controlled secrets |
| **Last-Write-Wins** | Rare data loss on conflicts | Medical records are mostly append-only |
| **Encrypted Master Key on Server** | Server breach + recovery leak = access | Enables multi-device without iCloud |
| **Plaintext Sync Metadata** | Server sees structure | Efficient sync requires coordination |
| **Device Revocation** | Local data persists | Acceptable (old data, not new syncs) |
| **Separate Attachment Storage** | More complex schema (3 tables) | 99.975% bandwidth savings justifies complexity |
| **Plaintext Content Hash** | Server detects duplicate photos | Enables deduplication, scoped to family member |
| **No Chunked Uploads** | Can't resume uploads >5MB | Medical photos are small, chunking is overkill |

## Implementation Notes

### Phase 1: Local Encryption

- **Not needed**: Sync is Phase 2 feature
- **Preparation**: Design Core Data schema for sync (include `updated_at`, `version`)

### Phase 2: Multi-Device Sync (FULL IMPLEMENTATION)

1. **Recovery Code System**:
   - Generate 24-word BIP39 mnemonic
   - Encrypt Master Key with recovery code
   - Upload encrypted Master Key to server
   - Show recovery code to user (with backup instructions)
2. **New Device Setup**:
   - Prompt for recovery code on sign-in
   - Download encrypted Master Key from server
   - Decrypt with recovery code
   - Store Master Key in Keychain
3. **Sync Protocol**:
   - Implement pull-based sync (on launch, foreground)
   - Supabase Realtime for push notifications
   - Queue local changes (PendingSyncOperation)
4. **Conflict Resolution**:
   - Compare `updated_at` timestamps
   - Keep latest version (last-write-wins)
   - Update local database, notify user if needed
5. **Device Management**:
   - Register device on first launch
   - Update `last_seen_at` on every sync
   - Settings UI: List devices, revoke device
6. **Attachment Sync**:
   - Create `attachments` and `record_attachments` tables in database schema
   - Implement `encryptAttachment()` and `decryptAttachment()` with HMAC-based content addressing
   - Sync attachments separately from medical records
   - Check for duplicate attachments using `content_hmac` before uploading
   - Download attachments on-demand (lazy loading for large photo libraries)

### Phase 3: Family Sharing

- Sync access grants (wrapped FMKs) same way as medical records
- Realtime notification when new access granted

### Phase 4: Enhancements

- **Audit Trail**: Show edit history, conflicting versions
- **Per-Device Keys**: Cryptographic device revocation (rotate FMKs)
- **Device-to-Device Transfer**: iOS 12.4+ Quick Start (in-person QR code)
- **Recovery Code Rotation**: Change recovery code (re-encrypt Master Key)
- **Conflict Log**: Let user review overwritten edits
- **Attachment Enhancements**:
  - Thumbnail generation (encrypted thumbnails for list views)
  - Progressive loading (low-res preview, full-res on demand)
  - Chunked uploads for large PDFs (>10 MB)
  - Client-side compression (WebP, HEIC before encryption)

## Related Decisions

- **ADR-0001**: Crypto Architecture First (establishes zero-knowledge requirement)
- **ADR-0002**: Key Hierarchy (defines Master Key, FMKs)
- **ADR-0003**: Multi-User Sharing Model (server as mailbox)
- **ADR-0005**: Access Revocation (syncs revocation across devices)

## References

- Issue #39: ADR-0004 Sync Encryption
- `docs/research/e2ee-sharing-patterns-research.md` (Section 9.2: Sync recommendations)
- `docs/research/privacy-and-data-exposure-analysis.md` (Metadata leakage)
- AGENTS.md: Cryptography specifications
- [BIP39 Specification](https://github.com/bitcoin/bips/blob/master/bip-0039.mediawiki): Mnemonic code for generating deterministic keys
- [1Password Security Design: Account Password vs. Secret Key](https://support.1password.com/secret-key-security/)
- [Supabase Realtime Documentation](https://supabase.com/docs/guides/realtime)
- [iOS Background Tasks](https://developer.apple.com/documentation/backgroundtasks): For background sync

---

**Decision Date**: 2025-12-20
**Author**: Claude Code (based on ADR-0002 and ADR-0003)
**Reviewers**: [To be assigned]
