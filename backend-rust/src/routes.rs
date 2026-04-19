use crate::opaque;
use crate::rate_limit::{check_rate_limit, RateLimitConfig, REGISTRATION_MAX_REQUESTS, REGISTRATION_WINDOW_SECONDS};
use base64::{engine::general_purpose::STANDARD as BASE64, Engine};
use serde::{Deserialize, Serialize};
use worker::*;

/// TTL for OPAQUE server-state KV entries.
/// Bounds the server-side fake-record lifetime per RFC 9807 §10.9 — must
/// be ≥ the longest plausible client-side KE2 → KE3 round trip. See
/// ADR-0011 §"Server-side fake-record TTL"; this value is independently
/// tunable from the rate-limit windows, even when the numbers happen to
/// match.
const LOGIN_STATE_TTL_SECONDS: u64 = 60;

// Request/Response types
//
// These DTOs define the HTTP wire contract between the iOS
// `OpaqueAuthService` client and this Worker. All JSON fields use
// `camelCase` so they line up with the Swift-side DTOs. Opaque-ke protocol
// blobs are always base64-encoded (STANDARD, with padding); `clientIdentifier`
// is always the 64-character lowercase-hex SHA-256 of the username
// (32 bytes → 64 hex chars). See ADR-0011 for the full OPAQUE protocol flow.

/// POST `/auth/opaque/register/start` request body.
///
/// - `clientIdentifier` (Rust: `client_identifier`): 64 hex chars = SHA-256(username), 32 bytes.
/// - `registrationRequest` (Rust: `registration_request`): base64-encoded opaque-ke `RegistrationRequest` blob.
#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct RegisterStartRequest {
    pub client_identifier: String,
    pub registration_request: String, // base64
}

/// POST `/auth/opaque/register/start` response body.
///
/// - `registrationResponse` (Rust: `registration_response`): base64-encoded opaque-ke `RegistrationResponse`
///   blob the client feeds into `ClientRegistration::finish`.
#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct RegisterStartResponse {
    pub registration_response: String, // base64
}

/// POST `/auth/opaque/register/finish` request body.
///
/// - `clientIdentifier` (Rust: `client_identifier`): 64 hex chars (same as register/start).
/// - `registrationRecord` (Rust: `registration_record`): base64-encoded opaque-ke `RegistrationUpload`
///   (the password file) that the server persists as the credential.
/// - `encryptedBundle` (Rust: `encrypted_bundle`): optional base64-encoded initial encrypted backup
///   bundle; when present it is stored under `bundle:<clientIdentifier>`.
#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct RegisterFinishRequest {
    pub client_identifier: String,
    pub registration_record: String, // base64
    pub encrypted_bundle: Option<String>,
}

/// Generic `{ "success": true }` response used by the register/finish path.
///
/// - `success` (Rust: `success`): always `true` on the success path; identical
///   wire name in both languages (no camelCase rename needed).
#[derive(Serialize)]
pub struct SuccessResponse {
    pub success: bool,
}

/// POST `/auth/opaque/login/start` request body.
///
/// - `clientIdentifier` (Rust: `client_identifier`): 64 hex chars (same as register).
/// - `startLoginRequest` (Rust: `start_login_request`): base64-encoded opaque-ke `CredentialRequest` blob.
#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct LoginStartRequest {
    pub client_identifier: String,
    pub start_login_request: String, // base64
}

/// POST `/auth/opaque/login/start` response body.
///
/// - `loginResponse` (Rust: `login_response`): base64-encoded opaque-ke `CredentialResponse` blob.
/// - `stateKey` (Rust: `state_key`): opaque server-state handle (plain string, no base64) the
///   client must echo back on login/finish. Encodes a fake-vs-real record
///   discriminator per RFC 9807 §10.9; server-managed, TTL ~60s
///   (server-side constant `LOGIN_STATE_TTL_SECONDS`).
#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct LoginStartResponse {
    pub login_response: String, // base64
    pub state_key: String,
}

/// POST `/auth/opaque/login/finish` request body.
///
/// - `clientIdentifier` (Rust: `client_identifier`): 64 hex chars (same as register/login start).
/// - `stateKey` (Rust: `state_key`): exact value returned by the prior login/start response.
/// - `finishLoginRequest` (Rust: `finish_login_request`): base64-encoded opaque-ke `CredentialFinalization`
///   blob.
#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct LoginFinishRequest {
    pub client_identifier: String,
    pub state_key: String,
    pub finish_login_request: String, // base64
}

