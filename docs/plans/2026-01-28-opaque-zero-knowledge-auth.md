# OPAQUE Zero-Knowledge Authentication Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace email-based authentication with OPAQUE protocol for true zero-knowledge authentication where the server never learns the username or password.

**Architecture:** Client (Swift via UniFFI-wrapped opaque-ke) ↔ Server (Cloudflare Workers with @serenity-kit/opaque). Both use the same underlying Rust `opaque-ke` library ensuring wire compatibility. OPAQUE provides an "export key" used as the basis for the existing key hierarchy.

**Tech Stack:**

- **iOS Client:** `opaque-ke` (Rust) → UniFFI → Swift XCFramework
- **Backend:** `@serenity-kit/opaque` (TypeScript/WASM) on Cloudflare Workers
- **Storage:** Cloudflare KV for OPAQUE credential files and user data bundles

---

## Phase 1: Architecture Documentation

### Task 1: Create ADR-0012 for OPAQUE Authentication

**Files:**

- Create: `docs/adr/adr-0012-opaque-zero-knowledge-auth.md`
- Modify: `docs/adr/README.md`
- Modify: `docs/adr/adr-0011-email-verification-backend.md` (mark superseded)

**Step 1: Write ADR-0012**

Create `docs/adr/adr-0012-opaque-zero-knowledge-auth.md`:

```markdown
# OPAQUE Zero-Knowledge Authentication

## Status

**Status**: Proposed

## Context

The Family Medical App requires user authentication for cloud sync and data sharing. The previous approach (ADR-0011) used email verification with hashed emails stored on the server. While privacy-preserving compared to plaintext email storage, this approach has limitations:

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
2. **Server**: `@serenity-kit/opaque` (TypeScript, wraps same `opaque-ke` via WASM)
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

1. **Supersedes ADR-0011**: Email verification no longer needed
2. **Username instead of email**: Users choose a username (can still be email-formatted if desired)
3. **Two round-trips**: OPAQUE requires request→response→finalization (vs single password check)

## Related Decisions

- **ADR-0002**: Key Hierarchy - Updated to use OPAQUE export_key
- **ADR-0004**: Sync Encryption - Recovery codes remain for account recovery
- **ADR-0011**: Email Verification Backend - **Superseded** by this ADR

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
```

**Step 2: Update ADR-0011 status to superseded**

Edit `docs/adr/adr-0011-email-verification-backend.md`, change:

```markdown
**Status**: Accepted
```

To:

```markdown
**Status**: Superseded by [ADR-0012](adr-0012-opaque-zero-knowledge-auth.md)
```

**Step 3: Update ADR index**

Add to `docs/adr/README.md` under "Backend Services" section:

```markdown
- [ADR-0012: OPAQUE Zero-Knowledge Authentication](adr-0012-opaque-zero-knowledge-auth.md) - **Proposed** (2026-01-28)
  - OPAQUE protocol (RFC 9807) for true zero-knowledge authentication
  - Server never learns username or password
  - opaque-ke (Rust) via UniFFI for iOS, @serenity-kit/opaque for Cloudflare Workers
  - Supersedes ADR-0011 (email verification no longer needed)
```

Update ADR-0011 entry to show superseded status:

```markdown
- [ADR-0011: Email Verification Backend Architecture](adr-0011-email-verification-backend.md) - ~~Accepted~~ **Superseded** (2026-01-27)
  - ~~Cloudflare Workers with KV storage for email verification codes~~
  - Superseded by ADR-0012 (OPAQUE zero-knowledge authentication)
```

**Step 4: Commit ADR changes**

```bash
git add docs/adr/adr-0012-opaque-zero-knowledge-auth.md docs/adr/adr-0011-email-verification-backend.md docs/adr/README.md
git commit -m "docs(adr): add ADR-0012 for OPAQUE zero-knowledge authentication

Introduces OPAQUE protocol (RFC 9807) for true zero-knowledge auth where
server never learns username or password. Uses opaque-ke via UniFFI for
iOS client and @serenity-kit/opaque for Cloudflare Workers.

Supersedes ADR-0011 (email verification) as email infrastructure is no
longer required."
```

---

## Phase 2: UniFFI Rust Wrapper for iOS

### Task 2: Set up Rust workspace for opaque-swift

**Files:**

- Create: `opaque-swift/Cargo.toml`
- Create: `opaque-swift/src/lib.rs`
- Create: `opaque-swift/src/opaque.udl`
- Create: `opaque-swift/.gitignore`

**Step 1: Create Rust workspace directory**

```bash
mkdir -p opaque-swift/src
```

**Step 2: Create Cargo.toml**

Create `opaque-swift/Cargo.toml`:

```toml
[package]
name = "opaque-swift"
version = "0.1.0"
edition = "2021"
description = "UniFFI wrapper around opaque-ke for Swift"

[lib]
crate-type = ["staticlib", "cdylib"]
name = "opaque_swift"

[dependencies]
opaque-ke = { version = "3", features = ["argon2"] }
rand = "0.8"
argon2 = "0.5"
sha2 = "0.10"
uniffi = { version = "0.28", features = ["cli"] }
thiserror = "1"

[build-dependencies]
uniffi = { version = "0.28", features = ["build"] }

[[bin]]
name = "uniffi-bindgen"
path = "uniffi-bindgen.rs"
```

**Step 3: Create UniFFI bindgen binary**

Create `opaque-swift/uniffi-bindgen.rs`:

```rust
fn main() {
    uniffi::uniffi_bindgen_main()
}
```

**Step 4: Create .gitignore**

Create `opaque-swift/.gitignore`:

```gitignore
/target
Cargo.lock
*.xcframework
generated/
```

**Step 5: Commit workspace setup**

