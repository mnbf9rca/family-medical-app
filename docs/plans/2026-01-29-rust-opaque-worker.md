# Rust OPAQUE Worker Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the broken TypeScript OPAQUE backend with a Rust-based Cloudflare Worker using `opaque-ke` v4, ensuring protocol compatibility between iOS client and server.

**Architecture:** A new Rust Worker using `workers-rs` will handle OPAQUE authentication endpoints. Both the iOS client (via OpaqueSwift) and the Rust Worker will use `opaque-ke` v4 with identical cipher suite configuration, ensuring cryptographic compatibility. The existing KV namespaces and Secrets Store bindings will be reused.

**Tech Stack:** Rust, workers-rs, opaque-ke v4, wasm-bindgen, Cloudflare KV, Cloudflare Secrets Store

---

## Background

The TypeScript backend using `@serenity-kit/opaque` fails on Cloudflare Workers because the library uses dynamic WASM compilation (`WebAssembly.compile()` at runtime), which Workers blocks for security reasons. The solution is to use Rust directly with `opaque-ke`, which compiles to WASM ahead of time.

**Key insight:** Both iOS (via UniFFI) and Workers (via wasm-bindgen) will use the same `opaque-ke` Rust crate, guaranteeing protocol compatibility.

## Critical Configuration

### Cipher Suite (MUST match exactly on client and server)

```rust
use opaque_ke::{CipherSuite, Ristretto255, TripleDh};

struct DefaultCipherSuite;

impl CipherSuite for DefaultCipherSuite {
    type OprfCs = Ristretto255;
    type KeGroup = Ristretto255;
    type KeyExchange = TripleDh<Ristretto255, sha2::Sha512>;
    type Ksf = argon2::Argon2<'static>;
}
```

### Breaking Changes in opaque-ke v4

1. `TripleDh` now requires explicit hash type: `TripleDh<Ristretto255, sha2::Sha512>`
2. `Ksf` trait changes - verify Argon2 integration still works
3. Message serialization format may have changed - test thoroughly

---

## Task 1: Create Rust Worker Project Structure

**Files:**

- Create: `backend-rust/Cargo.toml`
- Create: `backend-rust/src/lib.rs`
- Create: `backend-rust/wrangler.toml`
- Create: `backend-rust/.cargo/config.toml`

**Step 1: Create project directory**

```bash
mkdir -p backend-rust/src backend-rust/.cargo
```

**Step 2: Create Cargo.toml**

Create `backend-rust/Cargo.toml`:

```toml
[package]
name = "recordwell-opaque-worker"
version = "0.1.0"
edition = "2021"
description = "OPAQUE authentication worker for RecordWell"

[lib]
crate-type = ["cdylib"]

[dependencies]
worker = "0.4"
worker-macros = "0.4"
opaque-ke = { version = "4", features = ["argon2"] }
argon2 = "0.5"
sha2 = "0.10"
rand = { version = "0.8", features = ["getrandom"] }
getrandom = { version = "0.2", features = ["js"] }
base64 = "0.22"
serde = { version = "1", features = ["derive"] }
serde_json = "1"
hex = "0.4"
console_error_panic_hook = "0.1"

[profile.release]
opt-level = "s"
lto = true
```

**Step 3: Create .cargo/config.toml**

Create `backend-rust/.cargo/config.toml`:

```toml
[build]
target = "wasm32-unknown-unknown"

[target.wasm32-unknown-unknown]
rustflags = ["-C", "target-feature=+simd128"]
```

**Step 4: Create wrangler.toml**

Create `backend-rust/wrangler.toml`:

