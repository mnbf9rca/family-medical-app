# Multi-User Sharing Model

## Status

**Status**: Proposed

## Context

The Family Medical App must support granular sharing of medical records among family members while maintaining End-to-End Encryption (E2EE). Per AGENTS.md requirements and Issue #35 (Phase 0 - Cryptographic Architecture Design), we need to specify how multiple authorized adults can securely access encrypted medical records.

### Foundation

This ADR builds on:
- **Issue #36**: Research E2EE Sharing Patterns → Recommended Hybrid Per-Family-Member model
- **ADR-0002**: Key Hierarchy → Established 3-tier structure with Curve25519 identity keys and per-family-member FMKs

See: `docs/research/e2ee-sharing-patterns-research.md` (especially Section 10: Public Key Exchange UX)

### Requirements

1. **Zero-Knowledge Server**: Server cannot decrypt medical records
2. **Granular Access Control**: Share specific family member's records (e.g., "Emma's records" not "all records")
3. **Insecure Channel Support**: Must work over email invitations (cannot assume iCloud Family Sharing)
4. **Offline-First**: Sharing should work without real-time server communication
5. **CryptoKit Only**: Use exclusively CryptoKit primitives (per AGENTS.md)
6. **KISS Principle**: Minimize UX friction to encourage adoption
7. **Revocation Support**: Ability to cryptographically revoke access (see ADR-0005)

### Key Design Questions

1. **Key Exchange Mechanism**: How do users securely share public keys over insecure channels?
2. **Trust Model**: TOFU (Trust On First Use) vs. mandatory out-of-band verification?
3. **Sharing Granularity**: Per-record, per-family-member, or per-user?
4. **Invitation Flow**: Email, QR code, or both?
5. **Verification UX**: Required or optional?

## Decision

We will implement a **Hybrid Per-Family-Member Sharing Model** with **TOFU (Trust On First Use)** for public key exchange.

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│ Sharing Flow: Adult A shares Emma's records with Adult B       │
└─────────────────────────────────────────────────────────────────┘

