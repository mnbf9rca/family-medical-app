# Key Hierarchy and Derivation

## Status

**Status**: Proposed

## Context

The Family Medical App requires a cryptographic key hierarchy that supports:
- **Phase 1**: Local encryption on a single device
- **Phase 2**: Multi-device synchronization with zero-knowledge server
- **Phase 3**: Multi-user family sharing with granular access control
- **All Phases**: Key rotation and cryptographic access revocation

Per AGENTS.md requirements, we must use CryptoKit exclusively with AES-256-GCM for symmetric encryption and PBKDF2-HMAC-SHA256 (min 100k iterations) or Argon2id for key derivation.

### Research Foundation

This ADR builds on Issue #36 (Research: E2EE sharing patterns), which evaluated multiple sharing models and recommended the **Hybrid Per-Family-Member Key Model** as the best fit for this application.

See: `docs/research/e2ee-sharing-patterns-research.md`

### Key Design Questions

The key hierarchy must answer:

1. **Master Key Derivation**: How to securely derive encryption keys from user password?
2. **Key Hierarchy Structure**: How many tiers of keys, and what does each tier protect?
3. **DEK Granularity**: What is the scope of each Data Encryption Key?
4. **Key Storage**: Where and how to store keys securely on iOS?
5. **Key Rotation**: How to update keys without data loss?

## Decision

We will implement a **three-tier hierarchical key structure** with **per-family-member data encryption keys**:

```
┌─────────────────────────────────────────────────────────────────┐
│ Tier 1: User Authentication & Master Key                       │
│                                                                 │
│ User Password + Salt                                            │
│   ↓ PBKDF2-HMAC-SHA256 (100,000 iterations)                    │
│ User Master Key (256-bit)                                       │
│   → Stored in iOS Keychain (kSecAttrAccessibleWhenUnlocked)    │
│   → Never transmitted to server                                 │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ Tier 2: User Identity (for sharing)                            │
│                                                                 │
│ Curve25519 KeyPair (generated once, not derived from password) │
│   - Private Key: Encrypted with Master Key, stored in Keychain │
│   - Public Key: Shareable, stored on server + Core Data        │
│   → Used for ECDH key agreement when sharing                   │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ Tier 3: Family Member Keys (FMKs)                              │
│                                                                 │
│ Per-Family-Member Symmetric Key (256-bit)                      │
│   - One FMK per family member (patient)                        │
│   - Generated randomly (SymmetricKey.init(size: .bits256))     │
│   - Wrapped using owner's Master Key → stored in Keychain      │
│   - Wrapped using authorized users' public keys (ECDH)         │
│     → stored in Core Data                                       │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ Tier 4: Medical Records                                        │
│                                                                 │
│ Encrypted with AES-256-GCM using Family Member Key             │
│   - Vaccine records, allergies, medications, etc.              │
│   - Encrypted locally before storage                           │
│   - Encrypted blobs synced to server (zero-knowledge)          │
└─────────────────────────────────────────────────────────────────┘
```

### Design Decisions

#### 1. Master Key Derivation: PBKDF2-HMAC-SHA256

**Decision**: Use PBKDF2-HMAC-SHA256 with 100,000 iterations (not Argon2id).

**Rationale**:
- ✅ **CryptoKit Compatibility**: Available via CommonCrypto (no third-party dependencies)
- ✅ **AGENTS.md Compliance**: Meets minimum requirement
- ✅ **KISS Principle**: Simpler than integrating Argon2id library
- ✅ **Widely Audited**: NIST-approved, well-understood
- ⚠️ **GPU Resistance**: Less resistant than Argon2id, but acceptable for hobby app scope
- ⚠️ **Future Enhancement**: Can migrate to Argon2id in Phase 4 if needed

**Implementation**:
```swift
import CommonCrypto

func deriveMasterKey(from password: String, salt: Data) -> SymmetricKey {
    let passwordData = password.data(using: .utf8)!
    var derivedKey = Data(count: 32) // 256 bits

    let status = derivedKey.withUnsafeMutableBytes { derivedKeyBytes in
        salt.withUnsafeBytes { saltBytes in
            CCKeyDerivationPBKDF(
                CCPBKDFAlgorithm(kCCPBKDF2),
                password, passwordData.count,
                saltBytes.baseAddress, salt.count,
                CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                100_000, // iterations
                derivedKeyBytes.baseAddress, derivedKey.count
            )
        }
    }

    guard status == kCCSuccess else {
        fatalError("Key derivation failed")
    }

    return SymmetricKey(data: derivedKey)
}
```