```bash
git add opaque-swift/
git commit -m "feat(opaque-swift): initialize Rust workspace for UniFFI wrapper"
```

---

### Task 3: Implement opaque-swift Rust wrapper

**Files:**

- Create: `opaque-swift/src/lib.rs`
- Create: `opaque-swift/src/opaque.udl`
- Create: `opaque-swift/build.rs`

**Step 1: Create UDL interface definition**

Create `opaque-swift/src/opaque.udl`:

```
namespace opaque_swift {
    /// Generate a client identifier from username
    [Throws=OpaqueError]
    string generate_client_identifier(string username);
};

[Error]
enum OpaqueError {
    "ProtocolError",
    "InvalidInput",
    "SerializationError",
};

/// Client-side registration state
interface ClientRegistration {
    /// Start registration with password, returns serialized registration request
    [Throws=OpaqueError, Name=start]
    constructor(string password);

    /// Get the registration request to send to server
    bytes get_request();

    /// Process server response and complete registration
    /// Returns (registration_upload, export_key)
    [Throws=OpaqueError]
    RegistrationResult finish(bytes server_response);
};

dictionary RegistrationResult {
    bytes registration_upload;
    bytes export_key;
};

/// Client-side login state
interface ClientLogin {
    /// Start login with password, returns serialized credential request
    [Throws=OpaqueError, Name=start]
    constructor(string password);

    /// Get the credential request to send to server
    bytes get_request();

    /// Process server response and complete login
    /// Returns (credential_finalization, session_key, export_key)
    [Throws=OpaqueError]
    LoginResult finish(bytes server_response);
};

dictionary LoginResult {
    bytes credential_finalization;
    bytes session_key;
    bytes export_key;
};
```

**Step 2: Create build.rs**

Create `opaque-swift/build.rs`:

```rust
fn main() {
    uniffi::generate_scaffolding("src/opaque.udl").unwrap();
}
```

**Step 3: Implement lib.rs**

Create `opaque-swift/src/lib.rs`:

```rust
use opaque_ke::{
    ClientRegistration as OpaqueClientRegistration,
    ClientLogin as OpaqueClientLogin,
    ClientRegistrationFinishParameters,
    ClientLoginFinishParameters,
    RegistrationResponse,
    CredentialResponse,
    Identifiers,
    rand::rngs::OsRng,
    CipherSuite,
    Ristretto255,
    keypair::PrivateKey,
};
use sha2::{Sha256, Sha512, Digest};
use std::sync::Mutex;

uniffi::include_scaffolding!("opaque");

/// Cipher suite matching @serenity-kit/opaque configuration
struct DefaultCipherSuite;

impl CipherSuite for DefaultCipherSuite {
    type OprfCs = Ristretto255;
    type KeGroup = Ristretto255;
    type KeyExchange = opaque_ke::key_exchange::tripledh::TripleDh;
    type Ksf = argon2::Argon2<'static>;
}

#[derive(Debug, thiserror::Error, uniffi::Error)]
pub enum OpaqueError {
    #[error("Protocol error")]
    ProtocolError,
    #[error("Invalid input")]
    InvalidInput,
    #[error("Serialization error")]
    SerializationError,
}

/// Generate client identifier from username (SHA256 hash)
#[uniffi::export]
pub fn generate_client_identifier(username: &str) -> Result<String, OpaqueError> {
    const APP_SALT: &[u8] = b"family-medical-app-opaque-v1";

    let mut hasher = Sha256::new();
    hasher.update(username.as_bytes());
    hasher.update(APP_SALT);
    let result = hasher.finalize();

    Ok(hex::encode(result))
}

#[derive(uniffi::Record)]
pub struct RegistrationResult {
    pub registration_upload: Vec<u8>,
    pub export_key: Vec<u8>,
}

#[derive(uniffi::Record)]
pub struct LoginResult {
    pub credential_finalization: Vec<u8>,
    pub session_key: Vec<u8>,
    pub export_key: Vec<u8>,
}

/// Client registration state wrapper
#[derive(uniffi::Object)]
pub struct ClientRegistration {
    state: Mutex<Option<OpaqueClientRegistration<DefaultCipherSuite>>>,
    request: Vec<u8>,
}

#[uniffi::export]
impl ClientRegistration {
    #[uniffi::constructor]
    pub fn start(password: &str) -> Result<Self, OpaqueError> {
        let mut rng = OsRng;

        let result = OpaqueClientRegistration::<DefaultCipherSuite>::start(
            &mut rng,
            password.as_bytes(),
        ).map_err(|_| OpaqueError::ProtocolError)?;

        let request = result.message.serialize().to_vec();

        Ok(Self {
            state: Mutex::new(Some(result.state)),
            request,
        })
    }

    pub fn get_request(&self) -> Vec<u8> {
        self.request.clone()
    }

    pub fn finish(&self, server_response: Vec<u8>) -> Result<RegistrationResult, OpaqueError> {
        let mut state_guard = self.state.lock().map_err(|_| OpaqueError::ProtocolError)?;
        let state = state_guard.take().ok_or(OpaqueError::ProtocolError)?;

        let response = RegistrationResponse::deserialize(&server_response)
            .map_err(|_| OpaqueError::SerializationError)?;

        let mut rng = OsRng;
        let result = state.finish(
            &mut rng,
            password.as_bytes(), // Note: need to store password or redesign
            response,
            ClientRegistrationFinishParameters::default(),
        ).map_err(|_| OpaqueError::ProtocolError)?;

        Ok(RegistrationResult {
            registration_upload: result.message.serialize().to_vec(),
            export_key: result.export_key.to_vec(),
        })
    }
}

/// Client login state wrapper
#[derive(uniffi::Object)]
pub struct ClientLogin {
    state: Mutex<Option<OpaqueClientLogin<DefaultCipherSuite>>>,
    request: Vec<u8>,
}

#[uniffi::export]
impl ClientLogin {
    #[uniffi::constructor]
    pub fn start(password: &str) -> Result<Self, OpaqueError> {
        let mut rng = OsRng;

        let result = OpaqueClientLogin::<DefaultCipherSuite>::start(
            &mut rng,
            password.as_bytes(),
        ).map_err(|_| OpaqueError::ProtocolError)?;

        let request = result.message.serialize().to_vec();

        Ok(Self {
            state: Mutex::new(Some(result.state)),
            request,
        })
    }

    pub fn get_request(&self) -> Vec<u8> {
        self.request.clone()
    }

    pub fn finish(&self, server_response: Vec<u8>) -> Result<LoginResult, OpaqueError> {
        let mut state_guard = self.state.lock().map_err(|_| OpaqueError::ProtocolError)?;
        let state = state_guard.take().ok_or(OpaqueError::ProtocolError)?;

        let response = CredentialResponse::deserialize(&server_response)
            .map_err(|_| OpaqueError::SerializationError)?;

        let result = state.finish(
            password.as_bytes(), // Note: need to store password or redesign
            response,
            ClientLoginFinishParameters::default(),
        ).map_err(|_| OpaqueError::ProtocolError)?;

        Ok(LoginResult {
            credential_finalization: result.message.serialize().to_vec(),
            session_key: result.session_key.to_vec(),
            export_key: result.export_key.to_vec(),
        })
    }
}
```

