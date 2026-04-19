# OPAQUE Zero-Knowledge Authentication

## Status

**Status**: Accepted

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
- **Rate limiting**: Applied per client_identifier (5 req/60s for login, 3 req/300s for registration)
- **Account enumeration resistance**: Full RFC 9807 §10.9 compliance. For unknown users, the server completes the full OPAQUE protocol using a fake record, making responses cryptographically indistinguishable from real users. The login will fail at the finish step with the same "Authentication failed" error.

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

## Addendum: Rate-limit ladder (2026-04-18)

The OPAQUE auth endpoints use a two-tier rate-limit ladder.

### Server-side defaults

All endpoints (`backend-rust/src/rate_limit.rs`):

- **Default ladder:** 5 requests per 60-second window (`DEFAULT_MAX_REQUESTS`, `DEFAULT_WINDOW_SECONDS`). Applied to `/login/start` (and any future endpoint that calls `RateLimitConfig::default()`).
- **Registration ladder** (applied to `/register/start`): 3 requests per 300-second (5-minute) window (`REGISTRATION_MAX_REQUESTS`, `REGISTRATION_WINDOW_SECONDS`). Rationale: the registration handshake creates durable state (envelope storage, key-material derivation) per attempt, so the cost of tolerating a high attempt rate is meaningfully higher than for login.

### Client-side back-off

The iOS client applies its own escalating device-lockout ladder in `AuthenticationService.swift` (`rateLimitThresholds`) after consecutive failed unlock attempts, before touching the server:

- 3 failures → 30-second lockout
- 4 failures → 60 seconds
- 5 failures → 300 seconds
- 6+ failures → 900 seconds

This client ladder defends against a stranger with the physical device; the server ladder defends against a remote attacker burning credentials against the API. The two layers are deliberately independent — a client that bypasses or reinstalls past the device-lockout still hits the server ceiling before causing persistent damage.

### Server-side fake-record TTL

Per RFC 9807 §10.9, the server must synthesise a deterministic fake login envelope on username miss to prevent timing / structure-based account enumeration. The fake-record state is stored in the `LOGIN_STATES` KV namespace and evicted after `LOGIN_STATE_TTL_SECONDS` (currently 60). This window must be ≥ the longest plausible client-side KE2 → KE3 round trip; 60s is deliberately generous.

The current value coincidentally equals `DEFAULT_WINDOW_SECONDS`. The equality is convenient but not semantic — retune independently.

### What to change together

Any change to `DEFAULT_MAX_REQUESTS` / `DEFAULT_WINDOW_SECONDS` / `REGISTRATION_MAX_REQUESTS` / `REGISTRATION_WINDOW_SECONDS` / `LOGIN_STATE_TTL_SECONDS` must be reflected in this addendum and cross-checked against the client-side ladder in `AuthenticationService.swift`.

## Addendum: Session / auto-lock lifetime (2026-04-18)

Default auto-lock timeout: **300 seconds (5 minutes)** (see `LockStateService.defaultTimeout`).

### Rationale

A medical-records app sits between two typical mobile timeout points:

- Banking apps often auto-lock after 60–120 seconds — a strong security stance but a high interruption rate for short, task-focused sessions.
- General-purpose apps commonly leave lock-state to the device's own OS screen lock (often 5 minutes), relying on the device passcode as the fallback.

Five minutes was chosen because:

1. The primary threat model (ADR-0001) treats the device as a soft-trust boundary — the OS screen lock is the first line of defence and its lifetime is user-controlled.
2. The OPAQUE primary passphrase is relatively expensive to re-enter (12+ chars); forcing re-entry every 60s materially degrades session-continuity for common flows like "photograph three bottles, then annotate them."
3. The 300s timer protects only the *background-time* gap. The app locks immediately on `WillResignActive` / `DidEnterBackground`, so the timer is not guarding the foreground-but-unattended case — that threat is covered by the device's own OS screen lock, whose lifetime is user-controlled and which users with a stricter risk tolerance can tighten independently of this default.

### Tunability contract

The 300s value is a tunable, not a constant. If user research or a compliance requirement shifts the balance, update this section and the `LockStateService.defaultTimeout` value together.

## Addendum: Rate-limiter fail-open policy and alerting contract (2026-04-18)

**Policy:** the rate limiter in `backend-rust/src/rate_limit.rs` fails open on KV-backend errors. A failure to read or write the counter entry allows the request through rather than blocking it.

**Rationale.** Cloudflare's edge network (the pre-application layer) is the primary defence against L3/L4 floods.
Application-level rate limiting exists to tame *correlated* high-effort attacks — repeated OPAQUE-handshake attempts from the same client identifier.
If the KV backend is degraded enough that rate-limit counters are unavailable, auth flows that depend on KV (`CREDENTIALS`, `LOGIN_STATES`, `BUNDLES`) are also degraded, so the rate-limiter's fail-open stance does not widen the attacker's actual window.

**Self-limiting property.** When a stored rate-limit entry fails to deserialize (possible causes: schema migration, byte poisoning via a bug elsewhere), the read path treats it as `None` → fresh window → `count=1` → the next write overwrites the poisoned bytes with well-formed JSON. The attacker's payoff is *exactly one extra allowed request* for the affected client identifier, after which normal accounting resumes.

### Failure-mode taxonomy and counters

The read path emits three distinct counters (as structured `console_*!` log lines with a `counter=` prefix; ops dashboards grep this prefix to build per-counter alerts):

- `rate_limit_kv_get_error` — KV backend unavailable (transient). Expected to be near-zero in normal operation; bursts indicate a Cloudflare KV incident. Severity: warn.
- `rate_limit_deser_error` — stored entry failed to deserialize. **Expected to be flat zero in normal operation.** A non-zero rate indicates either a schema migration is in flight without a corresponding read-side migration, or an active attempt to poison a rate-limit key. Severity: error. Alert immediately.
- `rate_limit_kv_put_error` — KV backend unavailable on write. Same class as `kv_get_error`. Severity: warn.

The write path emits `rate_limit_kv_put_error` for the single put site (the read-then-write has exactly one `put_entry` call regardless of whether the window is new or incremented).

### Alerting contract

- `rate_limit_deser_error > 0` over any 5-minute window → page oncall.
- `rate_limit_kv_get_error` or `rate_limit_kv_put_error` sustained > 10/min for 5 minutes → alert (indicates KV incident).