```toml
name = "recordwell-opaque"
main = "build/worker/shim.mjs"
compatibility_date = "2024-01-01"

[build]
command = "cargo install -q worker-build && worker-build --release"

# KV Namespaces - OPAQUE Authentication
[[kv_namespaces]]
binding = "CREDENTIALS"
id = "c0373f3b95e54fbeaaef36782d426ca3"

[[kv_namespaces]]
binding = "BUNDLES"
id = "7967763b05c9496e89c4223fd765a34d"

[[kv_namespaces]]
binding = "LOGIN_STATES"
id = "671b81ebdc2946e494d0d37c2059f9d6"

[[kv_namespaces]]
binding = "RATE_LIMITS"
id = "5d519620a3c341bc8821fc568ce67beb"

[vars]
ENVIRONMENT = "production"

[observability]
enabled = true

[observability.logs]
enabled = true
invocation_logs = true

# Secrets Store binding for OPAQUE server setup
[[secrets_store_secrets]]
binding = "OPAQUE_SERVER_SETUP"
secret_name = "recordwell_OPAQUE_SERVER_SETUP"
store_id = "9ff53e3094b54ddeb4de44cfa3471119"
```

**Step 5: Create minimal lib.rs stub**

Create `backend-rust/src/lib.rs`:

```rust
use worker::*;

#[event(fetch)]
async fn main(req: Request, env: Env, _ctx: Context) -> Result<Response> {
    console_error_panic_hook::set_once();

    Response::ok("RecordWell OPAQUE Worker - Under Construction")
}
```

**Step 6: Verify it compiles**

Run: `cd backend-rust && cargo check --target wasm32-unknown-unknown`
Expected: Successful compilation (may have warnings)

**Step 7: Commit**

```bash
git add backend-rust/
git commit -m "feat(backend-rust): scaffold Rust OPAQUE worker project"
```

---

## Task 2: Implement OPAQUE Cipher Suite and Server Setup

**Files:**

- Create: `backend-rust/src/opaque.rs`
- Modify: `backend-rust/src/lib.rs`

**Step 1: Create opaque.rs with cipher suite**

Create `backend-rust/src/opaque.rs`:

```rust
use opaque_ke::{
    CipherSuite, Ristretto255,
    ServerSetup, ServerRegistration, ServerLogin,
    RegistrationRequest, RegistrationResponse, RegistrationUpload,
    CredentialRequest, CredentialResponse, CredentialFinalization,
    ServerLoginStartResult,
    keypair::KeyPair,
    errors::ProtocolError,
};
use argon2::Argon2;
use sha2::Sha512;
use rand::rngs::OsRng;

/// Cipher suite matching iOS OpaqueSwift configuration
/// MUST be identical to client for protocol compatibility
pub struct DefaultCipherSuite;

impl CipherSuite for DefaultCipherSuite {
    type OprfCs = Ristretto255;
    type KeGroup = Ristretto255;
    type KeyExchange = opaque_ke::key_exchange::tripledh::TripleDh;
    type Ksf = Argon2<'static>;
}

pub type OpaqueServerSetup = ServerSetup<DefaultCipherSuite>;
pub type OpaqueServerRegistration = ServerRegistration<DefaultCipherSuite>;
pub type OpaqueServerLogin = ServerLogin<DefaultCipherSuite>;

/// Initialize server setup from stored secret or generate new
pub fn init_server_setup(stored: Option<&str>) -> Result<OpaqueServerSetup, String> {
    match stored {
        Some(b64) => {
            let bytes = base64::Engine::decode(
                &base64::engine::general_purpose::STANDARD,
                b64
            ).map_err(|e| format!("Failed to decode server setup: {}", e))?;

            OpaqueServerSetup::deserialize(&bytes)
                .map_err(|_| "Failed to deserialize server setup".to_string())
        }
        None => {
            let mut rng = OsRng;
            Ok(OpaqueServerSetup::new(&mut rng))
        }
    }
}

/// Serialize server setup for storage
pub fn serialize_server_setup(setup: &OpaqueServerSetup) -> String {
    base64::Engine::encode(&base64::engine::general_purpose::STANDARD, setup.serialize())
}

#[derive(Debug)]
pub struct RegistrationStartResult {
    pub response: Vec<u8>,
}

/// Start registration - process client's registration request
pub fn start_registration(
    server_setup: &OpaqueServerSetup,
    client_identifier: &[u8],
    registration_request: &[u8],
) -> Result<RegistrationStartResult, String> {
    let request = RegistrationRequest::<DefaultCipherSuite>::deserialize(registration_request)
        .map_err(|_| "Failed to deserialize registration request")?;

    let result = OpaqueServerRegistration::start(
        server_setup,
        request,
        client_identifier,
    ).map_err(|_| "Failed to start registration")?;

    Ok(RegistrationStartResult {
        response: result.message.serialize().to_vec(),
    })
}

#[derive(Debug)]
pub struct LoginStartResult {
    pub response: Vec<u8>,
    pub state: Vec<u8>,
}

/// Start login - process client's credential request
pub fn start_login(
    server_setup: &OpaqueServerSetup,
    client_identifier: &[u8],
    password_file: &[u8],
    credential_request: &[u8],
) -> Result<LoginStartResult, String> {
    let request = CredentialRequest::<DefaultCipherSuite>::deserialize(credential_request)
        .map_err(|_| "Failed to deserialize credential request")?;

    let password = RegistrationUpload::<DefaultCipherSuite>::deserialize(password_file)
        .map_err(|_| "Failed to deserialize password file")?;

    let mut rng = OsRng;
    let result = OpaqueServerLogin::start(
        &mut rng,
        server_setup,
        Some(password),
        request,
        client_identifier,
        ServerLoginStartParameters::default(),
    ).map_err(|_| "Failed to start login")?;

    Ok(LoginStartResult {
        response: result.message.serialize().to_vec(),
        state: result.state.serialize().to_vec(),
    })
}

#[derive(Debug)]
pub struct LoginFinishResult {
    pub session_key: Vec<u8>,
}

/// Finish login - verify client's credential finalization
pub fn finish_login(
    server_state: &[u8],
    credential_finalization: &[u8],
) -> Result<LoginFinishResult, String> {
    let state = OpaqueServerLogin::deserialize(server_state)
        .map_err(|_| "Failed to deserialize server state")?;

    let finalization = CredentialFinalization::<DefaultCipherSuite>::deserialize(credential_finalization)
        .map_err(|_| "Failed to deserialize credential finalization")?;

    let result = state.finish(finalization)
        .map_err(|_| "Login verification failed")?;

    Ok(LoginFinishResult {
        session_key: result.session_key.to_vec(),
    })
}
```

