# OPAQUE Zero-Knowledge Authentication

## Status

**Status**: Proposed

## Context

The Family Medical App requires user authentication for cloud sync and data sharing. An earlier approach considered email verification with hashed emails stored on the server. While privacy-preserving compared to plaintext email storage, this approach has limitations:

1. **Email hashes are reversible**: Common emails can be rainbow-tabled
2. **Server knows when users authenticate**: Timing metadata leakage
3. **Email infrastructure required**: Adds complexity (AWS SES, delivery issues)
4. **No offline-first registration**: Requires network for email verification

### Requirements

1. **Zero-knowledge identity**: Server cannot learn username or password
2. **Server compromise resistance**: Stolen database enables only online attacks (rate-limitable)
3. **No email dependency**: Works without email infrastructure
4. **Offline-first**: Local account creation, sync when online
5. **Wire compatibility**: Client and server must use compatible OPAQUE implementations

### OPAQUE Protocol Overview

OPAQUE (RFC 9807) is an augmented Password-Authenticated Key Exchange (aPAKE) that:

- Never transmits password or password-equivalent to server
- Uses Oblivious PRF (OPRF) so server contributes to key derivation without learning password
- Provides mutual authentication and forward secrecy
- Resists pre-computation attacks even if server is compromised

## Decision

We will implement OPAQUE-based authentication using:

1. **iOS Client**: `opaque-ke` (Rust) wrapped via Mozilla UniFFI for Swift bindings
2. **Server**: `opaque-ke` (Rust) compiled to wasm32-unknown-unknown for Cloudflare Workers
3. **Storage**: Cloudflare KV for OPAQUE credential files

### Authentication Flows

#### Registration (New User)

```
┌─────────────────┐                              ┌─────────────────┐
│   iOS Client    │                              │  CF Workers     │
└────────┬────────┘                              └────────┬────────┘
         │                                                │
         │  1. User enters username + password            │
         │     Client: registration_request =             │
         │       ClientRegistration::start(password)      │
         │                                                │
         │  ──────── registration_request ──────────────► │
         │           (+ client_identifier)                │
         │                                                │
         │                                2. Server:      │
         │                                   ServerRegistration::start()
         │                                   generates registration_response
         │                                                │
         │  ◄─────── registration_response ────────────── │
         │                                                │
         │  3. Client: registration_upload, export_key =  │
         │       ClientRegistration::finish(response)     │
         │                                                │
         │  ──────── registration_upload ───────────────► │
         │                                                │
         │                                4. Server:      │
         │                                   password_file =
         │                                     ServerRegistration::finish()
         │                                   Store password_file in KV
         │                                                │
         │  5. export_key used to derive Primary Key      │
         │     (integrates with ADR-0002 key hierarchy)   │
         │                                                │
```

#### Login (Returning User)

```
┌─────────────────┐                              ┌─────────────────┐
│   iOS Client    │                              │  CF Workers     │
└────────┬────────┘                              └────────┬────────┘
         │                                                │
         │  1. User enters username + password            │
         │     Client: credential_request =               │
         │       ClientLogin::start(password)             │
         │                                                │
         │  ──────── credential_request ────────────────► │
         │           (+ client_identifier)                │
         │                                                │
         │                                2. Server:      │
         │                                   Lookup password_file from KV
         │                                   credential_response =
         │                                     ServerLogin::start(password_file)
         │                                                │
         │  ◄─────── credential_response ───────────────  │
         │                                                │
         │  3. Client: credential_finalization,           │
         │             session_key, export_key =          │
         │       ClientLogin::finish(response)            │
         │                                                │
         │  ──────── credential_finalization ───────────► │
         │                                                │
         │                                4. Server:      │
         │                                   session_key =
         │                                     ServerLogin::finish()
         │                                   Both have matching session_key
         │                                                │
         │  5. export_key used to derive Primary Key      │
         │     Decrypt user's data bundle                 │
         │                                                │
```

### Client Identifier Design

The client sends a **client_identifier** derived from the username:

```
client_identifier = SHA256(username || app_salt)
```

This provides:

- **Username privacy**: Server stores only the hash
- **Collision resistance**: 256-bit hash space
- **Deterministic**: Same username always maps to same identifier

The server uses `client_identifier` as the KV key for storing password files.

### Integration with Key Hierarchy (ADR-0002)

OPAQUE's `export_key` replaces the password-derived Primary Key:

```
Current (ADR-0002):
  Primary Key = Argon2id(password, salt)

New (with OPAQUE):
  export_key = OPAQUE protocol output (already memory-hard via internal KSF)
  Primary Key = HKDF(export_key, context="primary-key")
```

Benefits:

- OPAQUE uses Argon2 internally for key stretching
- export_key is 256-bit, suitable for key derivation
- No separate salt storage needed (OPAQUE handles this securely)

### Data Bundle Storage

After successful authentication, the server returns the user's encrypted data bundle:

```
KV Storage:
  key: "cred:{client_identifier}"     → OPAQUE password_file
  key: "bundle:{client_identifier}"   → Encrypted data (FMKs, settings, sync state)
```

The bundle is encrypted with a key derived from export_key, ensuring zero-knowledge.

### Error Handling

OPAQUE intentionally provides no indication of whether username or password is wrong:

- **Invalid credentials**: Generic "Authentication failed" error
- **Rate limiting**: Applied per client_identifier and per IP
- **Account enumeration resistance**: Registration and login responses are indistinguishable

## Consequences

### Positive

1. **True zero-knowledge**: Server never learns username or password
2. **Server compromise resistance**: Stolen password_files require online brute-force (rate-limitable)
3. **No email infrastructure**: Removes AWS SES dependency, delivery issues
4. **Offline-first**: Create account locally, register with server when online
5. **Wire compatible**: Both client and server use opaque-ke
6. **Forward secrecy**: Each session derives fresh keys
7. **Mutual authentication**: Client verifies server, server verifies client

### Negative

1. **No password recovery**: By design, server cannot reset passwords
   - **Mitigation**: Recovery codes (existing ADR-0004 pattern)
2. **UniFFI complexity**: Requires Rust→Swift build pipeline
   - **Mitigation**: One-time setup, well-documented process
3. **Cannot distinguish wrong password from wrong username**
   - **Mitigation**: This is a security feature, not a bug
4. **New dependency**: opaque-ke Rust crate + UniFFI
   - **Mitigation**: opaque-ke is audited (NCC Group), UniFFI is production-proven (Mozilla)

### Neutral

1. **No email infrastructure**: Email verification approach was considered but rejected
2. **Username instead of email**: Users choose a username (can still be email-formatted if desired)
3. **Two round-trips**: OPAQUE requires request→response→finalization (vs single password check)

## Related Decisions

- **ADR-0002**: Key Hierarchy - Updated to use OPAQUE export_key
- **ADR-0004**: Sync Encryption - Recovery codes remain for account recovery

## References

- [RFC 9807: OPAQUE Protocol](https://datatracker.ietf.org/doc/rfc9807/)
- [opaque-ke Rust library](https://github.com/facebook/opaque-ke) (audited by NCC Group)
- [@serenity-kit/opaque](https://github.com/serenity-kit/opaque) (TypeScript wrapper)
- [Mozilla UniFFI](https://github.com/mozilla/uniffi-rs) (Rust→Swift bindings)
- [Cloudflare OPAQUE blog post](https://blog.cloudflare.com/opaque-oblivious-passwords/)

---

**Decision Date**: 2026-01-28
**Author**: Claude Code
**Reviewers**: [To be assigned]
