# Agent Guidelines

## Tech Stack

### iOS
- **Xcode**: 26.2+ (December 2025)
- **Swift**: 6.2.3+ (ships with Xcode 26.2)
- **iOS Deployment Target**: 16.0+ (supports 93.9% of devices, good balance of reach and modern APIs)
- **iOS SDK**: 26.2+ (build with latest SDK, but deploy to older iOS versions)
- **UI**: SwiftUI only
- **Crypto**: CryptoKit (Apple's framework) + CommonCrypto (PBKDF2 only)
- **Auth**: LocalAuthentication framework
- **Storage**: Core Data with field-level encryption (CryptoKit)
- **Networking**: URLSession with certificate pinning

### Cryptography - Use These Exact Specs
- **Symmetric Encryption**: AES-256-GCM (CryptoKit.AES.GCM)
- **Key Derivation**: PBKDF2-HMAC-SHA256 (100k iterations via CommonCrypto.CCKeyDerivationPBKDF)
  - Future enhancement: Argon2id (Phase 4)
- **Public-Key Crypto**: Curve25519 (CryptoKit.Curve25519.KeyAgreement for ECDH)
- **Key Wrapping**: AES.KeyWrap (CryptoKit.AES.KeyWrap - RFC 3394)
- **Key Derivation Function**: HKDF (SharedSecret.hkdfDerivedSymmetricKey)
- **Random Generation**: CryptoKit.SymmetricKey, SecRandomCopyBytes
- **NO custom crypto implementations - ever**

## Key Hierarchy

Three tiers: User Master Key → User Identity (Curve25519) → Family Member Keys → Medical Records.

**Per-family-member encryption**: Each patient has their own FMK. Use ECDH + Key Wrapping for sharing.

**See**: [ADR-0002](docs/adr/adr-0002-key-hierarchy.md) for complete design and rationale.

## Encryption Boundaries

### Must Be Encrypted (before leaving device)
- All medical records (vaccines, conditions, medications, allergies)
- Family member PII (names, DOB, relationships)
- Document attachments (images, PDFs)
- User notes and custom fields
- Sharing metadata (who has access to what)

### Can Be Plaintext (locally or in transit over TLS)
- App configuration
- UI strings
- Sync metadata: timestamps, device IDs, version numbers
- User's own device list (for their account only)

### Never Store Anywhere (even encrypted)
- Decryption keys in logs or analytics
- Stack traces containing medical data
- User passwords (store salt in UserDefaults, derive Master Key on-demand)
- Master Key or Private Key on server (they NEVER leave the device)
- Unwrapped Family Member Keys on server (only wrapped versions)

## iOS-Specific Gotchas

### Keychain
- **Use Keychain for**: Master Key, Private Key (Curve25519), owned Family Member Keys
- **Use Core Data for**: Shared/wrapped keys, encrypted records, public keys
- **Never use UserDefaults for**: keys, passwords, tokens
- **Protection**: `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`, never sync to iCloud

### Biometric Auth
- **Always provide fallback**: Face/Touch ID may be disabled, unavailable, or fail
- **Don't assume it's configured**: gracefully degrade to password
- **Use LAContext**: check availability before attempting auth

### Memory Management
- Clear sensitive data from memory after use (zero out, don't just dereference)
- Use `withUnsafeBytes` carefully with crypto operations

### Background Modes
- App may be killed while syncing - handle partial sync states
- Don't decrypt data in app extensions unless absolutely necessary

## Common Mistakes to Avoid

1. **Storing keys in UserDefaults** → Use Keychain
2. **Storing Master Key on server** → NEVER (device-only)
3. **Deriving user identity from password** → Generate randomly (see ADR-0002)
4. **Per-record encryption keys** → Use per-family-member FMKs (see ADR-0002)
5. **Assuming biometrics work** → Always have password fallback
6. **Custom crypto** → Use CryptoKit + CommonCrypto only
7. **Trusting server timestamps** → Validate on client
8. **Weak KDF iterations** → Use ≥100k for PBKDF2
9. **Logging decrypted data** → Never log medical data, even for debugging
10. **"Soft delete" for revocation** → Re-encrypt with new FMK (see ADR-0002)

## Testing Requirements

For security-critical code (auth, encryption, key derivation, sharing):
- Write unit tests
- Test failure cases (wrong password, corrupted data, missing keys)
- Test key rotation and access revocation

## Communication Style

**Be direct. No fluff.**

### Don't
- Suggest what to do while waiting for downloads/builds
- Say "Let me know when..." (user will tell you)
- Offer patronizing suggestions ("take a break", "review the docs")
- Add encouragement or motivational content
- State the obvious ("this is a big download")
- Repeat information already in documentation

### Do
- Give only necessary technical information
- State what's required, then stop
- Answer questions directly
- Provide context only when it prevents mistakes

---

See README.md for architecture and threat model.