**Step 2: Update lib.rs to use opaque module**

Add to `backend-rust/src/lib.rs`:

```rust
mod opaque;

use worker::*;

#[event(fetch)]
async fn main(req: Request, env: Env, _ctx: Context) -> Result<Response> {
    console_error_panic_hook::set_once();

    // Test that opaque module compiles
    Response::ok("RecordWell OPAQUE Worker - Opaque module loaded")
}
```

**Step 3: Verify compilation**

Run: `cd backend-rust && cargo check --target wasm32-unknown-unknown`
Expected: Successful compilation

**Step 4: Commit**

```bash
git add backend-rust/src/
git commit -m "feat(backend-rust): implement OPAQUE cipher suite and core functions"
```

---

## Task 3: Implement HTTP Route Handlers

**Files:**

- Create: `backend-rust/src/routes.rs`
- Modify: `backend-rust/src/lib.rs`

**Step 1: Create routes.rs**

Create `backend-rust/src/routes.rs`:

```rust
use serde::{Deserialize, Serialize};
use worker::*;
use crate::opaque;

// Request/Response types
#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct RegisterStartRequest {
    pub client_identifier: String,
    pub registration_request: String, // base64
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct RegisterStartResponse {
    pub registration_response: String, // base64
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct RegisterFinishRequest {
    pub client_identifier: String,
    pub registration_record: String, // base64
    pub encrypted_bundle: Option<String>,
}

#[derive(Serialize)]
pub struct SuccessResponse {
    pub success: bool,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct LoginStartRequest {
    pub client_identifier: String,
    pub start_login_request: String, // base64
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct LoginStartResponse {
    pub login_response: String, // base64
    pub state_key: String,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct LoginFinishRequest {
    pub client_identifier: String,
    pub state_key: String,
    pub finish_login_request: String, // base64
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct LoginFinishResponse {
    pub success: bool,
    pub session_key: String,
    pub encrypted_bundle: Option<String>,
}

#[derive(Serialize)]
pub struct ErrorResponse {
    pub error: String,
}

use base64::{Engine, engine::general_purpose::STANDARD as BASE64};

pub async fn handle_register_start(
    mut req: Request,
    env: &Env,
    server_setup: &opaque::OpaqueServerSetup,
) -> Result<Response> {
    let body: RegisterStartRequest = req.json().await?;

    // Validate client identifier (64 hex chars = 32 bytes SHA256)
    if body.client_identifier.len() != 64 {
        return json_response(&ErrorResponse { error: "Invalid clientIdentifier".into() }, 400);
    }

    let request_bytes = BASE64.decode(&body.registration_request)
        .map_err(|_| Error::from("Invalid base64 in registrationRequest"))?;

    let result = opaque::start_registration(
        server_setup,
        body.client_identifier.as_bytes(),
        &request_bytes,
    ).map_err(|e| Error::from(e))?;

    json_response(&RegisterStartResponse {
        registration_response: BASE64.encode(&result.response),
    }, 200)
}

pub async fn handle_register_finish(
    mut req: Request,
    env: &Env,
) -> Result<Response> {
    let body: RegisterFinishRequest = req.json().await?;

    if body.client_identifier.len() != 64 {
        return json_response(&ErrorResponse { error: "Invalid clientIdentifier".into() }, 400);
    }

    let credentials = env.kv("CREDENTIALS")?;
    let key = format!("cred:{}", body.client_identifier);

    // Check if user already exists
    if credentials.get(&key).text().await?.is_some() {
        return json_response(&ErrorResponse { error: "Registration failed".into() }, 400);
    }

    // Store the registration record as the password file
    credentials.put(&key, &body.registration_record)?.execute().await?;

    // Store initial bundle if provided
    if let Some(bundle) = body.encrypted_bundle {
        let bundles = env.kv("BUNDLES")?;
        bundles.put(&format!("bundle:{}", body.client_identifier), &bundle)?
            .execute().await?;
    }

    console_log!("[opaque/register/finish] Registered user: {}...", &body.client_identifier[..8]);

    json_response(&SuccessResponse { success: true }, 200)
}

pub async fn handle_login_start(
    mut req: Request,
    env: &Env,
    server_setup: &opaque::OpaqueServerSetup,
) -> Result<Response> {
    let body: LoginStartRequest = req.json().await?;

    if body.client_identifier.len() != 64 {
        return json_response(&ErrorResponse { error: "Invalid clientIdentifier".into() }, 400);
    }

    // Get password file
    let credentials = env.kv("CREDENTIALS")?;
    let key = format!("cred:{}", body.client_identifier);

    let password_file_b64 = match credentials.get(&key).text().await? {
        Some(pf) => pf,
        None => {
            console_log!("[opaque/login/start] Unknown user: {}...", &body.client_identifier[..8]);
            return json_response(&ErrorResponse { error: "Authentication failed".into() }, 401);
        }
    };

    let password_file = BASE64.decode(&password_file_b64)
        .map_err(|_| Error::from("Corrupted password file"))?;

    let request_bytes = BASE64.decode(&body.start_login_request)
        .map_err(|_| Error::from("Invalid base64 in startLoginRequest"))?;

    let result = opaque::start_login(
        server_setup,
        body.client_identifier.as_bytes(),
        &password_file,
        &request_bytes,
    ).map_err(|e| Error::from(e))?;

    // Store server state temporarily (60 second TTL)
    let login_states = env.kv("LOGIN_STATES")?;
    let state_key = format!("state:{}:{}", body.client_identifier, Date::now().as_millis());

    login_states.put(&state_key, BASE64.encode(&result.state))?
        .expiration_ttl(60)
        .execute().await?;

    json_response(&LoginStartResponse {
        login_response: BASE64.encode(&result.response),
        state_key,
    }, 200)
}

pub async fn handle_login_finish(
    mut req: Request,
    env: &Env,
) -> Result<Response> {
    let body: LoginFinishRequest = req.json().await?;

    if body.client_identifier.len() != 64 {
        return json_response(&ErrorResponse { error: "Invalid clientIdentifier".into() }, 400);
    }

    // Get and delete server state (one-time use)
    let login_states = env.kv("LOGIN_STATES")?;

    let server_state_b64 = match login_states.get(&body.state_key).text().await? {
        Some(s) => s,
        None => {
            return json_response(&ErrorResponse { error: "Session expired".into() }, 401);
        }
    };

    login_states.delete(&body.state_key).await?;

    let server_state = BASE64.decode(&server_state_b64)
        .map_err(|_| Error::from("Corrupted server state"))?;

    let finalization_bytes = BASE64.decode(&body.finish_login_request)
        .map_err(|_| Error::from("Invalid base64 in finishLoginRequest"))?;

    let result = match opaque::finish_login(&server_state, &finalization_bytes) {
        Ok(r) => r,
        Err(_) => {
            console_log!("[opaque/login/finish] Failed verification: {}...", &body.client_identifier[..8]);
            return json_response(&ErrorResponse { error: "Authentication failed".into() }, 401);
        }
    };

    // Get user's encrypted bundle
    let bundles = env.kv("BUNDLES")?;
    let encrypted_bundle = bundles.get(&format!("bundle:{}", body.client_identifier))
        .text().await?;

    console_log!("[opaque/login/finish] Successful login: {}...", &body.client_identifier[..8]);

    json_response(&LoginFinishResponse {
        success: true,
        session_key: BASE64.encode(&result.session_key),
        encrypted_bundle,
    }, 200)
}

fn json_response<T: Serialize>(data: &T, status: u16) -> Result<Response> {
    let body = serde_json::to_string(data)?;
    let mut headers = Headers::new();
    headers.set("Content-Type", "application/json")?;
    headers.set("Access-Control-Allow-Origin", "*")?;

    Ok(Response::from_body(ResponseBody::Body(body.into_bytes()))
        .unwrap()
        .with_status(status)
        .with_headers(headers))
}
```

