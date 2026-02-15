import CryptoKit
import Foundation

/// Service for encrypting and decrypting RecordContent
///
/// Handles the transformation between RecordContent model objects and encrypted Data blobs.
/// This service is used by MedicalRecordRepository to encrypt RecordContent before storage
/// and decrypt it after retrieval.
///
/// Flow:
/// - Encrypt: RecordContent → JSON → Encrypted Data
/// - Decrypt: Encrypted Data → JSON → RecordContent
protocol RecordContentServiceProtocol: Sendable {
    /// Encrypt RecordContent to Data
    ///
    /// - Parameters:
    ///   - content: The RecordContent to encrypt
    ///   - fmk: Family Member Key to encrypt with
    /// - Returns: Encrypted data in combined format (nonce + ciphertext + tag)
    /// - Throws: RepositoryError if encoding or encryption fails
    func encrypt(_ content: RecordContent, using fmk: SymmetricKey) throws -> Data

    /// Decrypt Data to RecordContent
    ///
    /// - Parameters:
    ///   - encryptedData: The encrypted data in combined format
    ///   - fmk: Family Member Key to decrypt with
    /// - Returns: Decrypted RecordContent
    /// - Throws: RepositoryError if decryption or decoding fails
    func decrypt(_ encryptedData: Data, using fmk: SymmetricKey) throws -> RecordContent
}

final class RecordContentService: RecordContentServiceProtocol, @unchecked Sendable {
    // MARK: - Dependencies

    private let encryptionService: EncryptionServiceProtocol
    private let logger: TracingCategoryLogger

    // MARK: - Initialization

    init(encryptionService: EncryptionServiceProtocol, logger: CategoryLoggerProtocol? = nil) {
        self.encryptionService = encryptionService
        self.logger = TracingCategoryLogger(
            wrapping: logger ?? LoggingService.shared.logger(category: .storage)
        )
    }

    // MARK: - RecordContentServiceProtocol

    func encrypt(_ content: RecordContent, using fmk: SymmetricKey) throws -> Data {
        let start = ContinuousClock.now
        logger.entry("encrypt")
        do {
            // 1. Encode RecordContent to JSON
            let jsonData = try JSONEncoder().encode(content)

            // 2. Encrypt with FMK
            let encryptedPayload = try encryptionService.encrypt(jsonData, using: fmk)

            // 3. Return combined format (nonce + ciphertext + tag)
            logger.exit("encrypt", duration: ContinuousClock.now - start)
            return encryptedPayload.combined
        } catch let error as CryptoError {
            throw RepositoryError.encryptionFailed(error.localizedDescription)
        } catch {
            throw RepositoryError.serializationFailed(error.localizedDescription)
        }
    }

    func decrypt(_ encryptedData: Data, using fmk: SymmetricKey) throws -> RecordContent {
        let start = ContinuousClock.now
        logger.entry("decrypt")
        do {
            // 1. Parse combined format into EncryptedPayload
            let payload = try EncryptedPayload(combined: encryptedData)

            // 2. Decrypt to get JSON data
            let jsonData = try encryptionService.decrypt(payload, using: fmk)

            // 3. Decode JSON to RecordContent
            let content = try JSONDecoder().decode(RecordContent.self, from: jsonData)
            logger.exit("decrypt", duration: ContinuousClock.now - start)
            return content
        } catch let error as CryptoError {
            throw RepositoryError.decryptionFailed(error.localizedDescription)
        } catch {
            throw RepositoryError.deserializationFailed(error.localizedDescription)
        }
    }
}
