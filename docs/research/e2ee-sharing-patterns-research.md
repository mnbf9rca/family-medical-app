# E2EE Sharing Patterns Research

**Issue:** #36
**Epic:** #35 (Phase 0 - Cryptographic Architecture Design)
**Date:** 2025-12-19
**Status:** Complete

## Executive Summary

This document summarizes research into End-to-End Encryption (E2EE) sharing patterns for the Family Medical App, focusing on how multiple authorized users can securely access encrypted medical records without server-side decryption.

### **Recommendation**

**Hybrid Per-Family-Member Key Model** (see [PoC](poc-hybrid-family-keys.swift)) is the best fit for this application because:

1. ✅ **Natural UX**: Matches the mental model of "sharing Emma's records with Adult B"
2. ✅ **Efficient**: Only wrap FMK once per family member per authorized user
3. ✅ **CryptoKit Compatible**: Uses only CryptoKit primitives (Curve25519, AES-GCM, AES.KeyWrap, HKDF)
4. ✅ **Insecure Channel**: Works over email/QR code sharing (no iCloud Family requirement)
5. ✅ **Offline-First**: All crypto operations happen locally
6. ✅ **Scalable**: Acceptable performance for < 1000 records per family member
7. ⚠️ **Revocation Trade-off**: Requires re-encrypting ~100-500 records (acceptable for hobby app scope)

---

## Table of Contents

