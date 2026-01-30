use crate::opaque;
use base64::{engine::general_purpose::STANDARD as BASE64, Engine};
use serde::{Deserialize, Serialize};
use worker::*;

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

pub async fn handle_register_start(
    mut req: Request,
    _env: &Env,
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

    let result = opaque::start_login(
        server_setup,
        body.client_identifier.as_bytes(),
        password_file.as_deref(),
        &request_bytes,
    )
    .map_err(Error::from)?;

    // Store server state temporarily (60 second TTL)
    // State key includes record type (f=fake, r=real) for finish step
    let login_states = env.kv("LOGIN_STATES")?;
    let state_key = format!(
        "state:{}:{}:{}",
        body.client_identifier,
        Date::now().as_millis(),
        if is_fake_record { "f" } else { "r" }
    );

    login_states
        .put(&state_key, BASE64.encode(&result.state))?
        .expiration_ttl(60)
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

fn json_response<T: Serialize>(data: &T, status: u16) -> Result<Response> {
    let body = serde_json::to_string(data)?;
    let headers = Headers::new();
    headers.set("Content-Type", "application/json")?;
    headers.set("Access-Control-Allow-Origin", "*")?;

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