**Step 2: Update lib.rs with routing**

Replace `backend-rust/src/lib.rs`:

```rust
mod opaque;
mod routes;

use worker::*;

#[event(fetch)]
async fn main(req: Request, env: Env, _ctx: Context) -> Result<Response> {
    console_error_panic_hook::set_once();

    // Handle CORS preflight
    if req.method() == Method::Options {
        return cors_preflight();
    }

    // Initialize OPAQUE server setup from secret
    let setup_secret = env.secret("OPAQUE_SERVER_SETUP")?.to_string();
    let server_setup = opaque::init_server_setup(Some(&setup_secret))
        .map_err(|e| Error::from(e))?;

    let path = req.path();

    match (req.method(), path.as_str()) {
        (Method::Post, "/auth/opaque/register/start") => {
            routes::handle_register_start(req, &env, &server_setup).await
        }
        (Method::Post, "/auth/opaque/register/finish") => {
            routes::handle_register_finish(req, &env).await
        }
        (Method::Post, "/auth/opaque/login/start") => {
            routes::handle_login_start(req, &env, &server_setup).await
        }
        (Method::Post, "/auth/opaque/login/finish") => {
            routes::handle_login_finish(req, &env).await
        }
        _ => {
            Response::error("Not found", 404)
        }
    }
}

fn cors_preflight() -> Result<Response> {
    let mut headers = Headers::new();
    headers.set("Access-Control-Allow-Origin", "*")?;
    headers.set("Access-Control-Allow-Methods", "POST, OPTIONS")?;
    headers.set("Access-Control-Allow-Headers", "Content-Type")?;
    headers.set("Access-Control-Max-Age", "86400")?;

    Ok(Response::empty()?.with_headers(headers))
}
```

