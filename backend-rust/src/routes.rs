use serde::{Deserialize, Serialize};
use worker::*;
use crate::opaque;
use base64::{Engine, engine::general_purpose::STANDARD as BASE64};

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
    let body: RegisterStartRequest = req.json().await?;
    console_log!("[opaque/register/start] Client ID: {}...", &body.client_identifier[..8.min(body.client_identifier.len())]);

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

    console_log!("[opaque/register/start] Success, response: {} bytes", result.response.len());

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
    console_log!("[opaque/login/start] Client ID: {}...", &body.client_identifier[..8.min(body.client_identifier.len())]);

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
    console_log!("[opaque/login/start] Found password file, {} bytes", password_file.len());

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

    console_log!("[opaque/login/start] Stored state, key: {}...", &state_key[..20.min(state_key.len())]);

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
    let headers = Headers::new();
    headers.set("Content-Type", "application/json")?;
    headers.set("Access-Control-Allow-Origin", "*")?;

    Ok(Response::from_body(ResponseBody::Body(body.into_bytes()))
        .unwrap()
        .with_status(status)
        .with_headers(headers))
}