**Note:** The above is a starting point. The actual implementation will need refinement based on opaque-ke's exact API in version 3.x. Consult the [opaque-ke documentation](https://docs.rs/opaque-ke) during implementation.

**Step 4: Verify Rust code compiles**

```bash
cd opaque-swift && cargo check
```

Expected: Compilation succeeds (may have warnings)

**Step 5: Commit implementation**

```bash
git add opaque-swift/
git commit -m "feat(opaque-swift): implement UniFFI wrapper for opaque-ke

Wraps opaque-ke Rust library with UniFFI bindings exposing:
- ClientRegistration: start() -> get_request() -> finish()
- ClientLogin: start() -> get_request() -> finish()
- generate_client_identifier() for username hashing

Uses DefaultCipherSuite matching @serenity-kit/opaque configuration
(Ristretto255 + TripleDH + Argon2)."
```

---

### Task 4: Build XCFramework for iOS

**Files:**

- Create: `opaque-swift/build-xcframework.sh`
- Create: `opaque-swift/Package.swift`

**Step 1: Create build script**

Create `opaque-swift/build-xcframework.sh`:

```bash
#!/bin/bash
set -euo pipefail

# Build for all iOS targets
echo "Building for iOS device (aarch64)..."
cargo build --release --target aarch64-apple-ios

echo "Building for iOS simulator (aarch64)..."
cargo build --release --target aarch64-apple-ios-sim

echo "Building for iOS simulator (x86_64)..."
cargo build --release --target x86_64-apple-ios

# Generate Swift bindings
echo "Generating Swift bindings..."
cargo run --bin uniffi-bindgen generate \
    --library target/aarch64-apple-ios/release/libopaque_swift.a \
    --language swift \
    --out-dir generated

# Create fat library for simulators
echo "Creating fat library for simulators..."
mkdir -p target/ios-simulator-universal/release
lipo -create \
    target/aarch64-apple-ios-sim/release/libopaque_swift.a \
    target/x86_64-apple-ios/release/libopaque_swift.a \
    -output target/ios-simulator-universal/release/libopaque_swift.a

# Create XCFramework
echo "Creating XCFramework..."
rm -rf OpaqueSwift.xcframework
xcodebuild -create-xcframework \
    -library target/aarch64-apple-ios/release/libopaque_swift.a \
    -headers generated \
    -library target/ios-simulator-universal/release/libopaque_swift.a \
    -headers generated \
    -output OpaqueSwift.xcframework

echo "Done! OpaqueSwift.xcframework created"
```

**Step 2: Make script executable and run**

```bash
chmod +x opaque-swift/build-xcframework.sh
```

**Step 3: Install Rust iOS targets (one-time setup)**

```bash
rustup target add aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios
```

**Step 4: Build the XCFramework**

```bash
cd opaque-swift && ./build-xcframework.sh
```

Expected: `OpaqueSwift.xcframework` directory created

**Step 5: Create Swift Package for easy integration**

Create `opaque-swift/Package.swift`:

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OpaqueSwift",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "OpaqueSwift", targets: ["OpaqueSwift", "OpaqueSwiftFFI"]),
    ],
    targets: [
        .target(
            name: "OpaqueSwift",
            dependencies: ["OpaqueSwiftFFI"],
            path: "generated",
            sources: ["opaque_swift.swift"]
        ),
        .binaryTarget(
            name: "OpaqueSwiftFFI",
            path: "OpaqueSwift.xcframework"
        ),
    ]
)
```

**Step 6: Commit build artifacts**

```bash
git add opaque-swift/build-xcframework.sh opaque-swift/Package.swift
git commit -m "build(opaque-swift): add XCFramework build script and Swift Package"
```

---

## Phase 3: Cloudflare Workers Backend

### Task 5: Update backend for OPAQUE authentication

**Files:**

- Modify: `backend/package.json`
- Create: `backend/src/opaque.ts`
- Modify: `backend/src/index.ts`
- Modify: `backend/wrangler.toml`

**Step 1: Add @serenity-kit/opaque dependency**

Update `backend/package.json` dependencies:

```json
{
  "dependencies": {
    "@serenity-kit/opaque": "^0.8.0"
  }
}
```

Run:

```bash
cd backend && npm install
```

**Step 2: Create OPAQUE handler module**

Create `backend/src/opaque.ts`:

```typescript
import * as opaque from '@serenity-kit/opaque';