**Step 3: Verify compilation**

Run: `cd backend-rust && cargo check --target wasm32-unknown-unknown`
Expected: Successful compilation

**Step 4: Commit**

```bash
git add backend-rust/src/
git commit -m "feat(backend-rust): implement OPAQUE HTTP route handlers"
```

---

## Task 4: Update OpaqueSwift to opaque-ke v4

**Files:**

- Modify: `opaque-swift/Cargo.toml`
- Modify: `opaque-swift/src/lib.rs`

**Step 1: Update Cargo.toml**

Edit `opaque-swift/Cargo.toml` to use opaque-ke v4:

```toml
[dependencies]
opaque-ke = { version = "4", features = ["argon2"] }
```

**Step 2: Update lib.rs for v4 API changes**

Update the cipher suite in `opaque-swift/src/lib.rs`:

```rust
use opaque_ke::{
    ClientRegistration as OpaqueClientRegistration,
    ClientLogin as OpaqueClientLogin,
    ClientRegistrationFinishParameters,
    ClientLoginFinishParameters,
    RegistrationResponse,
    CredentialResponse,
    CipherSuite,
    Ristretto255,
    rand::rngs::OsRng,
};

/// Cipher suite matching backend Rust worker configuration
/// Ristretto255 + TripleDH + Argon2
struct DefaultCipherSuite;

impl CipherSuite for DefaultCipherSuite {
    type OprfCs = Ristretto255;
    type KeGroup = Ristretto255;
    type KeyExchange = opaque_ke::key_exchange::tripledh::TripleDh;
    type Ksf = argon2::Argon2<'static>;
}
```

