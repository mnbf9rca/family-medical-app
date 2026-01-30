import CryptoKit
import Foundation

/// Protocol for backup file operations
protocol BackupFileServiceProtocol: Sendable {
    /// Create encrypted backup file from payload
    func createEncryptedBackup(payload: BackupPayload, password: String) throws -> BackupFile

    /// Create unencrypted backup file from payload
    func createUnencryptedBackup(payload: BackupPayload) throws -> BackupFile

    /// Decrypt backup file to payload
    func decryptBackup(file: BackupFile, password: String) throws -> BackupPayload

    /// Read unencrypted backup file
    func readUnencryptedBackup(file: BackupFile) throws -> BackupPayload

    /// Verify checksum integrity
    func verifyChecksum(file: BackupFile) throws -> Bool

    /// Serialize BackupFile to JSON data
    func serializeToJSON(file: BackupFile) throws -> Data

    /// Deserialize BackupFile from JSON data
    func deserializeFromJSON(_ data: Data) throws -> BackupFile
}

/// Service for creating and reading backup files
final class BackupFileService: BackupFileServiceProtocol, @unchecked Sendable {
    // MARK: - Constants

    private static let minimumPasswordLength = 8

    // MARK: - Dependencies

    private let keyDerivationService: KeyDerivationServiceProtocol
    private let encryptionService: EncryptionServiceProtocol
    private let logger: CategoryLoggerProtocol

    // MARK: - Initialization

    init(
        keyDerivationService: KeyDerivationServiceProtocol,
        encryptionService: EncryptionServiceProtocol,
        logger: CategoryLoggerProtocol? = nil
    ) {
        self.keyDerivationService = keyDerivationService
        self.encryptionService = encryptionService
        self.logger = logger ?? LoggingService.shared.logger(category: .storage)
    }

    // MARK: - BackupFileServiceProtocol

    func createEncryptedBackup(payload: BackupPayload, password: String) throws -> BackupFile {
        guard password.count >= Self.minimumPasswordLength else {
            throw BackupError.passwordTooWeak
        }

        logger.debug("Creating encrypted backup")

        // Encode payload to JSON
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let payloadData = try encoder.encode(payload)

        // Generate salt
        let salt = try keyDerivationService.generateSalt()

        // Derive key using Argon2id
        var passwordBytes = Array(password.utf8)
        defer { keyDerivationService.secureZero(&passwordBytes) }
        let key = try keyDerivationService.derivePrimaryKey(from: passwordBytes, salt: salt)

        // Encrypt payload
        let encrypted = try encryptionService.encrypt(payloadData, using: key)

        // Compute checksum of ciphertext (the combined nonce || ciphertext || tag)
        let checksum = BackupChecksum.sha256(of: encrypted.combined)

        // Build encryption parameters
        let kdf = BackupKDF(
            algorithm: "Argon2id",
            version: 19,
            salt: salt.base64EncodedString(),
            memory: 67_108_864,
            iterations: 3,
            parallelism: 1,
            keyLength: 32
        )

        let encryption = BackupEncryption(
            algorithm: "AES-256-GCM",
            kdf: kdf,
            nonce: encrypted.nonce.base64EncodedString(),
            tag: encrypted.tag.base64EncodedString()
        )

        logger.debug("Encrypted backup created successfully")

        return BackupFile(
            schema: BackupFile.schemaURL,
            formatName: BackupFile.formatNameValue,
            formatVersion: BackupFile.currentVersion,
            generator: generatorString(),
            encrypted: true,
            checksum: checksum,
            encryption: encryption,
            ciphertext: encrypted.ciphertext.base64EncodedString(),
            data: nil
        )
    }

    func createUnencryptedBackup(payload: BackupPayload) throws -> BackupFile {
        logger.debug("Creating unencrypted backup")

        // Encode payload to compute checksum
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let payloadData = try encoder.encode(payload)

        let checksum = BackupChecksum.sha256(of: payloadData)

        logger.debug("Unencrypted backup created successfully")

        return BackupFile(
            schema: BackupFile.schemaURL,
            formatName: BackupFile.formatNameValue,
            formatVersion: BackupFile.currentVersion,
            generator: generatorString(),
            encrypted: false,
            checksum: checksum,
            encryption: nil,
            ciphertext: nil,
            data: payload
        )
    }

    func decryptBackup(file: BackupFile, password: String) throws -> BackupPayload {
        guard file.encrypted else {
            throw BackupError.corruptedFile
        }

        guard let encryption = file.encryption,
              let ciphertextBase64 = file.ciphertext else {
            throw BackupError.corruptedFile
        }

        logger.debug("Decrypting backup")

        // Decode base64 components
        guard let salt = Data(base64Encoded: encryption.kdf.salt),
              let nonce = Data(base64Encoded: encryption.nonce),
              let tag = Data(base64Encoded: encryption.tag),
              let ciphertext = Data(base64Encoded: ciphertextBase64) else {
            throw BackupError.corruptedFile
        }

        // Derive key
        var passwordBytes = Array(password.utf8)
        defer { keyDerivationService.secureZero(&passwordBytes) }

        let key: SymmetricKey
        do {
            key = try keyDerivationService.derivePrimaryKey(from: passwordBytes, salt: salt)
        } catch {
            logger.error("Key derivation failed during backup decryption")
            throw BackupError.invalidPassword
        }

        // Reconstruct encrypted payload
        let encrypted: EncryptedPayload
        do {
            encrypted = try EncryptedPayload(nonce: nonce, ciphertext: ciphertext, tag: tag)
        } catch {
            throw BackupError.corruptedFile
        }

        // Decrypt
        let decryptedData: Data
        do {
            decryptedData = try encryptionService.decrypt(encrypted, using: key)
        } catch {
            logger.error("Decryption failed - likely wrong password")
            throw BackupError.invalidPassword
        }

        // Decode payload
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let payload = try decoder.decode(BackupPayload.self, from: decryptedData)
            logger.debug("Backup decrypted successfully")
            return payload
        } catch {
            logger.error("Failed to decode decrypted payload")
            throw BackupError.corruptedFile
        }
    }

    func readUnencryptedBackup(file: BackupFile) throws -> BackupPayload {
        guard !file.encrypted else {
            throw BackupError.corruptedFile
        }

        guard let data = file.data else {
            throw BackupError.corruptedFile
        }

        return data
    }

    func verifyChecksum(file: BackupFile) throws -> Bool {
        if file.encrypted {
            guard let ciphertextBase64 = file.ciphertext,
                  let nonce = file.encryption.flatMap({ Data(base64Encoded: $0.nonce) }),
                  let tag = file.encryption.flatMap({ Data(base64Encoded: $0.tag) }),
                  let ciphertext = Data(base64Encoded: ciphertextBase64) else {
                throw BackupError.corruptedFile
            }
            // Reconstruct combined data as it was when checksum was computed
            var combined = Data()
            combined.append(nonce)
            combined.append(ciphertext)
            combined.append(tag)
            return file.checksum.verify(against: combined)
        } else {
            guard let data = file.data else {
                throw BackupError.corruptedFile
            }
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
            let payloadData = try encoder.encode(data)
            return file.checksum.verify(against: payloadData)
        }
    }

    func serializeToJSON(file: BackupFile) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(file)
    }

    func deserializeFromJSON(_ data: Data) throws -> BackupFile {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            return try decoder.decode(BackupFile.self, from: data)
        } catch {
            throw BackupError.corruptedFile
        }
    }

    // MARK: - Private

    private func generatorString() -> String {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        return "FamilyMedicalApp/\(appVersion) (iOS)"
    }
}
