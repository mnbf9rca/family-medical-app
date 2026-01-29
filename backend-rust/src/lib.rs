mod opaque;
mod routes;

use worker::*;

#[event(fetch)]
async fn main(req: Request, env: Env, _ctx: Context) -> Result<Response> {
    console_error_panic_hook::set_once();

    if req.method() == Method::Options {
        return cors_preflight();
    }

    console_log!("[opaque] {} {}", req.method(), req.path());

    // Load OPAQUE server setup from worker secret
    // Note: Using traditional secret due to workers-rs SecretStore bug
    // https://github.com/cloudflare/workers-rs/issues/XXX
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
        _ => Response::error("Not found", 404)
    }
}

fn cors_preflight() -> Result<Response> {
    let headers = Headers::new();
    headers.set("Access-Control-Allow-Origin", "*")?;
    headers.set("Access-Control-Allow-Methods", "POST, OPTIONS")?;
    headers.set("Access-Control-Allow-Headers", "Content-Type")?;
    headers.set("Access-Control-Max-Age", "86400")?;
    Ok(Response::empty()?.with_headers(headers))
}