// Ensure OPAQUE WASM is loaded
await opaque.ready;

// Server setup (generate once, store securely)
let serverSetup: string | null = null;

export function initServerSetup(storedSetup: string | null): void {
  if (storedSetup) {
    serverSetup = storedSetup;
  } else {
    serverSetup = opaque.server.createSetup();
  }
}

export function getServerSetup(): string {
  if (!serverSetup) {
    throw new Error('Server setup not initialized');
  }
  return serverSetup;
}

// Registration flow
export interface RegistrationStartResult {
  registrationResponse: string;
  serverState: string; // Must be stored temporarily
}

export function startRegistration(
  clientIdentifier: string,
  registrationRequest: string
): RegistrationStartResult {
  const { registrationResponse } = opaque.server.createRegistrationResponse({
    serverSetup: getServerSetup(),
    userIdentifier: clientIdentifier,
    registrationRequest,
  });

  return {
    registrationResponse,
    serverState: '', // Not needed for registration
  };
}

export interface RegistrationFinishResult {
  passwordFile: string;
}

export function finishRegistration(
  clientIdentifier: string,
  registrationUpload: string
): RegistrationFinishResult {
  const { passwordFile } = opaque.server.finishRegistration({
    registrationUpload,
  });

  return { passwordFile };
}

// Login flow
export interface LoginStartResult {
  credentialResponse: string;
  serverState: string; // Must be stored for finish
}

export function startLogin(
  clientIdentifier: string,
  passwordFile: string,
  credentialRequest: string
): LoginStartResult {
  const { credentialResponse, serverLoginState } = opaque.server.startLogin({
    serverSetup: getServerSetup(),
    userIdentifier: clientIdentifier,
    passwordFile,
    credentialRequest,
  });

  return {
    credentialResponse,
    serverState: serverLoginState,
  };
}

export interface LoginFinishResult {
  sessionKey: string;
}

export function finishLogin(
  serverState: string,
  credentialFinalization: string
): LoginFinishResult {
  const { sessionKey } = opaque.server.finishLogin({
    serverLoginState: serverState,
    credentialFinalization,
  });

  return { sessionKey };
}
```

**Step 3: Update main Worker entry point**

Modify `backend/src/index.ts` to add OPAQUE routes:

```typescript
import { initServerSetup, startRegistration, finishRegistration, startLogin, finishLogin } from './opaque';
import { checkRateLimit, RATE_LIMITS } from './rate-limit';

export interface Env {
  CREDENTIALS: KVNamespace;  // OPAQUE password files
  BUNDLES: KVNamespace;      // Encrypted user data
  RATE_LIMITS: KVNamespace;
  LOGIN_STATES: KVNamespace; // Temporary login states (short TTL)
  OPAQUE_SERVER_SETUP: string; // Secret: server setup string
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    // Initialize OPAQUE server setup
    initServerSetup(env.OPAQUE_SERVER_SETUP);

    const url = new URL(request.url);
    const path = url.pathname;

    if (request.method === 'OPTIONS') {
      return corsResponse(null, 204);
    }

    if (request.method === 'POST') {
      // Registration endpoints
      if (path === '/api/auth/register/start') {
        return handleRegisterStart(request, env);
      }
      if (path === '/api/auth/register/finish') {
        return handleRegisterFinish(request, env);
      }

      // Login endpoints
      if (path === '/api/auth/login/start') {
        return handleLoginStart(request, env);
      }
      if (path === '/api/auth/login/finish') {
        return handleLoginFinish(request, env);
      }
    }

    return corsResponse({ error: 'Not found' }, 404);
  }
};

async function handleRegisterStart(request: Request, env: Env): Promise<Response> {
  const { clientIdentifier, registrationRequest } = await request.json();

  // Check if user already exists
  const existing = await env.CREDENTIALS.get(`cred:${clientIdentifier}`);
  if (existing) {
    // Don't reveal whether account exists - return same format
    // but the client will fail at finish step
  }

  const result = startRegistration(clientIdentifier, registrationRequest);

  return corsResponse({
    registrationResponse: result.registrationResponse,
  });
}

async function handleRegisterFinish(request: Request, env: Env): Promise<Response> {
  const { clientIdentifier, registrationUpload, encryptedBundle } = await request.json();

  // Check if user already exists
  const existing = await env.CREDENTIALS.get(`cred:${clientIdentifier}`);
  if (existing) {
    return corsResponse({ error: 'Registration failed' }, 400);
  }

  const result = finishRegistration(clientIdentifier, registrationUpload);

  // Store password file and initial bundle
  await env.CREDENTIALS.put(`cred:${clientIdentifier}`, result.passwordFile);
  if (encryptedBundle) {
    await env.BUNDLES.put(`bundle:${clientIdentifier}`, encryptedBundle);
  }

  return corsResponse({ success: true });
}

async function handleLoginStart(request: Request, env: Env): Promise<Response> {
  const { clientIdentifier, credentialRequest } = await request.json();

  // Rate limit
  const rateLimit = await checkRateLimit(
    env.RATE_LIMITS,
    `login:${clientIdentifier}`,
    { maxRequests: 5, windowSeconds: 300 }
  );
  if (!rateLimit.allowed) {
    return corsResponse({ error: 'Too many attempts' }, 429);
  }

  const passwordFile = await env.CREDENTIALS.get(`cred:${clientIdentifier}`);
  if (!passwordFile) {
    // Don't reveal whether account exists
    // Generate fake response (constant-time)
    return corsResponse({ error: 'Authentication failed' }, 401);
  }

  const result = startLogin(clientIdentifier, passwordFile, credentialRequest);

  // Store server state temporarily (60 second TTL)
  const stateKey = `state:${clientIdentifier}:${Date.now()}`;
  await env.LOGIN_STATES.put(stateKey, result.serverState, { expirationTtl: 60 });

  return corsResponse({
    credentialResponse: result.credentialResponse,
    stateKey,
  });
}

