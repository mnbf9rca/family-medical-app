use opaque_ke::{CipherSuite, Ristretto255, ServerSetup};
use argon2::Argon2;
use sha2::Sha512;
use rand::rngs::OsRng;
use base64::{Engine, engine::general_purpose::STANDARD as BASE64};

struct DefaultCipherSuite;

impl CipherSuite for DefaultCipherSuite {
    type OprfCs = Ristretto255;
    type KeyExchange = opaque_ke::key_exchange::tripledh::TripleDh<Ristretto255, Sha512>;
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
