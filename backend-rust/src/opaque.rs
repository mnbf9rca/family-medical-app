use opaque_ke::{
    CipherSuite, Ristretto255,
    ServerSetup, ServerRegistration, ServerLogin,
    RegistrationRequest, RegistrationUpload,
    CredentialRequest, CredentialFinalization,
    ServerLoginParameters,
};
use argon2::Argon2;
use sha2::Sha512;
use rand::rngs::OsRng;
use base64::{Engine, engine::general_purpose::STANDARD as BASE64};

/// Cipher suite matching iOS OpaqueSwift configuration
/// MUST be identical to client for protocol compatibility
pub struct DefaultCipherSuite;

impl CipherSuite for DefaultCipherSuite {
    type OprfCs = Ristretto255;
    type KeyExchange = opaque_ke::key_exchange::tripledh::TripleDh<Ristretto255, Sha512>;
    type Ksf = Argon2<'static>;
}

pub type OpaqueServerSetup = ServerSetup<DefaultCipherSuite>;

/// Initialize server setup from stored secret or generate new
pub fn init_server_setup(stored: Option<&str>) -> Result<OpaqueServerSetup, String> {
    match stored {
        Some(b64) => {
            let bytes = BASE64.decode(b64)
                .map_err(|e| format!("Failed to decode server setup: {}", e))?;

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
#[allow(dead_code)]
pub fn serialize_server_setup(setup: &OpaqueServerSetup) -> String {
    BASE64.encode(setup.serialize())
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

    let result = ServerRegistration::start(
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

    // Password file is stored as RegistrationUpload, but ServerLogin::start expects ServerRegistration
    let password = RegistrationUpload::<DefaultCipherSuite>::deserialize(password_file)
        .map_err(|_| "Failed to deserialize password file")?;

    // Complete the registration to get ServerRegistration
    let server_registration = ServerRegistration::finish(password);

    let mut rng = OsRng;
    let result = ServerLogin::start(
        &mut rng,
        server_setup,
        Some(server_registration),
        request,
        client_identifier,
        ServerLoginParameters::default(),
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
    let state = ServerLogin::<DefaultCipherSuite>::deserialize(server_state)
        .map_err(|_| "Failed to deserialize server state")?;

    let finalization = CredentialFinalization::<DefaultCipherSuite>::deserialize(credential_finalization)
        .map_err(|_| "Failed to deserialize credential finalization")?;

    let result = state.finish(finalization, ServerLoginParameters::default())
        .map_err(|_| "Login verification failed")?;

    Ok(LoginFinishResult {
        session_key: result.session_key.to_vec(),
    })
}