**Step 3: Verify compilation**

Run: `cd opaque-swift && cargo check`
Expected: Successful compilation

**Step 4: Rebuild XCFramework**

Run: `cd opaque-swift && ./build-xcframework.sh`
Expected: Successful build of OpaqueSwift.xcframework

**Step 5: Run iOS tests to verify OpaqueSwift still works**

Run: `./scripts/run-tests.sh`
Expected: All tests pass

**Step 6: Commit**

```bash
git add opaque-swift/
git commit -m "feat(opaque-swift): upgrade to opaque-ke v4"
```

---

## Task 5: Fix Compilation Issues and Test Locally

**Files:**

- Potentially modify: `backend-rust/src/opaque.rs`
- Potentially modify: `backend-rust/src/routes.rs`

**Step 1: Attempt full build**

Run: `cd backend-rust && cargo build --release --target wasm32-unknown-unknown`
Expected: May have compilation errors related to v4 API changes

**Step 2: Fix any API incompatibilities**

Common v4 issues to check:

- `TripleDh` generic parameter changes
- `ServerLoginStartParameters` might be needed
- Serialization/deserialization method names
- Import paths may have changed

**Step 3: Run wrangler dev for local testing**

Run: `cd backend-rust && wrangler dev`
Expected: Local worker starts on localhost:8787

**Step 4: Test with curl**

```bash
# Test 404 response
curl -X GET http://localhost:8787/

# Test register/start (will fail without valid OPAQUE data, but should return 400 not 500)
curl -X POST http://localhost:8787/auth/opaque/register/start \
  -H "Content-Type: application/json" \
  -d '{"clientIdentifier":"invalid","registrationRequest":"test"}'
```

Expected: Proper error responses, no 500s

**Step 5: Commit any fixes**

```bash
git add backend-rust/
git commit -m "fix(backend-rust): resolve opaque-ke v4 API compatibility"
```

---

## Task 6: Migrate Server Setup Secret Format

**Background:** The current OPAQUE_SERVER_SETUP secret was generated by `@serenity-kit/opaque` and may not be compatible with `opaque-ke` v4's `ServerSetup` format. We need to generate a new server setup.

**Files:**

- Create: `backend-rust/scripts/generate-server-setup.rs` (optional, can use cargo run)

**Step 1: Create a tool to generate new server setup**

Create `backend-rust/src/bin/generate_setup.rs`:

