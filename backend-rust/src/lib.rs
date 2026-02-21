mod opaque;
mod rate_limit;
mod routes;

use serde::Serialize;
use std::collections::HashMap;
use worker::*;

#[derive(Serialize)]
struct HealthStatus {
    status: &'static str,
}

#[derive(Serialize)]
struct ReadyStatus {
    status: &'static str,
    checks: HashMap<&'static str, &'static str>,
}

#[event(fetch)]
async fn main(req: Request, env: Env, _ctx: Context) -> Result<Response> {
    console_error_panic_hook::set_once();

    if req.method() == Method::Options {
        return cors_preflight();
    }

    let path = req.path();

    // Health checks - before loading secrets so they work even when secrets are misconfigured
    if req.method() == Method::Get && path == "/health/live" {
        return routes::json_response(&HealthStatus { status: "ok" }, 200);
    }
    if req.method() == Method::Get && path == "/health/ready" {
        return handle_ready(&env).await;
    }

    console_log!("[opaque] {} {}", req.method(), path);

    // Load OPAQUE server setup from worker secret
    // Note: Using traditional secret due to workers-rs SecretStore bug
    // https://github.com/cloudflare/workers-rs/issues/919
    let setup_secret = env.secret("OPAQUE_SERVER_SETUP")?.to_string();

    let server_setup = opaque::init_server_setup(Some(&setup_secret)).map_err(Error::from)?;

    match (req.method(), path.as_str()) {
        (Method::Post, "/auth/opaque/register/start") => routes::handle_register_start(req, &env, &server_setup).await,
        (Method::Post, "/auth/opaque/register/finish") => routes::handle_register_finish(req, &env).await,
        (Method::Post, "/auth/opaque/login/start") => routes::handle_login_start(req, &env, &server_setup).await,
        (Method::Post, "/auth/opaque/login/finish") => routes::handle_login_finish(req, &env).await,
        _ => Response::error("Not found", 404),
    }
}

async fn handle_ready(env: &Env) -> Result<Response> {
    let mut checks = HashMap::new();
    let mut all_ok = true;

    // Check OPAQUE server setup is accessible
    match env.secret("OPAQUE_SERVER_SETUP") {
        Ok(_) => {
            checks.insert("opaque_setup", "ok");
        }
        Err(_) => {
            checks.insert("opaque_setup", "error");
            all_ok = false;
        }
    }

    // Check KV namespaces with harmless reads
    for (name, kv_name) in [
        ("kv_credentials", "CREDENTIALS"),
        ("kv_bundles", "BUNDLES"),
        ("kv_login_states", "LOGIN_STATES"),
        ("kv_rate_limits", "RATE_LIMITS"),
    ] {
        match env.kv(kv_name) {
            Ok(kv) => match kv.get("__healthcheck__").text().await {
                Ok(_) => {
                    checks.insert(name, "ok");
                }
                Err(_) => {
                    checks.insert(name, "error");
                    all_ok = false;
                }
            },
            Err(_) => {
                checks.insert(name, "error");
                all_ok = false;
            }
        }
    }

    let status = if all_ok { "ok" } else { "degraded" };
    let code = if all_ok { 200 } else { 503 };

    routes::json_response(&ReadyStatus { status, checks }, code)
}

fn cors_preflight() -> Result<Response> {
    let headers = Headers::new();
    headers.set("Access-Control-Allow-Origin", "*")?;
    headers.set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")?;
    headers.set("Access-Control-Allow-Headers", "Content-Type")?;
    headers.set("Access-Control-Max-Age", "86400")?;
    Ok(Response::empty()?.with_headers(headers))
}
