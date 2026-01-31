import CryptoKit
import Foundation

/// Top-level backup file structure
///
/// The backup file is a single JSON document containing either:
/// - Encrypted: cryptographic parameters + base64 ciphertext
/// - Unencrypted: raw BackupPayload data
///
/// This format is designed for maximum portability - any developer can
/// implement import/export using only the file itself as documentation.
struct BackupFile: Codable, Equatable {
    // MARK: - Constants

    static let currentVersion = "1.0"
    static let formatNameValue = "RecordWell Backup"
    static let schemaURL = "https://recordwell.app/schemas/backup-v1.json"

    // MARK: - Properties

    /// JSON Schema URL (informational, for validation)
    let schema: String?

    /// Human-readable format identifier
    let formatName: String

    /// Semantic version for compatibility checking
    let formatVersion: String

    /// App name/version that created this backup
    let generator: String

    /// Whether the payload is encrypted
    let encrypted: Bool

    /// Integrity checksum of ciphertext (encrypted) or data (unencrypted)
    let checksum: BackupChecksum

    /// Encryption parameters (nil if unencrypted)
    let encryption: BackupEncryption?

    /// Base64-encoded encrypted payload (nil if unencrypted)
    let ciphertext: String?

    /// Raw payload data (nil if encrypted)
    let data: BackupPayload?

    // MARK: - Coding Keys

    enum CodingKeys: String, CodingKey {
        case schema = "$schema"
        case formatName, formatVersion, generator, encrypted
        case checksum, encryption, ciphertext, data
    }

    // MARK: - Initialization

    init(
        schema: String? = schemaURL,
        formatName: String = formatNameValue,
        formatVersion: String = currentVersion,
        generator: String,
        encrypted: Bool,
        checksum: BackupChecksum,
        encryption: BackupEncryption?,
        ciphertext: String?,
        data: BackupPayload?
    ) {
        self.schema = schema
        self.formatName = formatName
        self.formatVersion = formatVersion
        self.generator = generator
        self.encrypted = encrypted
        self.checksum = checksum
        self.encryption = encryption
        self.ciphertext = ciphertext
        self.data = data
    }
}

// MARK: - BackupChecksum

/// Integrity checksum for corruption detection
struct BackupChecksum: Codable, Equatable {
    /// Hash algorithm used (always "SHA-256")
    let algorithm: String

    /// Base64-encoded hash value
    let value: String

    /// Compute SHA-256 checksum of data
    static func sha256(of data: Data) -> BackupChecksum {
        let hash = SHA256.hash(data: data)
        return BackupChecksum(
            algorithm: "SHA-256",
            value: Data(hash).base64EncodedString()
        )
    }

    /// Verify checksum matches data
    func verify(against data: Data) -> Bool {
        let computed = Self.sha256(of: data)
        return computed.value == value
    }
}

// MARK: - BackupEncryption

/// Encryption parameters for the backup
struct BackupEncryption: Codable, Equatable {
    /// Encryption algorithm (always "AES-256-GCM")
    let algorithm: String

    /// Key derivation function parameters
    let kdf: BackupKDF

    /// Base64-encoded 12-byte nonce
    let nonce: String

    /// Base64-encoded 16-byte authentication tag
    let tag: String
}

// MARK: - BackupKDF

/// Key derivation function parameters
struct BackupKDF: Codable, Equatable {
    /// KDF algorithm (always "Argon2id")
    let algorithm: String

    /// Argon2id version (19 = 0x13)
    let version: Int

    /// Base64-encoded salt
    let salt: String

    /// Memory cost in bytes (67108864 = 64 MB)
    let memory: Int

    /// Time cost (iterations)
    let iterations: Int

    /// Parallelism (lanes)
    let parallelism: Int

    /// Output key length in bytes
    let keyLength: Int

    /// Default Argon2id parameters matching ADR-0002
    static var defaultArgon2id: BackupKDF {
        BackupKDF(
            algorithm: "Argon2id",
            version: 19,
            salt: "", // Filled at export time
            memory: 67_108_864, // 64 MB
            iterations: 3,
            parallelism: 1,
            keyLength: 32
        )
    }
}
