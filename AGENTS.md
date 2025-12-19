# Agent Guidelines

## Tech Stack

### iOS
- **Swift**: 5.9+
- **iOS Target**: 16.0+
- **UI**: SwiftUI only
- **Crypto**: CryptoKit (Apple's framework)
- **Auth**: LocalAuthentication framework
- **Storage**: TBD (Core Data + encryption OR SQLCipher)
- **Networking**: URLSession with certificate pinning

### Cryptography - Use These Exact Specs
- **Symmetric Encryption**: AES-256-GCM (CryptoKit.AES.GCM)
- **Key Derivation**: Argon2id OR PBKDF2-HMAC-SHA256 (min 100k iterations)
- **Random Generation**: CryptoKit.SymmetricKey, SecRandomCopyBytes
- **NO custom crypto implementations - ever**

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
- User passwords (only derived keys in Keychain)

## iOS-Specific Gotchas

### Keychain
- **Use Keychain for**: encryption keys, derived user secrets
- **Never use UserDefaults for**: keys, passwords, tokens

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
2. **Assuming biometrics work** → Always have password fallback
3. **Custom crypto** → Use CryptoKit only
4. **Trusting server timestamps** → Validate on client
5. **Weak KDF iterations** → Use ≥100k for PBKDF2, proper params for Argon2
6. **Logging decrypted data** → Never log medical data, even for debugging

## Testing Requirements

For security-critical code (auth, encryption, key derivation, sharing):
- Write unit tests
- Test failure cases (wrong password, corrupted data, missing keys)
- Test key rotation and access revocation

---

See README.md for architecture and threat model.
