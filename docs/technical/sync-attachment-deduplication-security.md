# Attachment Deduplication Security Analysis

## Critical Vulnerability: Rainbow Table Attack on SHA256 Hashes

**Problem**: Original design used `SHA256(plaintext_attachment)` for content-addressed deduplication:

```swift
// ❌ VULNERABLE
let contentHash = SHA256.hash(data: attachmentData).hexString
```

**Attack scenario:**

1. Attacker pre-computes hashes of common vaccine cards:
   - CDC Pfizer card template: `a3f2b945c8e1...`
   - CDC Moderna card template: `b7e9f3a2d4c6...`
   - NHS vaccination certificate: `d4f1a8b9e2c3...`

2. Server sees user uploaded attachment with hash `a3f2b945c8e1...`

3. Attacker learns: "User has Pfizer vaccine card" (known-plaintext attack)

4. Attacker builds profile: "User uploaded 12 CDC vaccine cards, 3 prescription PDFs, 1 insurance card"

**Why it's exploitable:**

- Medical documents have limited templates (CDC, NHS, insurance forms)
- Photos of vaccine cards are highly similar (same card design, different handwriting)
- Attacker can obtain templates and pre-compute SHA256 hashes
- Server stores plaintext hashes (no protection)

## Solution: HMAC-SHA256 with Family Member Key

**Fix**: Use HMAC keyed with the Family Member Key (FMK):

```swift
// ✅ SECURE
let contentHMAC = HMAC<SHA256>.authenticationCode(
    for: attachmentData,
    using: fmk  // Family Member Key (secret, known only to authorized users)
).hexString
```

**Why HMAC solves it:**

1. **Prevents rainbow tables**:
   - Attacker doesn't know FMK → can't pre-compute HMACs
   - Each family member has different FMK → same card produces different HMAC

2. **Deduplication still works**:
   - Same photo + same FMK → same HMAC (deterministic)
   - Multiple records for Emma with same photo → same HMAC → deduplicated ✅

3. **Scoped to family member**:
   - Emma's vaccine card HMAC ≠ Liam's vaccine card HMAC (different FMKs)
   - Already implemented via `UNIQUE(family_member_id, content_hmac)` constraint

4. **CryptoKit native**:
   - `HMAC<SHA256>` is built into CryptoKit
   - No third-party dependencies
   - Hardware-accelerated on modern iOS devices

## Updated Schema

```sql
CREATE TABLE attachments (
    attachment_id UUID PRIMARY KEY,
    family_member_id UUID NOT NULL,

    -- Encrypted binary content
    encrypted_data BYTEA NOT NULL,
    nonce_data BYTEA NOT NULL,
    tag_data BYTEA NOT NULL,

    -- Encrypted metadata
    encrypted_metadata BYTEA NOT NULL,
    nonce_metadata BYTEA NOT NULL,
    tag_metadata BYTEA NOT NULL,

    -- Content-addressed deduplication (HMAC, not plain hash)
    content_hmac TEXT NOT NULL,  -- HMAC-SHA256(attachment, FMK)

    -- Sync metadata
    encrypted_size_bytes INTEGER NOT NULL,
    created_at TIMESTAMPTZ NOT NULL,
    uploaded_by_device_id UUID NOT NULL,

    -- Deduplication constraint (HMAC is scoped to family member via FMK)
    UNIQUE(family_member_id, content_hmac)
);
```

## Updated Implementation

```swift
import CryptoKit

struct AttachmentMetadata: Codable {
    let mimeType: String
    let filename: String
    let originalSizeBytes: Int
}

func encryptAttachment(
    data: Data,
    metadata: AttachmentMetadata,
    fmk: SymmetricKey
) throws -> EncryptedAttachment {
    // Compute HMAC (not plain hash) for deduplication
    let contentHMAC = HMAC<SHA256>.authenticationCode(for: data, using: fmk)
    let hmacString = contentHMAC.compactMap { String(format: "%02x", $0) }.joined()

    // Encrypt binary data
    let nonceData = AES.GCM.Nonce()
    let sealedData = try AES.GCM.seal(data, using: fmk, nonce: nonceData)

    // Encrypt metadata
    let metadataJSON = try JSONEncoder().encode(metadata)
    let nonceMetadata = AES.GCM.Nonce()
    let sealedMetadata = try AES.GCM.seal(metadataJSON, using: fmk, nonce: nonceMetadata)

    return EncryptedAttachment(
        attachmentId: UUID(),
        familyMemberId: /* Emma's ID */,
        contentHMAC: hmacString,  // Keyed HMAC, not plain hash
        encryptedData: sealedData.ciphertext,
        nonceData: nonceData.withUnsafeBytes { Data($0) },
        tagData: sealedData.tag,
        encryptedMetadata: sealedMetadata.ciphertext,
        nonceMetadata: nonceMetadata.withUnsafeBytes { Data($0) },
        tagMetadata: sealedMetadata.tag,
        encryptedSizeBytes: sealedData.ciphertext.count
    )
}

// Deduplication check
func checkForDuplicate(data: Data, familyMemberId: UUID, fmk: SymmetricKey) async -> UUID? {
    // Compute HMAC
    let contentHMAC = HMAC<SHA256>.authenticationCode(for: data, using: fmk)
    let hmacString = contentHMAC.compactMap { String(format: "%02x", $0) }.joined()

    // Query server
    let existing = try await database.query(
        "SELECT attachment_id FROM attachments WHERE family_member_id = $1 AND content_hmac = $2",
        [familyMemberId, hmacString]
    )

    return existing?.attachment_id  // Reuse if exists, nil if new
}
```

## Security Properties

1. **Rainbow table resistance**: ✅
   - Attacker cannot pre-compute HMACs without FMK
   - FMK is secret (stored in Keychain, encrypted with Master Key)

2. **Deduplication still works**: ✅
   - Deterministic within family member (same data + FMK → same HMAC)

3. **Cross-family privacy**: ✅
   - Emma's FMK ≠ Liam's FMK → different HMACs for same photo
   - Server cannot correlate attachments across family members

4. **Server cannot build profiles**: ✅
   - Server sees opaque HMACs, not recognizable hashes
   - Cannot determine "this is a CDC vaccine card"

## Comparison

| Approach | Rainbow Table Vulnerable? | Deduplication Works? | Privacy Level |
|----------|---------------------------|----------------------|---------------|
| **Plain SHA256** | ❌ Yes | ✅ Yes | ⚠️ Low (server can profile) |
| **HMAC-SHA256 (FMK)** | ✅ No | ✅ Yes | ✅ High (opaque to server) |
| **Random per-upload** | ✅ No | ❌ No | ✅ Highest (no dedup) |

**Chosen**: HMAC-SHA256 (best balance of security and efficiency)

## Records Already Secure

Medical records don't have this vulnerability:

```swift
// AES-GCM uses random nonces
let nonce = AES.GCM.Nonce()  // New random nonce per encryption
let sealed = try AES.GCM.seal(record, using: fmk, nonce: nonce)
```

**Result**: Same plaintext → different ciphertext each time ✅

**No deterministic encryption** → no rainbow table vulnerability

---

**Status**: Security fix implemented (2025-12-21)
**Impact**: Prevents known-plaintext attacks on attachment deduplication