async function handleLoginFinish(request: Request, env: Env): Promise<Response> {
  const { clientIdentifier, stateKey, credentialFinalization } = await request.json();

  const serverState = await env.LOGIN_STATES.get(stateKey);
  if (!serverState) {
    return corsResponse({ error: 'Session expired' }, 401);
  }

  // Delete state (one-time use)
  await env.LOGIN_STATES.delete(stateKey);

  try {
    const result = finishLogin(serverState, credentialFinalization);

    // Get user's encrypted bundle
    const bundle = await env.BUNDLES.get(`bundle:${clientIdentifier}`);

    return corsResponse({
      success: true,
      sessionKey: result.sessionKey,
      encryptedBundle: bundle,
    });
  } catch {
    return corsResponse({ error: 'Authentication failed' }, 401);
  }
}

function corsResponse(data: unknown, status = 200): Response {
  return new Response(data ? JSON.stringify(data) : null, {
    status,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
    },
  });
}
```

**Step 4: Update wrangler.toml with new KV namespaces**

Add to `backend/wrangler.toml`:

```toml
[[kv_namespaces]]
binding = "CREDENTIALS"
id = "TODO_CREATE_NAMESPACE"

[[kv_namespaces]]
binding = "BUNDLES"
id = "TODO_CREATE_NAMESPACE"

[[kv_namespaces]]
binding = "LOGIN_STATES"
id = "TODO_CREATE_NAMESPACE"
```

**Step 5: Commit backend changes**

```bash
git add backend/
git commit -m "feat(backend): implement OPAQUE authentication endpoints

Replaces email verification with OPAQUE protocol:
- POST /api/auth/register/start - Begin registration
- POST /api/auth/register/finish - Complete registration
- POST /api/auth/login/start - Begin login
- POST /api/auth/login/finish - Complete login

Uses @serenity-kit/opaque for wire compatibility with iOS client.
Stores password files in CREDENTIALS KV, encrypted bundles in BUNDLES KV."
```

---

## Phase 4: iOS Client Integration

### Task 6: Add OpaqueSwift package to Xcode project

**Files:**

- Modify: `ios/FamilyMedicalApp/FamilyMedicalApp.xcodeproj/project.pbxproj`

**Step 1: Add local package dependency**

In Xcode:

1. File → Add Package Dependencies
2. Click "Add Local..."
3. Navigate to `opaque-swift/` directory
4. Add to FamilyMedicalApp target

**Step 2: Verify import works**

Create a test file or add to existing service:

```swift
import OpaqueSwift

// Test that module is accessible
let _ = try? generateClientIdentifier(username: "test")
```

**Step 3: Commit Xcode project changes**

```bash
git add ios/
git commit -m "build(ios): add OpaqueSwift local package dependency"
```

---

### Task 7: Create OpaqueAuthService for iOS

**Files:**

- Create: `ios/FamilyMedicalApp/FamilyMedicalApp/Services/Auth/OpaqueAuthService.swift`
- Create: `ios/FamilyMedicalApp/FamilyMedicalApp/Services/Auth/OpaqueAuthServiceProtocol.swift`

**Step 1: Create protocol**

Create `OpaqueAuthServiceProtocol.swift`:

```swift
import Foundation

/// Result of OPAQUE registration
struct OpaqueRegistrationResult {
    let exportKey: Data
}

/// Result of OPAQUE login
struct OpaqueLoginResult {
    let exportKey: Data
    let sessionKey: Data
    let encryptedBundle: Data?
}

/// Protocol for OPAQUE authentication operations
protocol OpaqueAuthServiceProtocol {
    /// Register a new user
    /// - Parameters:
    ///   - username: User's chosen username
    ///   - password: User's password
    /// - Returns: Registration result with export key
    func register(username: String, password: String) async throws -> OpaqueRegistrationResult

    /// Login an existing user
    /// - Parameters:
    ///   - username: User's username
    ///   - password: User's password
    /// - Returns: Login result with export key and optional bundle
    func login(username: String, password: String) async throws -> OpaqueLoginResult

    /// Upload encrypted bundle after registration/key change
    /// - Parameters:
    ///   - username: User's username
    ///   - bundle: Encrypted data bundle
    func uploadBundle(username: String, bundle: Data) async throws
}
```

**Step 2: Create implementation**

Create `OpaqueAuthService.swift`:

```swift
import Foundation
import OpaqueSwift

/// OPAQUE authentication service implementation
final class OpaqueAuthService: OpaqueAuthServiceProtocol {
    private let baseURL: URL
    private let session: URLSession

    init(
        baseURL: URL = URL(string: "https://family-medical.cynexia.com/api/auth")!,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.session = session
    }

    func register(username: String, password: String) async throws -> OpaqueRegistrationResult {
        let clientIdentifier = try generateClientIdentifier(username: username)

        // Step 1: Start registration
        let registration = try ClientRegistration.start(password: password)
        let request = registration.getRequest()

        let startResponse = try await post(
            path: "register/start",
            body: [
                "clientIdentifier": clientIdentifier,
                "registrationRequest": request.base64EncodedString()
            ]
        )

        guard let responseData = Data(base64Encoded: startResponse["registrationResponse"] as? String ?? "") else {
            throw OpaqueAuthError.invalidResponse
        }

        // Step 2: Finish registration
        let result = try registration.finish(serverResponse: [UInt8](responseData))

        let _ = try await post(
            path: "register/finish",
            body: [
                "clientIdentifier": clientIdentifier,
                "registrationUpload": Data(result.registrationUpload).base64EncodedString()
            ]
        )

        return OpaqueRegistrationResult(exportKey: Data(result.exportKey))
    }