**Salt Generation**:
- Generate unique 32-byte salt per user on account creation
- Store salt in UserDefaults (not sensitive)
- Use same salt for all PBKDF2 operations for that user

#### 2. Key Hierarchy Structure: Three Tiers

**Decision**: Use three tiers (Master Key → User Identity → Family Member Keys → Medical Records).

**Rationale**:
- ✅ **Separation of Concerns**:
  - Tier 1: User authentication (password-derived)
  - Tier 2: User identity for sharing (not password-derived for forward secrecy)
  - Tier 3: Data encryption (random, per-patient granularity)
- ✅ **Independent Rotation**: Can rotate FMKs without changing user identity
- ✅ **Sharing Support**: Curve25519 keypair enables public-key sharing (Issue #36 research)
- ⚠️ **Complexity**: More complex than two-tier, but necessary for sharing model

**Why Not Two Tiers?**
- If we derived Curve25519 keypair from password, changing password would break all sharing relationships
- Separating identity from authentication enables key rotation without re-establishing trust

#### 3. DEK Granularity: Per-Family-Member

**Decision**: One Family Member Key (FMK) per family member (patient), encrypting all their medical records.

**Rationale** (from Issue #36 research):
- ✅ **Natural Access Control**: "Share Emma's records" is a natural user action
- ✅ **Efficiency**: Wrap FMK once per authorized user (not once per record)
- ✅ **Scalability**: 5-10 family members × 2-4 authorized adults = 10-40 wrapped keys
  - vs. per-record: 500 records × 2-4 users = 1,000-2,000 wrapped keys
- ✅ **Revocation**: Re-encrypt ~100-500 records in ~500ms (acceptable on iOS)
- ✅ **Matches Use Case**: Medical records naturally group by patient

**Not Chosen**:
- ❌ **Per-record**: Excessive key management overhead
- ❌ **Per-user**: No granular sharing (all-or-nothing)
- ❌ **Hybrid (per-record + per-field)**: Violates KISS without meaningful security benefit

#### 4. Key Storage Plan

**Decision**: Multi-tiered storage based on key sensitivity.

| Key Type | Storage Location | Protection Level | Synchronizable | Rationale |
|----------|-----------------|------------------|----------------|-----------|
| **User Master Key** | iOS Keychain | `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` | No | Most sensitive, requires device unlock |
| **User Private Key (Curve25519)** | iOS Keychain (encrypted with Master Key) | `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` | No | Protected by Master Key + Keychain |
| **User Public Key** | Core Data + Server | Plaintext (it's public!) | Yes | Enables key exchange |
| **FMK (owner)** | iOS Keychain (wrapped with Master Key) | `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` | No | Owner's copy, most secure |
| **FMK (shared)** | Core Data (wrapped with ECDH-derived key) | N/A (encrypted at rest) | Yes | Shared copies, synced to other users |
| **Encrypted Medical Records** | Core Data | N/A (encrypted with FMK) | Yes | Synced as encrypted blobs |

**Keychain Organization**:
```
com.family-medical-app.master-key.<userID>
com.family-medical-app.identity-private-key.<userID>
com.family-medical-app.fmk.<familyMemberID>
```

**Rationale**:
- ✅ **Master Key Never Syncs**: Device-only prevents cloud extraction
- ✅ **FMKs Wrapped Multiple Ways**: Owner has Keychain copy (secure), shared users have Core Data copy (encrypted with ECDH)
- ✅ **Public Keys on Server**: Enables key exchange without secure channel

#### 5. Key Rotation Strategy

**Decision**: Re-encrypt in place for FMK rotation (access revocation), lazy rotation for Master Key changes.

##### Scenario A: User Changes Password

**Flow**:
1. Derive new Master Key from new password
2. Re-encrypt User Private Key with new Master Key
3. Re-wrap owner's FMKs with new Master Key
4. Update Keychain entries
5. Old Master Key securely zeroed from memory

**Performance**: < 100ms (only re-wrapping keys, not data)

##### Scenario B: Access Revocation (Adult C loses access to Emma)

**Flow**:
1. Generate new FMK_Emma
2. Decrypt all Emma's records with old FMK_Emma
3. Re-encrypt all Emma's records with new FMK_Emma (AES-256-GCM)
4. Re-wrap new FMK_Emma for remaining authorized users (Adult A, Adult B)
5. Delete wrapped FMK for Adult C from Core Data
6. Sync changes to server (new encrypted records + new wrapped keys)

**Performance**:
- 500 records × ~1ms per decrypt+encrypt = ~500ms
- Acceptable for mobile device
- User-initiated action (expected delay)

**Alternative Considered: Key Versioning**
- ❌ Rejected: Old records still encrypted with compromised key
- ❌ Violates cryptographic revocation requirement

##### Scenario C: Periodic Rotation (Preventive)

**Recommendation**: Not required for hobby app scope.

**Rationale**:
- Medical records are static (not high-value real-time communications)
- Rotation cost (re-encryption) outweighs benefit for small dataset
- Can be added in Phase 4 if needed

#### 6. Forward Secrecy Considerations

**Decision**: User identity keypair is NOT rotated (no perfect forward secrecy).

**Rationale**:
- ⚠️ **Trade-off**: If User Private Key is compromised, past shared FMKs can be unwrapped
- ✅ **Acceptable**: Medical records are not time-sensitive communications
- ✅ **KISS**: Rotating identity keys breaks all sharing relationships
- ✅ **Mitigation**: FMK rotation (Scenario B) provides limited forward secrecy

**Future Enhancement**: Could implement key rotation for User Identity in Phase 4.

### Key Derivation Flow Examples

#### Example 1: New User Account Creation

```
1. User enters password: "correct-horse-battery-staple"
2. App generates random salt (32 bytes)
3. Derive Master Key: PBKDF2(password, salt, 100k iterations) → Master Key
4. Generate Curve25519 keypair → Private Key, Public Key
5. Encrypt Private Key with Master Key → Encrypted Private Key
6. Store:
   - Keychain: Master Key, Encrypted Private Key
   - UserDefaults: salt
   - Server: Public Key
```

#### Example 2: Adult A Creates Family Member Profile (Emma)

```
1. User initiates "Add family member: Emma"
2. App generates random FMK_Emma (256-bit SymmetricKey)
3. Retrieve User Master Key from Keychain
4. Wrap FMK_Emma with Master Key → Wrapped FMK_Emma
5. Store:
   - Keychain: Wrapped FMK_Emma (tagged with Emma's ID)
   - Core Data: Emma's profile (name encrypted with FMK_Emma)
```

#### Example 3: Adult A Shares Emma's Records with Adult B

```
1. Adult A initiates sharing with Adult B (email invitation)
2. Adult B's Public Key retrieved from server
3. Adult A unwraps FMK_Emma (from Keychain, using Master Key)
4. Perform ECDH:
   - Shared Secret = KeyAgreement(Adult A Private Key, Adult B Public Key)
   - Wrapping Key = HKDF(Shared Secret, context: "fmk_emma_<ID>")
5. Wrap FMK_Emma with Wrapping Key → Wrapped FMK_Emma (for Adult B)
6. Store:
   - Core Data: Wrapped FMK_Emma (Adult B's copy)
   - Sync to server (Adult B downloads it)
7. Adult B unwraps using their Private Key + Adult A's Public Key
```

## Consequences

### Positive

1. **Supports All Phases**: Key hierarchy designed from the start for local, sync, and sharing
2. **CryptoKit Compliance**: Uses only CryptoKit + CommonCrypto (no third-party dependencies)
3. **Efficient Sharing**: Per-family-member granularity minimizes key management overhead
4. **Cryptographic Revocation**: Re-encryption provides true access removal (not just UI hiding)
5. **Natural UX**: "Share Emma's records" aligns with user mental model
6. **Scalable**: 5-10 family members × 2-4 users = manageable key count
7. **Auditable**: Clear key hierarchy, standard algorithms (PBKDF2, X25519, AES-GCM)

### Negative

1. **Complexity**: Three-tier hierarchy is more complex than single-tier
   - **Mitigation**: Necessary for sharing requirements, well-documented
2. **Revocation Cost**: Re-encrypting 500 records takes ~500ms
   - **Mitigation**: Acceptable for user-initiated action, < 1000 records per family member
3. **PBKDF2 GPU Weakness**: Less resistant to GPU attacks than Argon2id
   - **Mitigation**: 100k iterations is industry standard, acceptable for hobby app
   - **Future**: Can migrate to Argon2id in Phase 4
4. **No Perfect Forward Secrecy**: User identity keypair is long-lived
   - **Mitigation**: Medical records are static data (different threat model than messaging)
   - **Mitigation**: FMK rotation provides limited forward secrecy per family member
5. **Master Key in Keychain**: If device is unlocked and compromised, Master Key is accessible
   - **Mitigation**: iOS Keychain is hardware-backed (Secure Enclave on modern devices)
   - **Mitigation**: User can enable biometric protection for additional security (Phase 4)

### Neutral

1. **Key Storage Split**: Some keys in Keychain, some in Core Data
   - **Note**: This is intentional (security vs. syncability trade-off)
2. **Salt in UserDefaults**: Salts are not secret, but storing them separately from keys
   - **Note**: Standard practice, simplifies key derivation flow
3. **Public Keys on Server**: Server knows who is using the app
   - **Note**: Acceptable for zero-knowledge architecture (server can't decrypt data)

### Trade-offs Accepted

| Decision | Trade-off | Justification |
|----------|-----------|---------------|
| **PBKDF2 vs Argon2id** | Weaker GPU resistance | Simpler, CryptoKit-compatible, meets AGENTS.md requirement |
| **Per-family-member FMKs** | Revocation requires re-encryption | Natural granularity, acceptable performance |
| **Long-lived identity keys** | No perfect forward secrecy | Medical records are static, not time-sensitive |
| **Three-tier hierarchy** | Added complexity | Necessary for sharing without breaking relationships |

## Implementation Notes

### Phase 1: Local Encryption (Foundation)

Implement:
- User Master Key derivation (PBKDF2)
- Curve25519 keypair generation
- FMK generation and wrapping (owner only)
- Keychain storage for all keys
- Medical record encryption with FMK

**NOT needed in Phase 1**: ECDH key wrapping (no sharing yet)

### Phase 2: Multi-Device Sync

Add:
- Sync encrypted medical records (already encrypted with FMK)
- Sync user's Public Key to server
- Sync user's wrapped FMKs (Core Data)

**Challenge**: How to get Master Key on new device? → See ADR-0004 (Sync Encryption)

### Phase 3: Family Sharing

Add:
- ECDH key agreement for FMK wrapping
- Public key exchange (email + TOFU)
- Multiple wrapped FMKs per family member (Core Data)
- Access management UI

**Full implementation** of key hierarchy used here.

### Phase 4: Access Revocation

Add:
- FMK rotation (re-encryption) implementation
- Audit trail for revocation events
- Optional: User identity key rotation
- Optional: Argon2id migration
- Optional: Biometric protection for Master Key

## Related Decisions

- **ADR-0001**: Crypto Architecture First (establishes need for this design)
- **ADR-0003**: Sharing Model (uses this key hierarchy for ECDH wrapping)
- **ADR-0004**: Sync Encryption (uses FMKs for blob encryption)
- **ADR-0005**: Access Revocation (uses FMK rotation strategy)

## References

- Issue #36: Research E2EE Sharing Patterns
- `docs/research/e2ee-sharing-patterns-research.md`
- `docs/research/poc-hybrid-family-keys.swift`
- AGENTS.md: Cryptography specifications
- [NIST SP 800-132](https://csrc.nist.gov/publications/detail/sp/800-132/final): Password-Based Key Derivation
- [RFC 7748](https://datatracker.ietf.org/doc/html/rfc7748): Elliptic Curves for Security (X25519)
- [NIST SP 800-38F](https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-38F.pdf): AES Key Wrapping

---

**Decision Date**: 2025-12-19
**Author**: Claude Code (based on Issue #36 research)
**Reviewers**: [To be assigned]