/// POST `/auth/opaque/login/finish` response body.
///
/// - `success` (Rust: `success`): always `true` on this success path.
/// - `sessionKey` (Rust: `session_key`): base64-encoded opaque-ke session key derived by the server.
/// - `encryptedBundle` (Rust: `encrypted_bundle`): optional base64-encoded encrypted backup bundle
///   associated with this account (whatever the client uploaded at
///   register/finish or via a subsequent update).
#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct LoginFinishResponse {
    pub success: bool,
    pub session_key: String,
    pub encrypted_bundle: Option<String>,
}

/// Error body returned on 4xx/5xx from the OPAQUE endpoints.
///
/// - `error` (Rust: `error`): human-readable string. The level of detail
///   depends on which code path produced the error:
///
/// **Validation and transport errors DO distinguish conditions** to aid
/// client-side debugging. Callers see specific strings such as `"Invalid
/// JSON: ..."`, `"Invalid clientIdentifier"`, `"Invalid registration record
/// format"`, `"Invalid base64 in registrationRequest"`, `"Session expired"`,
/// and `"Too many requests"` (accompanied by a `Retry-After` header).
/// These paths leak nothing about account existence; they only describe the
/// shape of the client's request or the state of a transient server-side
/// session.
///
/// **Auth-outcome paths deliberately return uniform strings** so that the
/// wire response does not reveal whether an account exists. Register start
/// and register finish collapse all credential-bearing failures to
/// `"Registration failed"`; login start and login finish collapse them to
/// `"Authentication failed"` (or `"Invalid credential request"` for
/// malformed OPAQUE messages, which applies equally to known and unknown
/// users). Combined with RFC 9807 §10.9 fake-record generation in
/// login/start, this prevents the endpoint from acting as an
/// account-enumeration oracle per RFC 9807 §6.4.
///
/// See ADR-0011 for the full OPAQUE protocol flow and threat model.
#[derive(Serialize)]
pub struct ErrorResponse {
    pub error: String,
}

pub async fn handle_register_start(
    mut req: Request,
    env: &Env,
    server_setup: &opaque::OpaqueServerSetup,
) -> Result<Response> {
    let body: RegisterStartRequest = match parse_json(&mut req).await {
        Ok(b) => b,
        Err(r) => return r,
    };
    console_log!(
        "[opaque/register/start] Client ID: {}...",
        &body.client_identifier[..8.min(body.client_identifier.len())]
    );

    // Validate client identifier (64 hex chars = 32 bytes SHA256)
    if body.client_identifier.len() != 64 {
        return json_response(
            &ErrorResponse {
                error: "Invalid clientIdentifier".into(),
            },
            400,
        );
    }

    // Rate limiting per client_identifier
    if let Ok(rate_limits) = env.kv("RATE_LIMITS") {
        let config = RateLimitConfig {
            max_requests: REGISTRATION_MAX_REQUESTS,
            window_seconds: REGISTRATION_WINDOW_SECONDS,
        };
        if let Err(retry_after) =
            check_rate_limit(&rate_limits, &body.client_identifier, "register_start", &config).await
        {
            console_log!(
                "[opaque/register/start] Rate limited: {}...",
                &body.client_identifier[..8]
            );
            let retry_after_str = retry_after.to_string();
            return json_response_with_headers(
                &ErrorResponse {
                    error: "Too many requests".into(),
                },
                429,
                &[("Retry-After", &retry_after_str)],
            );
        }
    }

    let request_bytes = BASE64
        .decode(&body.registration_request)
        .map_err(|_| Error::from("Invalid base64 in registrationRequest"))?;

    let result = opaque::start_registration(server_setup, body.client_identifier.as_bytes(), &request_bytes)
        .map_err(Error::from)?;

    console_log!(
        "[opaque/register/start] Success, response: {} bytes",
        result.response.len()
    );

    json_response(
        &RegisterStartResponse {
            registration_response: BASE64.encode(&result.response),
        },
        200,
    )
}