```rust
use opaque_ke::{CipherSuite, Ristretto255, ServerSetup};
use argon2::Argon2;
use rand::rngs::OsRng;
use base64::{Engine, engine::general_purpose::STANDARD as BASE64};

struct DefaultCipherSuite;

impl CipherSuite for DefaultCipherSuite {
    type OprfCs = Ristretto255;
    type KeGroup = Ristretto255;
    type KeyExchange = opaque_ke::key_exchange::tripledh::TripleDh;
    type Ksf = Argon2<'static>;
}

fn main() {
    let mut rng = OsRng;
    let setup = ServerSetup::<DefaultCipherSuite>::new(&mut rng);
    let serialized = setup.serialize();
    let b64 = BASE64.encode(&serialized);

    println!("New OPAQUE Server Setup (base64):");
    println!("{}", b64);
    println!("\nStore this as OPAQUE_SERVER_SETUP secret in Cloudflare");
}
```

**Step 2: Add binary target to Cargo.toml**

Add to `backend-rust/Cargo.toml`:

```toml
[[bin]]
name = "generate_setup"
path = "src/bin/generate_setup.rs"
```

**Step 3: Generate new server setup**

Run: `cd backend-rust && cargo run --bin generate_setup`
Expected: Outputs base64-encoded server setup

**Step 4: Update Cloudflare secret**

```bash
# Store the new secret (replace YOUR_NEW_SETUP with the generated value)
wrangler secret put OPAQUE_SERVER_SETUP
# Paste the generated base64 value when prompted
```

**Step 5: Commit**

```bash
git add backend-rust/
git commit -m "feat(backend-rust): add server setup generation tool"
```

**⚠️ IMPORTANT:** Changing the server setup will invalidate ALL existing user registrations. For a fresh deployment this is fine, but for production migrations you'd need a more complex strategy.

---

## Task 7: Deploy Rust Worker

**Files:**

- None (deployment only)

**Step 1: Build release**

Run: `cd backend-rust && cargo build --release --target wasm32-unknown-unknown`
Expected: Successful build

**Step 2: Deploy with wrangler**

Run: `cd backend-rust && wrangler deploy`
Expected: Successful deployment to Cloudflare

**Step 3: Verify deployment**

```bash
# Test the deployed worker
curl -X POST https://api.recordwell.app/auth/opaque/login/start \
  -H "Content-Type: application/json" \
  -d '{"clientIdentifier":"0000000000000000000000000000000000000000000000000000000000000000","startLoginRequest":"dGVzdA=="}'
```