Step 1: Key Exchange (TOFU)
──────────────────────────────
Adult A                          Server (zero-knowledge)              Adult B
   │                                      │                              │
   │  1. Initiates sharing invitation    │                              │
   │  "Share Emma's records with Adult B"│                              │
   │                                      │                              │
   │  2. Send email invite ───────────────────────────────────────────> │
   │     (contains: Adult A's Public Key) │                              │
   │                                      │                              │
   │                               3. Adult B accepts invitation         │
   │                                      │  - Generates Curve25519 keypair
   │                                      │  - Uploads Public Key B     │
   │                                      │                              │
   │ <────── 4. Retrieve Public Key B ────┤                              │
   │     (from server, insecure OK)       │                              │
   │                                      │                              │

Step 2: Family Member Key Wrapping
──────────────────────────────────
Adult A's Device:
   │
   │  5. Unwrap FMK_Emma (from Keychain, using Master Key)
   │  6. Perform ECDH Key Agreement:
   │     - Shared Secret = ECDH(Private Key A, Public Key B)
   │     - Wrapping Key = HKDF(Shared Secret, context: "FMK-Emma-<UUID>")
   │  7. Wrap FMK_Emma with Wrapping Key
   │     - Wrapped_FMK_Emma = AES.KeyWrap(FMK_Emma, Wrapping Key)
   │  8. Upload to server:
   │     - Access record: (Adult B's User ID, Wrapped_FMK_Emma, Emma's ID)
   │     - Adult A's Public Key (if not already uploaded)
   │

Step 3: Adult B Accesses Emma's Records
───────────────────────────────────────
Adult B's Device:
   │
   │  9. Download from server:
   │     - Wrapped_FMK_Emma (for Adult B)
   │     - Adult A's Public Key
   │     - Emma's encrypted medical records
   │ 10. Perform ECDH (same result as Step 6):
   │     - Shared Secret = ECDH(Private Key B, Public Key A)
   │     - Wrapping Key = HKDF(Shared Secret, context: "FMK-Emma-<UUID>")
   │ 11. Unwrap FMK_Emma:
   │     - FMK_Emma = AES.KeyUnwrap(Wrapped_FMK_Emma, Wrapping Key)
   │ 12. Decrypt medical records:
   │     - Record = AES-GCM Decrypt(Encrypted Record, FMK_Emma)
   │

Optional: Verification (Post-TOFU)
─────────────────────────────────
Both devices compute verification code:
   - Verification Code = SHA256(Shared Secret).prefix(3)
   - Format: "A3-5F-2B" (6 hex digits)
   - Users can compare codes via phone/text (out-of-band)
   - If mismatch detected → MITM warning → re-key
```

### Design Decisions

#### 1. TOFU (Trust On First Use) for Key Exchange

**Decision**: Use TOFU by default, with optional verification codes for paranoid users.

**Flow**:
1. Public keys exchanged automatically via server (no user verification required)
2. Sharing works immediately upon invitation acceptance
3. Verification codes displayed in Settings for optional out-of-band confirmation
4. Users can verify later if concerned about MITM attacks

**Rationale**:
- ✅ **Simplest UX**: No friction for initial sharing (critical for adoption)
- ✅ **Real-World Families**: Works for geographically distant family members, estranged members, custody arrangements
- ✅ **Threat Model Fit**: Medical records are static data (not real-time messaging where MITM enables active surveillance)
- ✅ **Optional Security Upgrade**: Power users can verify codes later
- ⚠️ **MITM Risk**: Vulnerable to server-side MITM on first key exchange
  - **Mitigation**: Later verification catches attacks and allows re-keying
  - **Acceptable Trade-off**: Convenience over perfect forward secrecy for hobby app scope

**Alternatives Considered**:
- ❌ **Mandatory Verification**: Too much friction, reduces adoption
- ❌ **QR Code Only**: Requires in-person meeting (not always feasible for families)
- ⚠️ **Future Enhancement**: Add QR code option for in-person sharing in Phase 3

#### 2. Per-Family-Member Sharing Granularity

**Decision**: Share access at the family member (patient) level, not per-record or all-or-nothing.

**Implementation**:
- One Family Member Key (FMK) per patient (Emma, Liam, etc.)
- All of Emma's records encrypted with FMK_Emma
- When sharing "Emma's records", Adult A wraps FMK_Emma for Adult B
- Adult B can decrypt all of Emma's records (but not Liam's unless also shared)

**Rationale** (from ADR-0002 and Issue #36):
- ✅ **Natural User Mental Model**: "Share Emma's records with Grandma"
- ✅ **Efficient**: Wrap FMK once per relationship (not per record)
  - 5 family members × 3 authorized adults = 15 wrapped keys
  - vs. per-record: 500 records × 3 adults = 1,500 wrapped keys
- ✅ **Scalable**: Adding new records doesn't require wrapping new keys
- ✅ **Revocation**: Re-encrypt ~100-500 records per family member (~500ms)

**Not Chosen**:
- ❌ **Per-Record Sharing**: Excessive overhead, unnatural UX ("Share this one vaccine record?")
- ❌ **All-or-Nothing**: No granularity ("Share all family medical records?")

#### 3. Email Invitation Flow

**Decision**: Primary sharing mechanism is email invitation with embedded public key.

**Email Template**:
```
Subject: [Family Medical App] Adult A wants to share Emma's records

Adult A has invited you to access Emma's medical records.

1. Install the Family Medical App: [App Store Link]
2. Create an account or sign in
3. Accept this invitation: [Deep Link to App]

Security note: This app uses end-to-end encryption. After accepting,
you can optionally verify the secure connection with Adult A by
comparing verification codes in Settings > Shared Access.

[Accept Invitation Button]
```

**Deep Link Format**: `familymedicalapp://accept-share?inviteToken=<JWT>`

**JWT Payload** (signed by server, but server doesn't see private data):
```json
{
  "inviterUserId": "uuid-adult-a",
  "inviterPublicKey": "base64-encoded-curve25519-public-key",
  "familyMemberId": "uuid-emma",
  "expiresAt": 1735948800
}
```

**Rationale**:
- ✅ **Familiar UX**: Email invitations are well-understood
- ✅ **Async**: Doesn't require both users online simultaneously
- ✅ **Insecure Channel**: Email is insecure, but public keys can be transmitted safely
- ✅ **Expiration**: 7-day expiration prevents stale invitations

#### 4. Verification Code Format

**Decision**: 6-digit hex code (3 bytes of SHA256 hash), formatted with dashes.

**Implementation**:
```swift
func generateVerificationCode(sharedSecret: SharedSecret) -> String {
    let hash = SHA256.hash(data: sharedSecret.rawRepresentation)
    let codeBytes = hash.prefix(3) // 3 bytes = 6 hex digits
    return codeBytes.map { String(format: "%02X", $0) }
                    .joined(separator: "-")
    // Example: "A3-5F-2B"
}
```

**Display in App**:
```
Settings > Shared Access > Adult B
─────────────────────────────────
Access to Emma's records
Security Code: A3-5F-2B

ⓘ To verify this connection is secure, ask Adult B to
  read their security code aloud. If they say "A3-5F-2B",
  the connection is verified. If different, report this
  immediately (potential security issue).

[Report Security Issue Button]
```

**Rationale**:
- ✅ **Easy to Verify**: 6 digits readable over phone call
- ✅ **Sufficient Entropy**: 3 bytes = 16,777,216 combinations (MITM has 1/16M chance)
- ✅ **Familiar Pattern**: Similar to Signal, WhatsApp safety numbers
- ⚠️ **Not Required**: Optional verification reduces friction

#### 5. Access Record Storage

**Decision**: Store wrapped FMKs in Core Data with metadata for sync and access management.

**Schema** (simplified):
```swift
entity FamilyMemberAccessGrant {
    grantId: UUID                      // Primary key
    familyMemberId: UUID               // Which patient (Emma, Liam, etc.)
    grantedToUserId: UUID              // Who has access (Adult B, Adult C, etc.)
    wrappedFMK: Data                   // AES.KeyWrap(FMK, ECDH-derived key)
    granterPublicKey: Data             // Adult A's public key (for ECDH)
    createdAt: Date
    revokedAt: Date?                   // Null if active, set on revocation
}
```

**Sync Behavior**:
- All `FamilyMemberAccessGrant` records synced to server (encrypted blobs)
- Server knows: who has access to which family member (metadata)
- Server doesn't know: actual FMK values (wrapped with ECDH-derived keys)

**Rationale**:
- ✅ **Queryable**: Can list "Who has access to Emma's records?"
- ✅ **Syncable**: Zero-knowledge sync (server can't decrypt wrapped FMKs)
- ✅ **Revocable**: Set `revokedAt` to soft-delete, then re-encrypt in background

### CryptoKit Implementation Details

#### Key Agreement (ECDH)
```swift
import CryptoKit

// Adult A's side (sharing)
let privateKeyA = Curve25519.KeyAgreement.PrivateKey() // from Keychain
let publicKeyB = Curve25519.KeyAgreement.PublicKey(rawRepresentation: adultBPublicKeyData)

let sharedSecret = try privateKeyA.sharedSecretFromKeyAgreement(with: publicKeyB)

// Derive wrapping key
let wrappingKey = sharedSecret.hkdfDerivedSymmetricKey(
    using: SHA256.self,
    salt: Data(), // Empty salt (shared secret already has entropy)
    sharedInfo: "FMK-Emma-\(emmaId.uuidString)".data(using: .utf8)!,
    outputByteCount: 32 // 256 bits for AES-256
)

// Wrap FMK
let wrappedFMK = try AES.KeyWrap.wrap(fmkEmma, using: wrappingKey)
```

#### Key Unwrapping (Adult B's side)
```swift
// Adult B's side (receiving)
let privateKeyB = Curve25519.KeyAgreement.PrivateKey() // from Keychain
let publicKeyA = Curve25519.KeyAgreement.PublicKey(rawRepresentation: adultAPublicKeyData)

// Same ECDH operation yields same shared secret
let sharedSecret = try privateKeyB.sharedSecretFromKeyAgreement(with: publicKeyA)

// Same HKDF derivation
let wrappingKey = sharedSecret.hkdfDerivedSymmetricKey(
    using: SHA256.self,
    salt: Data(),
    sharedInfo: "FMK-Emma-\(emmaId.uuidString)".data(using: .utf8)!,
    outputByteCount: 32
)

// Unwrap FMK
let fmkEmma = try AES.KeyWrap.unwrap(wrappedFMK, using: wrappingKey)
```

**Security Properties**:
- ✅ **Perfect Forward Secrecy (per relationship)**: Each FMK wrapping uses unique ECDH shared secret
- ✅ **Context Binding**: HKDF `sharedInfo` includes family member ID (prevents key reuse across patients)
- ✅ **Standard Primitives**: X25519 (Curve25519 ECDH) + HKDF-SHA256 + AES-KeyWrap (all CryptoKit native)

## Consequences

### Positive

1. **Simple UX**: TOFU enables one-click sharing without verification friction
2. **Real-World Family Support**: Works for geographically distant, estranged, or complex family situations
3. **Zero-Knowledge Maintained**: Server cannot decrypt FMKs (wrapped with ECDH-derived keys unknown to server)
4. **Granular Access Control**: Per-family-member sharing matches natural user mental model
5. **Efficient Key Management**: Wrap FMK once per relationship (not per record)
   - 5 patients × 3 adults = 15 wrapped keys (vs. 1,500 for per-record model)
6. **Cryptographically Sound**: Uses industry-standard primitives (X25519, HKDF, AES-KeyWrap)
7. **Optional Security Upgrade**: Power users can verify codes post-TOFU
8. **Offline-First**: Key wrapping happens locally (no server round-trip for crypto operations)
9. **Scalable**: Adding records doesn't require wrapping new keys
10. **Revocable**: See ADR-0005 for re-encryption strategy

### Negative

1. **MITM Vulnerability (TOFU)**: Server could perform MITM attack on initial key exchange
   - **Severity**: Medium (requires malicious/compromised server + targeted attack)
   - **Mitigation**: Optional verification codes + warning if codes don't match
   - **Accepted Trade-off**: UX simplicity over perfect security for hobby app scope
   - **Rationale**: Medical records are static data (different threat model than real-time messaging)

2. **No Verification Enforcement**: Users may skip verification step
   - **Mitigation**: Clear UI guidance, "Security Code" prominently displayed in Settings
   - **Accepted Trade-off**: Cannot force users to verify without harming UX

3. **Revocation Requires Re-encryption**: See ADR-0005
   - **Impact**: ~500ms to revoke access for 500 records
   - **Acceptable**: User-initiated action, infrequent operation

4. **Public Keys on Server**: Server knows user relationships (who shares with whom)
   - **Impact**: Metadata leakage (not content)
   - **Acceptable**: Zero-knowledge applies to medical data, not social graph
   - **Note**: Common in E2EE systems (Signal, WhatsApp, etc.)

5. **Email Dependency**: Sharing requires email (not just in-app)
   - **Mitigation**: Future enhancement could add QR code for in-person sharing
   - **Acceptable**: Email is universally available

### Neutral

1. **Trust Establishment**: Relies on out-of-band verification (phone call, text) for paranoid users
   - **Note**: Same model as Signal, WhatsApp (industry standard)

2. **Key Longevity**: User identity keys are long-lived (no automatic rotation)
   - **Note**: Matches ADR-0002 decision (no perfect forward secrecy by default)
   - **Future Enhancement**: Manual key rotation in Phase 4

3. **Server Knows Social Graph**: Server can see `(User A → User B, family member X)` relationships
   - **Note**: Metadata, not content; acceptable for zero-knowledge architecture

### Trade-offs Accepted

| Decision | Trade-off | Justification |
|----------|-----------|---------------|
| **TOFU vs. Mandatory Verification** | MITM risk on first share | UX critical for adoption; medical records are static data |
| **Email Invitations** | Requires email address | Universal, familiar, async; can add QR later |
| **Per-Family-Member Granularity** | Revocation requires re-encryption | Natural UX, efficient key management, acceptable performance |
| **Optional Verification** | Users may skip | Cannot enforce without UX penalty; clear guidance provided |
| **Public Keys on Server** | Metadata leakage (social graph) | Standard for E2EE systems; zero-knowledge applies to content |

## Implementation Notes

### Phase 1: Local Encryption
- **Not needed**: Sharing is Phase 3 feature
- **Preparation**: User Curve25519 keypair generation (ADR-0002 Tier 2)

### Phase 2: Multi-Device Sync
- **Partial implementation**: Sync public keys to server
- **Not needed**: ECDH wrapping (no sharing yet)

### Phase 3: Family Sharing (FULL IMPLEMENTATION)
1. **Email Invitation System**:
   - Server-side: JWT signing, email delivery
   - Client-side: Deep link handling, invitation acceptance UI
2. **ECDH Key Wrapping**:
   - Implement `shareAccess(familyMember:, withUser:)` method
   - HKDF context binding with family member ID
3. **Access Grant Management**:
   - Core Data entity: `FamilyMemberAccessGrant`
   - Sync access grants to server
4. **Verification Code UI**:
   - Settings > Shared Access screen
   - Verification code display and comparison instructions
5. **Security Warning System**:
   - Detect code mismatch (indicates MITM)
   - Re-keying flow for compromised relationships

### Phase 4: Enhancements
- **QR Code Sharing**: For in-person sharing (most secure)
- **Mandatory Verification Mode**: Enterprise/paranoid users setting
- **Key Rotation**: User identity key rotation with re-wrapping
- **Audit Trail**: Log all sharing events (encrypted)

## Related Decisions

- **ADR-0001**: Crypto Architecture First (establishes E2EE requirement)
- **ADR-0002**: Key Hierarchy (defines Curve25519 identity keys and FMKs)
- **ADR-0004**: Sync Encryption (uses same FMKs for blob encryption)
- **ADR-0005**: Access Revocation (uses FMK rotation to cryptographically revoke)

## References

- Issue #36: Research E2EE Sharing Patterns
- `docs/research/e2ee-sharing-patterns-research.md` (Section 10: Public Key Exchange UX)
- `docs/research/poc-public-key-sharing.swift`
- `docs/research/poc-hybrid-family-keys.swift`
- AGENTS.md: Cryptography specifications
- [RFC 7748](https://datatracker.ietf.org/doc/html/rfc7748): Elliptic Curves for Security (X25519)
- [NIST SP 800-56A](https://csrc.nist.gov/publications/detail/sp/800-56a/rev-3/final): Key Agreement Using Discrete Logarithm Cryptography
- [NIST SP 800-108](https://csrc.nist.gov/publications/detail/sp/800-108/rev-1/final): Key Derivation Using Pseudorandom Functions (HKDF)
- [Signal Protocol: Key Agreement](https://signal.org/docs/specifications/x3dh/)
- [1Password Security Design: Shared Vaults](https://agilebits.github.io/security-design/sharedVaults.html)

---

**Decision Date**: 2025-12-19
**Author**: Claude Code (based on Issue #36 research and ADR-0002)
**Reviewers**: [To be assigned]
