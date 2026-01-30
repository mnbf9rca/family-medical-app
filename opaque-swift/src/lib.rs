use opaque_ke::{
    rand::rngs::OsRng, CipherSuite, ClientLogin as OpaqueClientLogin, ClientLoginFinishParameters,
    ClientRegistration as OpaqueClientRegistration, ClientRegistrationFinishParameters, CredentialResponse,
    RegistrationResponse, Ristretto255,
};
use sha2::{Digest, Sha256, Sha512};
use std::sync::Mutex;

uniffi::setup_scaffolding!();

/// Cipher suite matching backend Rust worker configuration
/// Ristretto255 + TripleDH + Argon2
struct DefaultCipherSuite;

impl CipherSuite for DefaultCipherSuite {
    type OprfCs = Ristretto255;
    type KeyExchange = opaque_ke::key_exchange::tripledh::TripleDh<Ristretto255, Sha512>;
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

/// Generate client identifier from username (SHA256 hash with app salt)
#[uniffi::export]
pub fn generate_client_identifier(username: String) -> Result<String, OpaqueError> {
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
    pub fn start(password: String) -> Result<Self, OpaqueError> {
        let mut rng = OsRng;

        let result = OpaqueClientRegistration::<DefaultCipherSuite>::start(&mut rng, password.as_bytes())
            .map_err(|_| OpaqueError::ProtocolError)?;

        let request = result.message.serialize().to_vec();

        Ok(Self {
            state: Mutex::new(Some(result.state)),
            request,
        })
    }

    #[uniffi::constructor]
    pub fn start_with_bytes(password: Vec<u8>) -> Result<Self, OpaqueError> {
        let mut rng = OsRng;

        let result = OpaqueClientRegistration::<DefaultCipherSuite>::start(&mut rng, &password)
            .map_err(|_| OpaqueError::ProtocolError)?;

        let request = result.message.serialize().to_vec();

        Ok(Self {
            state: Mutex::new(Some(result.state)),
            request,
        })
    }

    pub fn get_request(&self) -> Vec<u8> {
        self.request.clone()
    }

    pub fn finish(&self, server_response: Vec<u8>, password: String) -> Result<RegistrationResult, OpaqueError> {
        let mut state_guard = self.state.lock().map_err(|_| OpaqueError::ProtocolError)?;
        let state = state_guard.take().ok_or(OpaqueError::ProtocolError)?;

        let response =
            RegistrationResponse::deserialize(&server_response).map_err(|_| OpaqueError::SerializationError)?;

        let mut rng = OsRng;
        let result = state
            .finish(
                &mut rng,
                password.as_bytes(),
                response,
                ClientRegistrationFinishParameters::default(),
            )
            .map_err(|_| OpaqueError::ProtocolError)?;

        Ok(RegistrationResult {
            registration_upload: result.message.serialize().to_vec(),
            export_key: result.export_key.to_vec(),
        })
    }

    pub fn finish_with_bytes(
        &self,
        server_response: Vec<u8>,
        password: Vec<u8>,
    ) -> Result<RegistrationResult, OpaqueError> {
        let mut state_guard = self.state.lock().map_err(|_| OpaqueError::ProtocolError)?;
        let state = state_guard.take().ok_or(OpaqueError::ProtocolError)?;

        let response =
            RegistrationResponse::deserialize(&server_response).map_err(|_| OpaqueError::SerializationError)?;

        let mut rng = OsRng;
        let result = state
            .finish(
                &mut rng,
                &password,
                response,
                ClientRegistrationFinishParameters::default(),
            )
            .map_err(|_| OpaqueError::ProtocolError)?;

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
    pub fn start(password: String) -> Result<Self, OpaqueError> {
        let mut rng = OsRng;

        let result = OpaqueClientLogin::<DefaultCipherSuite>::start(&mut rng, password.as_bytes())
            .map_err(|_| OpaqueError::ProtocolError)?;

        let request = result.message.serialize().to_vec();

        Ok(Self {
            state: Mutex::new(Some(result.state)),
            request,
        })
    }

    #[uniffi::constructor]
    pub fn start_with_bytes(password: Vec<u8>) -> Result<Self, OpaqueError> {
        let mut rng = OsRng;

        let result = OpaqueClientLogin::<DefaultCipherSuite>::start(&mut rng, &password)
            .map_err(|_| OpaqueError::ProtocolError)?;

        let request = result.message.serialize().to_vec();

        Ok(Self {
            state: Mutex::new(Some(result.state)),
            request,
        })
    }

    pub fn get_request(&self) -> Vec<u8> {
        self.request.clone()
    }

    pub fn finish(&self, server_response: Vec<u8>, password: String) -> Result<LoginResult, OpaqueError> {
        let mut state_guard = self.state.lock().map_err(|_| OpaqueError::ProtocolError)?;
        let state = state_guard.take().ok_or(OpaqueError::ProtocolError)?;

        let response =
            CredentialResponse::deserialize(&server_response).map_err(|_| OpaqueError::SerializationError)?;

        let mut rng = OsRng;
        let result = state
            .finish(
                &mut rng,
                password.as_bytes(),
                response,
                ClientLoginFinishParameters::default(),
            )
            .map_err(|_| OpaqueError::ProtocolError)?;

        Ok(LoginResult {
            credential_finalization: result.message.serialize().to_vec(),
            session_key: result.session_key.to_vec(),
            export_key: result.export_key.to_vec(),
        })
    }

    pub fn finish_with_bytes(&self, server_response: Vec<u8>, password: Vec<u8>) -> Result<LoginResult, OpaqueError> {
        let mut state_guard = self.state.lock().map_err(|_| OpaqueError::ProtocolError)?;
        let state = state_guard.take().ok_or(OpaqueError::ProtocolError)?;

        let response =
            CredentialResponse::deserialize(&server_response).map_err(|_| OpaqueError::SerializationError)?;

        let mut rng = OsRng;
        let result = state
            .finish(&mut rng, &password, response, ClientLoginFinishParameters::default())
            .map_err(|_| OpaqueError::ProtocolError)?;

        Ok(LoginResult {
            credential_finalization: result.message.serialize().to_vec(),
            session_key: result.session_key.to_vec(),
            export_key: result.export_key.to_vec(),
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_registration_with_bytes() {
        let password = b"test-password-123".to_vec();

        // Start registration
        let reg = ClientRegistration::start_with_bytes(password.clone()).unwrap();
        let request = reg.get_request();
        assert!(!request.is_empty());
    }

    #[test]
    fn test_login_with_bytes() {
        let password = b"test-password-123".to_vec();

        // Start login
        let login = ClientLogin::start_with_bytes(password.clone()).unwrap();
        let request = login.get_request();
        assert!(!request.is_empty());
    }
}