Expected: 401 "Authentication failed" (user doesn't exist) - NOT a 500 error

**Step 4: Commit any deployment config changes**

```bash
git add backend-rust/wrangler.toml
git commit -m "chore(backend-rust): finalize deployment configuration"
```

---

## Task 8: Create Integration Smoke Tests

**Files:**

- Create: `backend-rust/tests/smoke_test.sh`

**Step 1: Create smoke test script**

Create `backend-rust/tests/smoke_test.sh`:

```bash
#!/bin/bash
set -e

BASE_URL="${1:-https://api.recordwell.app}"

echo "Testing OPAQUE endpoints at $BASE_URL"

# Test CORS preflight
echo -n "OPTIONS /auth/opaque/register/start... "
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X OPTIONS "$BASE_URL/auth/opaque/register/start")
[ "$STATUS" = "200" ] && echo "OK" || { echo "FAIL ($STATUS)"; exit 1; }

# Test invalid client identifier
echo -n "POST /auth/opaque/register/start (invalid)... "
RESPONSE=$(curl -s -X POST "$BASE_URL/auth/opaque/register/start" \
  -H "Content-Type: application/json" \
  -d '{"clientIdentifier":"short","registrationRequest":"dGVzdA=="}')
echo "$RESPONSE" | grep -q '"error"' && echo "OK (got error)" || { echo "FAIL"; exit 1; }

# Test unknown user login
echo -n "POST /auth/opaque/login/start (unknown user)... "
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/auth/opaque/login/start" \
  -H "Content-Type: application/json" \
  -d '{"clientIdentifier":"0000000000000000000000000000000000000000000000000000000000000000","startLoginRequest":"dGVzdA=="}')
[ "$STATUS" = "401" ] && echo "OK (401)" || { echo "FAIL ($STATUS)"; exit 1; }

# Test 404
echo -n "GET /nonexistent... "
STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/nonexistent")
[ "$STATUS" = "404" ] && echo "OK (404)" || { echo "FAIL ($STATUS)"; exit 1; }

echo ""
echo "All smoke tests passed!"
```

**Step 2: Make executable and test**

Run: `chmod +x backend-rust/tests/smoke_test.sh && ./backend-rust/tests/smoke_test.sh`
Expected: All tests pass

**Step 3: Commit**

```bash
git add backend-rust/tests/
git commit -m "test(backend-rust): add deployment smoke tests"
```

---

## Task 9: Run Full iOS Test Suite

**Files:**

- None (testing only)

**Step 1: Run iOS tests**

Run: `./scripts/run-tests.sh`
Expected: All tests pass

**Step 2: Check coverage**

Run: `./scripts/check-coverage.sh`
Expected: Coverage meets thresholds (90% overall, 85% per file)

**Step 3: Test in simulator manually**

1. Open Xcode: `open ios/FamilyMedicalApp/FamilyMedicalApp.xcodeproj`
2. Run on iPhone 17 Pro simulator
3. Test registration flow with a new account
4. Test login flow
5. Test Face ID enable flow

Expected: All flows complete without errors

---

## Task 10: Clean Up Old TypeScript Backend

**Files:**

- Delete: `backend/src/opaque.ts`
- Modify: `backend/src/index.ts`
- Update: `backend/wrangler.toml`
- Update: `backend/README.md`

**Step 1: Remove opaque.ts**

Run: `rm backend/src/opaque.ts`

**Step 2: Update index.ts to remove OPAQUE routes**

Modify `backend/src/index.ts` to remove all OPAQUE-related code, keeping only the structure for future sync endpoints.

**Step 3: Update backend README**

Update `backend/README.md` to explain the split architecture:

- Rust worker handles OPAQUE authentication
- TypeScript worker (future) handles sync

**Step 4: Commit**

```bash
git add backend/
git commit -m "refactor(backend): remove OPAQUE code, handled by Rust worker"
```

---

## Task 11: Create Pull Request

**Step 1: Push branch**

```bash
git push -u origin HEAD
```

**Step 2: Create PR**

```bash
gh pr create --title "feat: replace TypeScript OPAQUE backend with Rust Worker" --body "$(cat <<'EOF'
## Summary

- Replaces broken TypeScript OPAQUE implementation with native Rust Worker
- Upgrades both iOS (OpaqueSwift) and backend to opaque-ke v4
- Fixes WASM compilation issues with Cloudflare Workers

## Technical Details

The `@serenity-kit/opaque` library uses dynamic WASM compilation which Cloudflare Workers blocks. This PR:

1. Creates a new Rust-based Worker using `workers-rs`
2. Uses `opaque-ke` v4 directly (same crate as iOS via UniFFI)
3. Maintains identical cipher suite configuration for protocol compatibility
4. Preserves existing KV namespaces and API contract

## Test Plan

- [ ] All iOS unit tests pass
- [ ] Coverage thresholds met (90% overall, 85% per file)
- [ ] Smoke tests pass against deployed worker
- [ ] Manual testing: registration, login, Face ID enable
EOF
)"
```

**Step 3: Verify CI passes**

Monitor the PR for CI status.

---

## Summary

This plan:

1. **Tasks 1-3:** Create Rust Worker project with OPAQUE implementation
2. **Task 4:** Upgrade iOS OpaqueSwift to opaque-ke v4
3. **Tasks 5-6:** Fix compilation issues and migrate server setup
4. **Tasks 7-8:** Deploy and smoke test
5. **Tasks 9-11:** Full testing, cleanup, and PR

**Key risks:**

- opaque-ke v4 API changes may require additional fixes beyond what's documented
- Server setup format change invalidates existing registrations (OK for fresh deploy)
- WASM compilation may hit edge cases with certain crate features

**Mitigations:**

- Thorough local testing before deployment
- Smoke tests to catch 500 errors early
- Can fall back to keeping TypeScript worker for non-OPAQUE endpoints