pub async fn handle_register_finish(mut req: Request, env: &Env) -> Result<Response> {
    let body: RegisterFinishRequest = match parse_json(&mut req).await {
        Ok(b) => b,
        Err(r) => return r,
    };

    if body.client_identifier.len() != 64 {
        return json_response(
            &ErrorResponse {
                error: "Invalid clientIdentifier".into(),
            },
            400,
        );
    }

    let credentials = env.kv("CREDENTIALS")?;
    let key = format!("cred:{}", body.client_identifier);

    // Check if user already exists
    if credentials.get(&key).text().await?.is_some() {
        return json_response(
            &ErrorResponse {
                error: "Registration failed".into(),
            },
            400,
        );
    }

    // Validate registration record is valid base64 before storing
    if BASE64.decode(&body.registration_record).is_err() {
        return json_response(
            &ErrorResponse {
                error: "Invalid registration record format".into(),
            },
            400,
        );
    }

    // Store the registration record as the password file
    credentials.put(&key, &body.registration_record)?.execute().await?;

    // Store initial bundle if provided
    if let Some(bundle) = body.encrypted_bundle {
        let bundles = env.kv("BUNDLES")?;
        bundles
            .put(&format!("bundle:{}", body.client_identifier), &bundle)?
            .execute()
            .await?;
    }

    console_log!(
        "[opaque/register/finish] Registered user: {}...",
        &body.client_identifier[..8]
    );

    json_response(&SuccessResponse { success: true }, 200)
}

pub async fn handle_login_start(
    mut req: Request,
    env: &Env,
    server_setup: &opaque::OpaqueServerSetup,
) -> Result<Response> {
    let body: LoginStartRequest = match parse_json(&mut req).await {
        Ok(b) => b,
        Err(r) => return r,
    };
    console_log!(
        "[opaque/login/start] Client ID: {}...",
        &body.client_identifier[..8.min(body.client_identifier.len())]
    );

    if body.client_identifier.len() != 64 {
        return json_response(
            &ErrorResponse {
                error: "Invalid clientIdentifier".into(),
            },
            400,
        );
    }

    // Rate limiting per client_identifier
    if let Ok(rate_limits) = env.kv("RATE_LIMITS") {
        let config = RateLimitConfig::default();
        if let Err(retry_after) = check_rate_limit(&rate_limits, &body.client_identifier, "login_start", &config).await
        {
            console_log!("[opaque/login/start] Rate limited: {}...", &body.client_identifier[..8]);
            let retry_after_str = retry_after.to_string();
            return json_response_with_headers(
                &ErrorResponse {
                    error: "Too many requests".into(),
                },
                429,
                &[("Retry-After", &retry_after_str)],
            );
        }
    }

    // Get password file (None for unknown users triggers fake record per RFC 9807 §10.9)
    let credentials = env.kv("CREDENTIALS")?;
    let key = format!("cred:{}", body.client_identifier);

    let password_file_b64 = credentials.get(&key).text().await?;
    let is_fake_record = password_file_b64.is_none();

    let password_file: Option<Vec<u8>> = match password_file_b64 {
        Some(pf_b64) => Some(
            BASE64
                .decode(&pf_b64)
                .map_err(|_| Error::from("Corrupted password file"))?,
        ),
        None => {
            console_log!(
                "[opaque/login/start] Unknown user, using fake record: {}...",
                &body.client_identifier[..8]
            );
            None
        }
    };

    if let Some(ref pf) = password_file {
        console_log!("[opaque/login/start] Found password file, {} bytes", pf.len());
    }

    let request_bytes = BASE64
        .decode(&body.start_login_request)
        .map_err(|_| Error::from("Invalid base64 in startLoginRequest"))?;

    let result = match opaque::start_login(
        server_setup,
        body.client_identifier.as_bytes(),
        password_file.as_deref(),
        &request_bytes,
    ) {
        Ok(r) => r,
        Err(e) => {
            console_log!("[opaque/login/start] OPAQUE protocol error: {}", e);
            return json_response(
                &ErrorResponse {
                    error: "Invalid credential request".into(),
                },
                400,
            );
        }
    };

    // Store server state temporarily.
    // State key includes record type (f=fake, r=real) for finish step.
    let login_states = env.kv("LOGIN_STATES")?;
    let state_key = format!(
        "state:{}:{}:{}",
        body.client_identifier,
        Date::now().as_millis(),
        if is_fake_record { "f" } else { "r" }
    );

    login_states
        .put(&state_key, BASE64.encode(&result.state))?
        .expiration_ttl(LOGIN_STATE_TTL_SECONDS)
        .execute()
        .await?;

    console_log!(
        "[opaque/login/start] Stored state, key: {}...",
        &state_key[..20.min(state_key.len())]
    );

    json_response(
        &LoginStartResponse {
            login_response: BASE64.encode(&result.response),
            state_key,
        },
        200,
    )
}