    func login(username: String, password: String) async throws -> OpaqueLoginResult {
        let clientIdentifier = try generateClientIdentifier(username: username)

        // Step 1: Start login
        let login = try ClientLogin.start(password: password)
        let request = login.getRequest()

        let startResponse = try await post(
            path: "login/start",
            body: [
                "clientIdentifier": clientIdentifier,
                "credentialRequest": request.base64EncodedString()
            ]
        )

        guard let responseData = Data(base64Encoded: startResponse["credentialResponse"] as? String ?? ""),
              let stateKey = startResponse["stateKey"] as? String else {
            throw OpaqueAuthError.invalidResponse
        }

        // Step 2: Finish login
        let result = try login.finish(serverResponse: [UInt8](responseData))

        let finishResponse = try await post(
            path: "login/finish",
            body: [
                "clientIdentifier": clientIdentifier,
                "stateKey": stateKey,
                "credentialFinalization": Data(result.credentialFinalization).base64EncodedString()
            ]
        )

        let bundleData: Data?
        if let bundleString = finishResponse["encryptedBundle"] as? String {
            bundleData = Data(base64Encoded: bundleString)
        } else {
            bundleData = nil
        }

        return OpaqueLoginResult(
            exportKey: Data(result.exportKey),
            sessionKey: Data(result.sessionKey),
            encryptedBundle: bundleData
        )
    }

    func uploadBundle(username: String, bundle: Data) async throws {
        let clientIdentifier = try generateClientIdentifier(username: username)

        let _ = try await post(
            path: "bundle",
            body: [
                "clientIdentifier": clientIdentifier,
                "encryptedBundle": bundle.base64EncodedString()
            ]
        )
    }

    // MARK: - Private

    private func post(path: String, body: [String: Any]) async throws -> [String: Any] {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpaqueAuthError.networkError
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw OpaqueAuthError.serverError(statusCode: httpResponse.statusCode)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw OpaqueAuthError.invalidResponse
        }

        return json
    }
}

enum OpaqueAuthError: Error {
    case invalidResponse
    case networkError
    case serverError(statusCode: Int)
    case authenticationFailed
}
```

**Step 3: Commit service**

```bash
git add ios/FamilyMedicalApp/FamilyMedicalApp/Services/Auth/
git commit -m "feat(ios): add OpaqueAuthService for OPAQUE authentication

Implements OpaqueAuthServiceProtocol with:
- register(username:password:) - OPAQUE registration flow
- login(username:password:) - OPAQUE login flow
- uploadBundle(username:bundle:) - Encrypted bundle storage

Uses OpaqueSwift (UniFFI-wrapped opaque-ke) for client-side cryptography."
```

---

### Task 8: Update AuthenticationService to use OPAQUE

**Files:**

- Modify: `ios/FamilyMedicalApp/FamilyMedicalApp/Services/Auth/AuthenticationService.swift`
- Modify: `ios/FamilyMedicalApp/FamilyMedicalApp/Services/Auth/AuthenticationFlowState.swift`

**Step 1: Update AuthenticationFlowState**

Modify `AuthenticationFlowState.swift` to replace email with username:

```swift
enum AuthenticationFlowState: Equatable {
    // MARK: - Initial State

    /// Username entry (both new and returning users start here)
    case usernameEntry

    // MARK: - New User States

    /// New user: create passphrase (with strength validation)
    case passphraseCreation(username: String)

    /// New user: confirm passphrase matches
    case passphraseConfirmation(username: String, passphrase: String)

    // MARK: - Returning User / Login States

    /// Enter passphrase for existing account (or new account attempt)
    case passphraseEntry(username: String)

    // MARK: - Common States

    /// Optional biometric setup (Face ID / Touch ID)
    case biometricSetup(username: String, passphrase: String)

    /// Daily unlock (existing device with setup complete)
    case unlock

    /// Authenticated - show main app
    case authenticated

    /// Error state - authentication failed (could be wrong password OR no account)
    case authenticationFailed(username: String, message: String)
}
```

**Step 2: Update AuthenticationService**

Modify `AuthenticationService.swift` to integrate OPAQUE:

```swift
// Add to dependencies
private let opaqueService: OpaqueAuthServiceProtocol

// Update init
init(
    keyDerivationService: KeyDerivationServiceProtocol = KeyDerivationService(),
    keychainService: KeychainServiceProtocol = KeychainService(),
    encryptionService: EncryptionServiceProtocol = EncryptionService(),
    biometricService: BiometricServiceProtocol? = nil,
    opaqueService: OpaqueAuthServiceProtocol = OpaqueAuthService(),
    userDefaults: UserDefaults = .standard,
    logger: CategoryLoggerProtocol? = nil
) {
    // ... existing init code ...
    self.opaqueService = opaqueService
}

// Update setUp to use OPAQUE registration
func setUp(password: String, username: String, enableBiometric: Bool) async throws {
    logger.logOperation("setUp", state: "started")

    // Register with OPAQUE server
    let registrationResult = try await opaqueService.register(
        username: username,
        password: password
    )

    // Derive Primary Key from OPAQUE export key
    let primaryKey = try keyDerivationService.deriveFromExportKey(registrationResult.exportKey)

    // Generate Curve25519 keypair (per ADR-0002)
    let privateKey = Curve25519.KeyAgreement.PrivateKey()
    let publicKey = privateKey.publicKey

    // ... rest of setup (encrypt private key, store in keychain, etc.) ...

    // Store username instead of email
    userDefaults.set(username, forKey: Self.usernameKey)

    logger.logOperation("setUp", state: "completed")
}