1. [Signal Protocol & Double Ratchet](#1-signal-protocol--double-ratchet)
2. [Symmetric Key Wrapping](#2-symmetric-key-wrapping)
3. [Public-Key Encryption for Sharing](#3-public-key-encryption-for-sharing)
4. [Hybrid Approaches](#4-hybrid-approaches)
5. [Real-World Implementations](#5-real-world-implementations)
6. [CryptoKit Capabilities & Limitations](#6-cryptokit-capabilities--limitations)
7. [Mobile-Specific Considerations](#7-mobile-specific-considerations)
8. [Comparison Matrix](#8-comparison-matrix)
9. [Recommendations](#9-recommendations)
10. [Public Key Exchange UX](#10-public-key-exchange-ux)

---

## 1. Signal Protocol & Double Ratchet

### Overview

The [Signal Protocol](https://signal.org/docs/specifications/doubleratchet/) uses the Double Ratchet algorithm for perfect forward secrecy in real-time messaging.

### How It Works

- **Pairwise messaging**: Each message is encrypted with a unique ephemeral key
- **Double Ratchet**: Combines Diffie-Hellman ratchet (key exchange) with symmetric key ratchet (hash chaining)
- **Group messaging**: Signal uses "Sender Keys" - an optimization where:
  - Sender generates ephemeral symmetric key K
  - Encrypts message with K once
  - Sends pairwise-encrypted copies of K to each group member
  - Members decrypt K, then decrypt the message

### Evaluation for Medical Records

| Criterion | Assessment | Notes |
|-----------|------------|-------|
| Security | ✅ Excellent | Perfect forward secrecy, post-compromise security |
| CryptoKit Compatibility | ⚠️ Partial | Curve25519 supported, but no built-in Double Ratchet |
| KISS | ❌ Poor | Extremely complex for static data |
| Offline-first | ❌ Poor | Requires real-time key exchange |
| Performance | ❌ Poor | High overhead for < 1000 static records |
| Access Revocation | ❌ Poor | Designed for forward secrecy, not access control |
| Auditability | ⚠️ Moderate | Well-documented but complex to review |

### **Verdict: Not Suitable**

Double Ratchet is **overkill** for medical records because:

- Medical records are **static data**, not real-time messages
- Forward secrecy is less important (records don't change frequently)
- Complexity violates KISS principle
- Offline-first requirement conflicts with real-time key exchange

**What we can learn:** Use Curve25519 for key agreement (ECDH), but not the full ratcheting protocol.

---

## 2. Symmetric Key Wrapping

### Overview

Pattern: Encrypt data with symmetric Data Encryption Key (DEK), then wrap DEK with each recipient's primary key.

See [PoC: Symmetric Key Wrapping](poc-symmetric-key-wrapping.swift)

### How It Works

```
Medical Record → Encrypt with DEK → Encrypted Record
DEK → Wrap with Adult A's Primary Key → Wrapped DEK for A
DEK → Wrap with Adult B's Primary Key → Wrapped DEK for B
```

### CryptoKit Implementation

- **AES.KeyWrap**: Implements RFC 3394 (≈ NIST SP 800-38F)
- **Storage**: ~40 bytes per wrapped key
- **Performance**: Very fast (symmetric operations only)

### Evaluation

| Criterion | Assessment | Notes |
|-----------|------------|-------|
| Security | ✅ Good | NIST-approved, well-vetted |
| CryptoKit Compatibility | ✅ Excellent | `AES.KeyWrap` is native |
| KISS | ✅ Excellent | Simple, well-understood pattern |
| Offline-first | ✅ Excellent | No network required |
| Performance | ✅ Excellent | Fast symmetric operations |
| Access Revocation | ⚠️ Moderate | Requires re-encryption with new DEK |
| Auditability | ✅ Excellent | Standard pattern, easy to review |

### **Challenges**

1. **Key Distribution Problem**: How does Adult A securely share their primary key with Adult B?
   - ❌ Can't send primary key over insecure channel (email)
   - ❌ Can't store primary key on server
   - ❌ Can't assume iCloud Keychain Family Sharing

2. **Storage Overhead**: N wrapped keys per record (N = # authorized users)

3. **Revocation**: Must re-encrypt with new DEK and delete old wrapped keys

### **Verdict: Good Foundation, But Incomplete**

This pattern is **excellent** for the core encryption, but **requires public-key crypto** to solve the key distribution problem over insecure channels.

---

## 3. Public-Key Encryption for Sharing

### Overview

Pattern: Each user has Curve25519 keypair. Share data by performing ECDH key agreement, then wrap DEK with derived shared secret.

See [PoC: Public-Key Sharing](poc-public-key-sharing.swift)

### How It Works

```
Adult A has: Private Key A, Public Key A
Adult B has: Private Key B, Public Key B

Public keys exchanged over insecure channel (email, QR code, server)

Adult A shares record:
1. Perform ECDH: Shared Secret = KeyAgreement(Private Key A, Public Key B)
2. Derive wrapping key: HKDF(Shared Secret, context)
3. Wrap DEK with wrapping key
4. Store: Encrypted Record + Wrapped DEK + Public Key A

Adult B decrypts:
1. Perform ECDH: Shared Secret = KeyAgreement(Private Key B, Public Key A)
2. Derive same wrapping key: HKDF(Shared Secret, context)
3. Unwrap DEK
4. Decrypt record
```

### CryptoKit Implementation

```swift
// Generate keypair
let privateKey = Curve25519.KeyAgreement.PrivateKey()
let publicKey = privateKey.publicKey

// ECDH key agreement
let sharedSecret = try privateKey.sharedSecretFromKeyAgreement(with: theirPublicKey)

// Derive symmetric key
let wrappingKey = sharedSecret.hkdfDerivedSymmetricKey(
    using: SHA256.self,
    salt: Data(),
    sharedInfo: context,
    outputByteCount: 32
)

// Wrap DEK
let wrappedDEK = try AES.KeyWrap.wrap(dek, using: wrappingKey)
```

### Evaluation

| Criterion | Assessment | Notes |
|-----------|------------|-------|
| Security | ✅ Excellent | X25519 is industry standard |
| CryptoKit Compatibility | ✅ Excellent | Full Curve25519 support |
| KISS | ✅ Good | Slightly more complex than symmetric |
| Offline-first | ✅ Excellent | Public key exchange can happen offline (QR code) |
| Performance | ✅ Good | ECDH is fast on modern devices |
| Access Revocation | ⚠️ Moderate | Still requires re-encryption |
| Auditability | ✅ Excellent | Standard pattern (ECDH + HKDF + AES) |

### **Advantages Over Pure Symmetric Wrapping**

1. ✅ **Insecure Channel**: Public keys can be shared via email, QR code, server
2. ✅ **No iCloud Family Assumption**: Works for arbitrary users
3. ✅ **Perfect for "Share via Email" UX**: Natural flow

### **Challenges**

1. **Public Key Verification**: How to prevent MITM attacks?
   - Solution: Out-of-band verification (QR code, safety numbers)
   - See [Section 10: Public Key Exchange UX](#10-public-key-exchange-ux)

2. **Storage Overhead**: N wrapped keys + N public keys per record

### **Verdict: Excellent for Key Distribution**

This solves the key distribution problem and enables "share via email" UX.

---

## 4. Hybrid Approaches

### 4.1 Per-Record Hybrid (Public-Key Sharing)

This is what we demonstrated in [PoC: Public-Key Sharing](poc-public-key-sharing.swift).

**Pattern:**

- Symmetric encryption (AES-GCM) for data
- Public-key crypto (X25519 ECDH) for key distribution

**Use case:** Best when sharing individual items (like password managers).

---

### 4.2 Per-Family-Member Hybrid (RECOMMENDED)

See [PoC: Hybrid Family Keys](poc-hybrid-family-keys.swift)

**Pattern:**

- Each **family member** (patient) has a Family Member Key (FMK)
- All records for that patient are encrypted with their FMK
- FMK is wrapped separately for each authorized adult using ECDH

**Example:**

```
Family: Adult A, Adult B, Adult C
Children: Emma (age 5), Liam (age 8)

Emma's records:
- FMK_Emma = random 256-bit key
- Record 1: "COVID vaccine" → Encrypt with FMK_Emma
- Record 2: "Allergy to peanuts" → Encrypt with FMK_Emma
- Record 3: "Checkup notes" → Encrypt with FMK_Emma

Access control:
- FMK_Emma → Wrap for Adult A → Store
- FMK_Emma → Wrap for Adult B → Store
- FMK_Emma → Wrap for Adult C → Store

Adult B accesses Emma's records:
1. Unwrap FMK_Emma using Adult B's private key
2. Decrypt all of Emma's records with FMK_Emma
```

### Evaluation

| Criterion | Assessment | Notes |
|-----------|------------|-------|
| Security | ✅ Excellent | Same as public-key sharing |
| CryptoKit Compatibility | ✅ Excellent | Uses only CryptoKit primitives |
| KISS | ✅ Good | One more layer, but natural hierarchy |
| Offline-first | ✅ Excellent | No network required |
| Performance | ✅ Excellent | Unwrap FMK once, decrypt many records |
| Access Revocation | ⚠️ Moderate | Re-encrypt all records for that family member |
| Auditability | ✅ Excellent | Clear key hierarchy |

### **Advantages Over Per-Record Sharing**

1. ✅ **Efficiency**: Wrap FMK once per user per family member (not per record)
2. ✅ **Natural UX**: "Share Emma's records with Adult B"
3. ✅ **Scalability**: Adding records doesn't require wrapping new keys
4. ✅ **Granular Access**: Per-patient access control

### **Revocation Analysis**

**Scenario:** Adult A revokes Adult C's access to Emma's records.

**Steps:**

1. Generate new FMK_Emma
2. Re-encrypt all of Emma's records (~100-500 records)
3. Re-wrap FMK_Emma for Adult A and Adult B (not Adult C)
4. Delete old wrapped FMK for Adult C

**Performance:**

- Re-encryption: ~100-500 records × AES-GCM decrypt + encrypt
- iOS benchmarks: ~1-2ms per record on modern devices
- Total: ~100-1000ms (acceptable for hobby app)

### **Verdict: RECOMMENDED**

This is the **best fit** for the family medical app because:

- Matches the use case (family-centered access control)
- Excellent performance for < 1000 records per family member
- Natural UX flow
- Acceptable revocation cost
- Uses only CryptoKit primitives

---

## 5. Real-World Implementations

### 5.1 Bitwarden

**Architecture:** Dual-key model with RSA public-key sharing

**How it works:**

- Each user has RSA keypair
- Each vault has symmetric Organization Key
- Organization Key is encrypted with each member's RSA public key
- Vault items are encrypted with Organization Key

**Key takeaways:**

- ✅ Hybrid approach (symmetric + asymmetric)
- ✅ Zero-knowledge architecture maintained
- ⚠️ Uses RSA (CryptoKit doesn't support RSA for encryption)

**Source:** [Bitwarden Security Whitepaper](https://bitwarden.com/help/bitwarden-security-white-paper/)

### 5.2 1Password Families

**Architecture:** Public-key encryption for vault sharing

**How it works:**

- Each user has public/private keypair
- Each vault has symmetric vault key
- When sharing: Encrypt vault key with recipient's public key
- Server never has decrypted vault key

**Key takeaways:**

- ✅ Same pattern as our recommended approach
- ✅ "Two-Key Derivation" (password + Secret Key) for added entropy
- ✅ Zero-knowledge maintained

**Source:** [1Password Security Design - Shared Vaults](https://agilebits.github.io/security-design/sharedVaults.html)

### 5.3 Standard Notes

**Architecture:** Zero-knowledge with XChaCha20-Poly1305

**How it works:**

- Items keys generated randomly (not password-derived)
- Items keys encrypted with primary key
- Server is "dumb data store"

**Sharing limitations:**

- ❌ **No real-time collaboration** due to E2EE architecture
- ⚠️ Multiple users can share account, but conflicts occur
- ✅ Can share via public links (Listed extension)

**Key takeaways:**

- Real-time collaboration **conflicts with zero-knowledge E2EE**
- This is acceptable for medical records (not real-time)
- Subscription sharing ≠ data sharing (important distinction)

**Source:** [Standard Notes Encryption Whitepaper](https://standardnotes.com/help/security/encryption)

### 5.4 ProtonMail

**Architecture:** PGP-based with bcrypt key derivation

**How it works:**

- Private key encrypted with mailbox password
- Two categories: email encryption keys + account keys
- Each address has separate keys

**Shared mailbox status:**

- ⚠️ Limited shared mailbox support
- Unclear how key management works for multi-user access
- Community requests suggest this is a feature gap

**Key takeaways:**

- ProtonMail's architecture optimized for individual mailboxes
- Multi-user shared access is complex with E2EE
- Not a good model for our use case

**Source:** [ProtonMail Encryption Explained](https://proton.me/support/proton-mail-encryption-explained)

---

## 6. CryptoKit Capabilities & Limitations

### 6.1 Supported Algorithms

✅ **Hash Functions:**

- SHA256, SHA384, SHA512

✅ **Symmetric Encryption:**

- AES-256-GCM (required per AGENTS.md)
- ChaChaPoly

✅ **Key Derivation:**

- HKDF (HMAC-based KDF)

✅ **Key Wrapping:**

- AES.KeyWrap (RFC 3394 / NIST SP 800-38F)

✅ **Public-Key Crypto:**

- Curve25519 (X25519 key agreement, Ed25519 signatures)
- P256, P384, P521 (NIST curves)

✅ **Digital Signatures:**

- Ed25519, ECDSA

✅ **Secure Enclave:**

- Subset of APIs can use Secure Enclave for key storage

### 6.2 Notable Limitations

❌ **AES-CBC:** Not supported (intentionally - easy to misuse)

❌ **RSA Encryption:** Not supported

- CryptoKit has RSA signatures, but not RSA encryption
- Bitwarden uses RSA, but we can use Curve25519 instead

❌ **PBKDF2:** Not in CryptoKit

- Must use CommonCrypto's `CCKeyDerivationPBKDF`
- Or use Argon2id via vetted third-party library

❌ **Argon2:** Not in CryptoKit

- Requires third-party library (check licensing & audits)

❌ **Cross-platform:** CryptoKit is Apple-only

- For cross-platform: use [Swift Crypto](https://github.com/apple/swift-crypto) (BoringSSL-backed)

### 6.3 CryptoKit Version History

- **iOS 13+**: Initial release
- **iOS 14+**: Added PEM/DER support
- **2025**: Swift Crypto 4.0.0 released (September 2025)

**Verdict:** CryptoKit has everything we need for the recommended hybrid approach.

**Sources:**

- [Apple CryptoKit Documentation](https://developer.apple.com/documentation/cryptokit/)
- [Swift Crypto GitHub](https://github.com/apple/swift-crypto)

---

## 7. Mobile-Specific Considerations

### 7.1 iOS Keychain Sharing

**Between apps (same developer):**

- ✅ Keychain access groups enable sharing between apps
- Requirement: Same App ID prefix

**Between users on same device:**

- ❌ **Not supported** for different user accounts
- Each iOS user has separate Keychain

**Family Sharing (iOS 17+):**

- ✅ iCloud Keychain supports password/passkey sharing groups
- ⚠️ Requires iCloud Family setup
- ❌ **Not suitable** for our use case (can't assume iCloud Family)

**Verdict:** Cannot rely on iOS Keychain for cross-user sharing. Must use public-key crypto.

**Sources:**

- [Apple: Sharing Keychain Items](https://developer.apple.com/documentation/security/sharing-access-to-keychain-items-among-a-collection-of-apps)
- [iOS 17 Password Sharing](https://appleinsider.com/inside/ios-17/tips/how-to-share-passwords-with-family-friends-in-ios-17)

### 7.2 Performance Considerations

**AES-GCM Encryption:**

- ~0.5-1ms per record (< 10KB data) on modern iOS devices
- Negligible overhead for < 1000 records

**X25519 Key Agreement:**

- ~1-2ms per operation
- Acceptable for unwrapping FMK (one-time cost per family member)

**AES Key Wrapping:**

- < 0.1ms (very fast)

**Re-encryption for Revocation:**

- 500 records × 1ms = ~500ms
- Acceptable for hobby app

### 7.3 Secure Enclave

CryptoKit can use Secure Enclave for key generation and operations:

```swift
let privateKey = try P256.KeyAgreement.PrivateKey(secureEnclaveKey: true)
```

**Limitations:**

- Only P256, not Curve25519
- Keys cannot be exported from Secure Enclave

**Verdict:** Consider for future enhancement, but not required for Phase 1.

---

## 8. Comparison Matrix

| Pattern | Security | CryptoKit | KISS | Offline | Perf | Revocation | Insecure Channel | Recommendation |
|---------|----------|-----------|------|---------|------|------------|------------------|----------------|
| **Double Ratchet** | ✅✅ | ⚠️ | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ Not suitable |
| **Symmetric Key Wrap** | ✅ | ✅✅ | ✅✅ | ✅✅ | ✅✅ | ⚠️ | ❌ | ⚠️ Needs public-key |
| **Public-Key Sharing (per-record)** | ✅✅ | ✅✅ | ✅ | ✅✅ | ✅ | ⚠️ | ✅✅ | ✅ Good |
| **Hybrid Per-Family-Member** | ✅✅ | ✅✅ | ✅ | ✅✅ | ✅✅ | ⚠️ | ✅✅ | ✅✅ **BEST** |

**Legend:**

- ✅✅ Excellent
- ✅ Good
- ⚠️ Moderate / Trade-offs
- ❌ Poor / Not suitable

---

## 9. Recommendations

### 9.1 Primary Recommendation: Hybrid Per-Family-Member Keys

**Use this pattern for ADR-0002 (Key Hierarchy) and ADR-0003 (Sharing Model).**

**Key Hierarchy:**

```
User Password
    ↓ (PBKDF2 100k+ iterations or Argon2id)
User Primary Key (stored in Keychain, never transmitted)
    ↓ (Used to encrypt user's Curve25519 private key)
User Identity Keypair (Curve25519)
    ↓ (ECDH with other user's public key + HKDF)
Shared Secret (ephemeral, per-relationship)
    ↓ (AES.KeyWrap)
Family Member Key (FMK) - one per family member
    ↓ (AES-256-GCM)
Medical Records (encrypted at rest)
```

**Sharing Flow:**

1. Adult A generates Curve25519 keypair (one-time setup)
2. Adult A creates family member profile for Emma
3. System generates random FMK_Emma
4. System wraps FMK_Emma for Adult A
5. Adult A shares Emma's records with Adult B:
   - Adult B generates Curve25519 keypair
   - Adult B shares public key with Adult A (via email, QR code)
   - Adult A verifies Adult B's public key (out-of-band)
   - Adult A unwraps FMK_Emma
   - Adult A wraps FMK_Emma for Adult B (ECDH + AES.KeyWrap)
   - System stores wrapped FMK for Adult B
6. Adult B can now decrypt all of Emma's records

**Revocation Flow:**

1. Adult A revokes Adult C's access to Emma:
   - Generate new FMK_Emma
   - Re-encrypt all Emma's records with new FMK
   - Re-wrap new FMK for Adult A and Adult B
   - Delete wrapped FMK for Adult C
   - Adult C can no longer decrypt (old FMK is useless)

### 9.2 Implementation Details for ADRs

**For ADR-0002 (Key Hierarchy):**

- User Primary Key: PBKDF2-HMAC-SHA256 (100k+ iterations) or Argon2id
- User Identity: Curve25519.KeyAgreement.PrivateKey (stored encrypted in Keychain)
- Family Member Keys: Random SymmetricKey(size: .bits256)
- Storage: iOS Keychain for user keys, Core Data for wrapped FMKs

**For ADR-0003 (Sharing Model):**

- Public key exchange: QR code (in-person) or email + verification code
- Key wrapping: ECDH (X25519) + HKDF + AES.KeyWrap
- Granularity: Per-family-member (not per-record)
- Revocation: Re-encrypt all records for that family member

**For ADR-0004 (Sync Encryption):**

- Encrypted blobs: Entire records encrypted with FMK
- Metadata: recordId (UUID), familyMemberId (UUID), recordType (plaintext)
- Wrapped keys: Synced separately (userId → wrapped FMK mapping)
- Conflict resolution: Last-write-wins for simplicity (KISS)

**For ADR-0005 (Access Revocation):**

- Method: Re-encrypt with new FMK + delete old wrapped keys
- Performance: Acceptable for < 1000 records per family member
- Audit trail: Log revocation events (encrypted)

### 9.3 CryptoKit Code Patterns

See proof-of-concept files:

- [poc-symmetric-key-wrapping.swift](poc-symmetric-key-wrapping.swift)
- [poc-public-key-sharing.swift](poc-public-key-sharing.swift)
- [poc-hybrid-family-keys.swift](poc-hybrid-family-keys.swift) ← **Recommended**

---

## 10. Public Key Exchange UX

### Context

The user asked: *"I imagine the easiest way to do it is that Adult A initiates sharing with Adult B by email?"*

**Answer:** Yes, email is a natural starting point for the sharing flow. However, we need to handle public key exchange securely to prevent Man-in-the-Middle (MITM) attacks.

### 10.1 Sharing Flow Options

#### Option 1: Email + Out-of-Band Verification (RECOMMENDED)

**Flow:**

1. Adult A clicks "Share Emma's records with someone"
2. App shows Adult A's public key fingerprint (6-digit code)
3. Adult A sends email: "I'm sharing Emma's medical records with you. Install the app and verify code: 123-456"
4. Adult B installs app, generates keypair
5. Adult B enters Adult A's email
6. App exchanges public keys via server (insecure channel is OK)
7. **Verification step:** Both users see 6-digit code (derived from shared secret)
8. Adult A and Adult B verify codes match (phone call, text message, in-person)
9. If codes match, sharing is confirmed

**Security:**

- ✅ Prevents MITM (attacker would have different code)
- ✅ Similar to Signal's "Safety Numbers"
- ✅ User-friendly (6-digit code easy to verify)

**UX Challenge:**

- ⚠️ Requires out-of-band verification step
- Mitigation: Clear instructions, optional step (TOFU mode)

#### Option 2: QR Code (In-Person)

**Flow:**

1. Adult A and Adult B meet in person
2. Adult A clicks "Share Emma's records"
3. App generates QR code containing Adult A's public key
4. Adult B scans QR code
5. Sharing confirmed immediately (no verification needed)

**Security:**

- ✅ Most secure (no MITM possible)
- ✅ No out-of-band verification needed

**UX Challenge:**

- ❌ Requires in-person meeting (not always convenient)

#### Option 3: TOFU (Trust On First Use) + Later Verification

**Flow:**

1. Adult A initiates sharing via email
2. Public keys exchanged automatically (no verification)
3. Sharing works immediately
4. App shows verification code in settings
5. Users can optionally verify later (call/text to confirm code)
6. App warns if code doesn't match

**Security:**

- ⚠️ Vulnerable to MITM on first use
- ✅ Can detect attacks if users verify later

**UX:**

- ✅ Easiest (no verification step required)
- ⚠️ Less secure than Option 1

### 10.2 Recommendation

**Phase 1:** Implement Option 3 (TOFU + Optional Later Verification)

- **Simplest UX** - critical for adoption
- Works for all family dynamics (local, remote, complex situations)
- Medical records are less time-sensitive than messaging (MITM risk is lower)
- Users can optionally verify later if concerned

**Phase 2 Enhancement:** Add Option 2 (QR Code)

- For users who prefer maximum security
- Good for initial family setup

**Why TOFU is acceptable for medical records:**

- ✅ Medical data is **static** (not real-time messaging where MITM enables active surveillance)
- ✅ Attackers need to intercept **specific** sharing invitation (harder than passive surveillance)
- ✅ Later verification catches attacks and allows re-keying
- ✅ **UX is critical** - complex flows reduce adoption
- ✅ Real-world families: geographic distance, estranged members, custody arrangements, etc.
- ⚠️ Trade-off accepted: Convenience over perfect forward secrecy on first share

### 10.3 Implementation Notes

**Verification Code Generation:**

```swift
// Both users derive the same code from shared secret
let sharedSecret = try privateKey.sharedSecretFromKeyAgreement(with: theirPublicKey)
let verificationCode = SHA256.hash(data: sharedSecret.rawRepresentation)
    .prefix(3)  // 3 bytes = 6 hex digits
    .map { String(format: "%02X", $0) }
    .joined(separator: "-")  // e.g., "A3-5F-2B"
```

**Email Template (TOFU approach):**

```
Subject: [Family Medical App] Adult A wants to share Emma's records

Adult A has invited you to access Emma's medical records.

1. Install the Family Medical App
2. Accept this invitation

[Accept Invitation Button]

Security note: After accepting, you can optionally verify the connection
with Adult A by comparing security codes in Settings > Shared Access.
```

---

## 11. Next Steps

### For ADR Writing

Use this research to inform:

1. **ADR-0002: Key Hierarchy**
   - Use Hybrid Per-Family-Member model
   - Document key derivation (PBKDF2 vs Argon2id decision)
   - Specify Curve25519 for user identity

2. **ADR-0003: Sharing Model**
   - Public-key encryption (X25519 ECDH)
   - Email + verification code for key exchange
   - Per-family-member granularity

3. **ADR-0004: Sync Encryption**
   - Encrypted blobs (AES-256-GCM per AGENTS.md)
   - Metadata strategy (what's plaintext vs encrypted)
   - Wrapped FMK synchronization

4. **ADR-0005: Access Revocation**
   - Re-encryption strategy
   - Performance analysis (500 records in ~500ms)
   - Audit trail design

### Proof-of-Concept Code

Three PoC files created:

1. `poc-symmetric-key-wrapping.swift` - Foundation pattern
2. `poc-public-key-sharing.swift` - Insecure channel sharing
3. `poc-hybrid-family-keys.swift` - **Recommended approach**

### Open Questions for ADRs

1. **PBKDF2 vs Argon2id:**
   - PBKDF2: Native to CommonCrypto, simpler
   - Argon2id: Better security (memory-hard), requires third-party library

2. **Verification Code UX:**
   - Required or optional?
   - 6-digit or 8-digit code?
   - How to handle users who skip verification?

3. **Key Rotation:**
   - How often should Curve25519 keypairs be rotated?
   - Automatic or manual rotation?

4. **Backup & Recovery:**
   - How to recover access if device is lost?
   - Encrypted backup of private key with recovery code?

---

## References

### Primary Sources

1. [Signal Protocol - Double Ratchet](https://signal.org/docs/specifications/doubleratchet/)
2. [Signal Protocol - Wikipedia](https://en.wikipedia.org/wiki/Signal_Protocol)
3. [NIST SP 800-38F - AES Key Wrapping](https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-38F.pdf)
4. [Apple CryptoKit Documentation](https://developer.apple.com/documentation/cryptokit/)
5. [Bitwarden Security Whitepaper](https://bitwarden.com/help/bitwarden-security-white-paper/)
6. [1Password Security Design - Shared Vaults](https://agilebits.github.io/security-design/sharedVaults.html)
7. [Standard Notes Encryption Whitepaper](https://standardnotes.com/help/security/encryption)
8. [ProtonMail Encryption Explained](https://proton.me/support/proton-mail-encryption-explained)

### Additional Resources

- [RFC 3394: AES Key Wrap](https://www.rfc-editor.org/rfc/rfc3394)
- [Swift Crypto GitHub](https://github.com/apple/swift-crypto)
- [CryptoKit Curve25519 Documentation](https://developer.apple.com/documentation/cryptokit/curve25519)
- [Apple: Sharing Keychain Items](https://developer.apple.com/documentation/security/sharing-access-to-keychain-items-among-a-collection-of-apps)

---

**Research completed:** 2025-12-19
**Next:** Write ADR-0002 (Key Hierarchy)