pub async fn handle_login_finish(mut req: Request, env: &Env) -> Result<Response> {
    let body: LoginFinishRequest = match parse_json(&mut req).await {
        Ok(b) => b,
        Err(r) => return r,
    };

    if body.client_identifier.len() != 64 {
        return json_response(
            &ErrorResponse {
                error: "Invalid clientIdentifier".into(),
            },
            400,
        );
    }

    // Get and delete server state (one-time use)
    let login_states = env.kv("LOGIN_STATES")?;

    // Check if this was a fake record (state key ends with :f)
    let is_fake_record = body.state_key.ends_with(":f");

    let server_state_b64 = match login_states.get(&body.state_key).text().await? {
        Some(s) => s,
        None => {
            return json_response(
                &ErrorResponse {
                    error: "Session expired".into(),
                },
                401,
            );
        }
    };

    login_states.delete(&body.state_key).await?;

    let server_state = BASE64
        .decode(&server_state_b64)
        .map_err(|_| Error::from("Corrupted server state"))?;

    let finalization_bytes = BASE64
        .decode(&body.finish_login_request)
        .map_err(|_| Error::from("Invalid base64 in finishLoginRequest"))?;

    let result = match opaque::finish_login(&server_state, &finalization_bytes) {
        Ok(r) => r,
        Err(_) => {
            console_log!(
                "[opaque/login/finish] Failed verification{}: {}...",
                if is_fake_record { " (fake record)" } else { "" },
                &body.client_identifier[..8]
            );
            return json_response(
                &ErrorResponse {
                    error: "Authentication failed".into(),
                },
                401,
            );
        }
    };

    // Defense-in-depth: reject fake records even if finish_login somehow succeeded
    // (should never happen cryptographically, but prevents logic bugs)
    if is_fake_record {
        console_log!(
            "[opaque/login/finish] Rejecting fake record success (should not happen): {}...",
            &body.client_identifier[..8]
        );
        return json_response(
            &ErrorResponse {
                error: "Authentication failed".into(),
            },
            401,
        );
    }

    // Get user's encrypted bundle
    let bundles = env.kv("BUNDLES")?;
    let encrypted_bundle = bundles
        .get(&format!("bundle:{}", body.client_identifier))
        .text()
        .await?;

    console_log!(
        "[opaque/login/finish] Successful login: {}...",
        &body.client_identifier[..8]
    );

    json_response(
        &LoginFinishResponse {
            success: true,
            session_key: BASE64.encode(&result.session_key),
            encrypted_bundle,
        },
        200,
    )
}

/// Build a `Headers` object whose `Access-Control-Allow-Origin: *` is
/// guaranteed, regardless of what a caller puts in `extras`.
///
/// `extras` pairs are applied first; the CORS origin is set last so a
/// caller cannot undermine the global CORS policy by passing
/// `Access-Control-Allow-Origin` in `extras`. All response-building
/// helpers funnel through here so ACAO has exactly one definition in
/// the crate.
pub(crate) fn build_response_headers(extras: &[(&str, &str)]) -> Result<Headers> {
    let headers = Headers::new();
    for (name, value) in extras {
        headers.set(name, value)?;
    }
    headers.set("Access-Control-Allow-Origin", "*")?;
    Ok(headers)
}

pub fn json_response<T: Serialize>(data: &T, status: u16) -> Result<Response> {
    let body = serde_json::to_string(data)?;
    let headers = build_response_headers(&[("Content-Type", "application/json")])?;
    Response::from_body(ResponseBody::Body(body.into_bytes())).map(|r| r.with_status(status).with_headers(headers))
}

/// JSON response with caller-supplied extra headers (e.g. `Retry-After`).
///
/// The hardcoded `Content-Type: application/json` is appended AFTER the
/// caller's extras, so a caller cannot accidentally override Content-Type
/// by including it in `extras`. `build_response_headers` then sets CORS
/// origin last, preserving the same policy guarantee.
fn json_response_with_headers<T: Serialize>(data: &T, status: u16, extras: &[(&str, &str)]) -> Result<Response> {
    let body = serde_json::to_string(data)?;
    let mut combined: Vec<(&str, &str)> = extras.to_vec();
    combined.push(("Content-Type", "application/json"));
    let headers = build_response_headers(&combined)?;
    Response::from_body(ResponseBody::Body(body.into_bytes())).map(|r| r.with_status(status).with_headers(headers))
}

/// Parse JSON request body, returning 400 Bad Request on parse failure
async fn parse_json<T: for<'de> Deserialize<'de>>(req: &mut Request) -> std::result::Result<T, Result<Response>> {
    match req.json().await {
        Ok(body) => Ok(body),
        Err(e) => Err(json_response(
            &ErrorResponse {
                error: format!("Invalid JSON: {}", e),
            },
            400,
        )),
    }
}