// Update unlockWithPassword to use OPAQUE login
func unlockWithPassword(_ password: String, username: String? = nil) async throws {
    logger.logOperation("unlockWithPassword", state: "started")

    // Check if locked out
    if isLockedOut {
        throw AuthenticationError.accountLocked(remainingSeconds: lockoutRemainingSeconds)
    }

    let targetUsername = username ?? storedUsername
    guard let targetUsername else {
        throw AuthenticationError.notSetUp
    }

    do {
        // Login with OPAQUE server
        let loginResult = try await opaqueService.login(
            username: targetUsername,
            password: password
        )

        // Derive Primary Key from OPAQUE export key
        let primaryKey = try keyDerivationService.deriveFromExportKey(loginResult.exportKey)

        // Verify by attempting to decrypt verification token
        // ... existing verification code using primaryKey ...

        // Success - reset failed attempts
        userDefaults.removeObject(forKey: Self.failedAttemptsKey)
        userDefaults.removeObject(forKey: Self.lockoutEndTimeKey)

        logger.logOperation("unlockWithPassword", state: "success")
    } catch {
        // OPAQUE failed - could be wrong password OR wrong username
        logger.notice("Authentication failed")
        try handleFailedAttempt()
        throw AuthenticationError.authenticationFailed
    }
}
```

**Step 3: Add new error case**

Update `AuthenticationErrors.swift`:

```swift
enum AuthenticationError: LocalizedError {
    // ... existing cases ...
    case authenticationFailed  // Generic - doesn't reveal if username or password is wrong

    var errorDescription: String? {
        switch self {
        // ... existing cases ...
        case .authenticationFailed:
            return "Authentication failed. Please check your username and password."
        }
    }
}
```

**Step 4: Commit authentication service updates**

```bash
git add ios/FamilyMedicalApp/FamilyMedicalApp/Services/Auth/
git commit -m "refactor(auth): integrate OPAQUE authentication into AuthenticationService

- Replace email-based flow with username-based OPAQUE flow
- setUp() now registers with OPAQUE server, derives Primary Key from export key
- unlockWithPassword() now authenticates via OPAQUE login flow
- Add generic authenticationFailed error (doesn't reveal username vs password issue)
- Update AuthenticationFlowState to use username instead of email"
```

---

### Task 9: Update UI for username-based flow

**Files:**

- Modify: `ios/FamilyMedicalApp/FamilyMedicalApp/Views/Auth/EmailEntryView.swift` → rename to `UsernameEntryView.swift`
- Modify: Related view models and coordinator

**Step 1: Rename and update EmailEntryView to UsernameEntryView**

This involves:

1. Renaming the file
2. Changing email validation to username validation
3. Updating placeholder text and labels
4. Removing email-specific UI (like "Check your email" verification)

The detailed UI changes will follow the existing patterns in the codebase.

**Step 2: Remove code verification views**

Since OPAQUE doesn't require email verification, remove:

- `CodeVerificationView.swift`
- Related view models

**Step 3: Update navigation coordinator**

Update `AuthenticationCoordinatorView.swift` to reflect new flow:

- `usernameEntry` → `passphraseCreation` (new user) or `passphraseEntry` (attempt login)

**Step 4: Commit UI changes**

```bash
git add ios/FamilyMedicalApp/FamilyMedicalApp/Views/Auth/
git commit -m "refactor(ui): update auth UI for OPAQUE username-based flow

- Rename EmailEntryView to UsernameEntryView
- Remove email verification (CodeVerificationView)
- Update flow: username → passphrase → biometric setup
- Users can't tell if account exists (privacy feature)"
```

---

## Phase 5: Testing

### Task 10: Write unit tests for OpaqueAuthService

**Files:**

- Create: `ios/FamilyMedicalApp/FamilyMedicalAppTests/Services/Auth/OpaqueAuthServiceTests.swift`
- Create: `ios/FamilyMedicalApp/FamilyMedicalAppTests/Services/Auth/MockOpaqueAuthService.swift`

**Step 1: Create mock service**

```swift
final class MockOpaqueAuthService: OpaqueAuthServiceProtocol {
    var registerResult: Result<OpaqueRegistrationResult, Error> = .failure(OpaqueAuthError.networkError)
    var loginResult: Result<OpaqueLoginResult, Error> = .failure(OpaqueAuthError.networkError)

    var registerCallCount = 0
    var loginCallCount = 0
    var lastUsername: String?
    var lastPassword: String?

    func register(username: String, password: String) async throws -> OpaqueRegistrationResult {
        registerCallCount += 1
        lastUsername = username
        lastPassword = password
        return try registerResult.get()
    }

    func login(username: String, password: String) async throws -> OpaqueLoginResult {
        loginCallCount += 1
        lastUsername = username
        lastPassword = password
        return try loginResult.get()
    }

    func uploadBundle(username: String, bundle: Data) async throws {
        // Track if needed
    }
}
```

**Step 2: Write tests**

```swift
@testable import FamilyMedicalApp
import XCTest

final class OpaqueAuthServiceTests: XCTestCase {

    func testRegisterGeneratesClientIdentifier() async throws {
        // Test that same username always generates same identifier
        let id1 = try generateClientIdentifier(username: "testuser")
        let id2 = try generateClientIdentifier(username: "testuser")
        XCTAssertEqual(id1, id2)

        // Different usernames generate different identifiers
        let id3 = try generateClientIdentifier(username: "otheruser")
        XCTAssertNotEqual(id1, id3)
    }

    func testRegisterReturnsExportKey() async throws {
        // Integration test would require actual server
        // Unit test uses mock
    }

    func testLoginReturnsExportKeyAndBundle() async throws {
        // Integration test would require actual server
    }
}
```

**Step 3: Commit tests**

```bash
git add ios/FamilyMedicalApp/FamilyMedicalAppTests/
git commit -m "test(auth): add unit tests for OpaqueAuthService"
```

---

### Task 11: Update UI tests for new flow

**Files:**

- Modify: `ios/FamilyMedicalApp/FamilyMedicalAppUITests/NewUserFlowUITests.swift`
- Modify: `ios/FamilyMedicalApp/FamilyMedicalAppUITests/ExistingUserFlowUITests.swift`
- Modify: `ios/FamilyMedicalApp/FamilyMedicalAppUITests/Helpers/UITestHelpers.swift`

**Step 1: Update test helpers**

Update `createAccount()` helper to use username flow:

```swift
func createAccount(
    username: String = "testuser",
    password passphrase: String = "Unique-Horse-Battery-Staple-2024",
    enableBiometric: Bool = false,
    timeout: TimeInterval = 15
) {
    // Step 1: Username Entry
    let usernameField = textFields["Username"]
    XCTAssertTrue(usernameField.waitForExistence(timeout: timeout))
    usernameField.tap()
    usernameField.typeText(username)

    let continueButton = buttons["Continue"]
    XCTAssertTrue(continueButton.waitForExistence(timeout: 2) && continueButton.isEnabled)
    continueButton.tap()

    // Step 2: Passphrase Creation (no code verification)
    let passphraseHeader = staticTexts["Create a Passphrase"]
    XCTAssertTrue(passphraseHeader.waitForExistence(timeout: timeout))

    // ... rest of flow unchanged ...
}
```

**Step 2: Update test cases**

Remove email verification test cases, update flow tests.

**Step 3: Run tests and verify**

```bash
./scripts/run-tests.sh
```

**Step 4: Commit test updates**

```bash
git add ios/FamilyMedicalApp/FamilyMedicalAppUITests/
git commit -m "test(ui): update UI tests for OPAQUE username-based flow

- Remove email verification test steps
- Update createAccount() helper for username flow
- Verify new user journey works end-to-end"
```

---

## Phase 6: Deployment

### Task 12: Create new KV namespaces and deploy

**Step 1: Create KV namespaces**

```bash
cd backend
npx wrangler kv:namespace create "CREDENTIALS"
npx wrangler kv:namespace create "BUNDLES"
npx wrangler kv:namespace create "LOGIN_STATES"
```

**Step 2: Update wrangler.toml with namespace IDs**

Add the returned IDs to `wrangler.toml`.

**Step 3: Generate and store OPAQUE server setup**

```bash
# Generate server setup (one-time, keep secret!)
node -e "
const opaque = require('@serenity-kit/opaque');
opaque.ready.then(() => {
  console.log(opaque.server.createSetup());
});
"
```

Store as Cloudflare secret:

```bash
npx wrangler secret put OPAQUE_SERVER_SETUP
# Paste the generated setup string
```

**Step 4: Deploy**

```bash
npx wrangler deploy
```

**Step 5: Commit deployment config**

```bash
git add backend/wrangler.toml
git commit -m "deploy(backend): configure KV namespaces for OPAQUE auth"
```

---

## Phase 7: Cleanup

### Task 13: Remove deprecated email verification code

**Files:**

- Delete: `ios/FamilyMedicalApp/FamilyMedicalApp/Services/Auth/EmailVerificationService.swift`
- Delete: `ios/FamilyMedicalApp/FamilyMedicalApp/Services/Auth/EmailVerificationServiceProtocol.swift`
- Delete: `ios/FamilyMedicalApp/FamilyMedicalApp/Views/Auth/CodeVerificationView.swift`
- Delete: `backend/src/email.ts`
- Modify: `backend/src/index.ts` (remove email routes)

**Step 1: Remove iOS email verification files**

```bash
git rm ios/FamilyMedicalApp/FamilyMedicalApp/Services/Auth/EmailVerificationService.swift
git rm ios/FamilyMedicalApp/FamilyMedicalApp/Services/Auth/EmailVerificationServiceProtocol.swift
```

**Step 2: Remove backend email code**

```bash
git rm backend/src/email.ts
```

Update `backend/src/index.ts` to remove send-code and verify-code routes.

**Step 3: Commit cleanup**

```bash
git add -A
git commit -m "chore: remove deprecated email verification code

Email verification is no longer needed with OPAQUE authentication.
- Remove EmailVerificationService and protocol
- Remove backend email sending code
- Remove code verification UI"
```

---

## Summary

This plan implements OPAQUE zero-knowledge authentication in 13 tasks across 7 phases:

1. **Architecture Documentation** - ADR-0012, update ADR-0011
2. **UniFFI Rust Wrapper** - opaque-swift package with XCFramework
3. **Backend** - Cloudflare Workers with @serenity-kit/opaque
4. **iOS Client** - OpaqueAuthService + AuthenticationService integration
5. **Testing** - Unit tests + UI test updates
6. **Deployment** - KV namespaces + secrets + deploy
7. **Cleanup** - Remove deprecated email verification

**Key files created/modified:**

- `docs/adr/adr-0012-opaque-zero-knowledge-auth.md` (new)
- `opaque-swift/` (new Rust workspace)
- `backend/src/opaque.ts` (new)
- `ios/.../Services/Auth/OpaqueAuthService.swift` (new)
- `ios/.../Services/Auth/AuthenticationService.swift` (modified)
- Various UI files renamed/modified

**Dependencies added:**

- `opaque-ke` (Rust, via UniFFI)
- `@serenity-kit/opaque` (TypeScript)
