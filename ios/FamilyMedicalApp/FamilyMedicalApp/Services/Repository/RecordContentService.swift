import CryptoKit
import Foundation

/// Service for encrypting and decrypting RecordContentEnvelope
///
/// Handles the transformation between RecordContentEnvelope and encrypted Data blobs.
/// Used by MedicalRecordRepository callers to encrypt content before storage
/// and decrypt it after retrieval.
///
/// Flow:
/// - Encrypt: RecordContentEnvelope → JSON → Encrypted Data
/// - Decrypt: Encrypted Data → JSON → RecordContentEnvelope
protocol RecordContentServiceProtocol: Sendable {
    /// Encrypt RecordContentEnvelope to Data
    func encrypt(_ envelope: RecordContentEnvelope, using fmk: SymmetricKey) throws -> Data

    /// Decrypt Data to RecordContentEnvelope
    func decrypt(_ encryptedData: Data, using fmk: SymmetricKey) throws -> RecordContentEnvelope
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

    func encrypt(_ envelope: RecordContentEnvelope, using fmk: SymmetricKey) throws -> Data {
        let start = ContinuousClock.now
        logger.entry("encrypt")
        do {
            let jsonData = try JSONEncoder().encode(envelope)
            let encryptedPayload = try encryptionService.encrypt(jsonData, using: fmk)
            logger.exit("encrypt", duration: ContinuousClock.now - start)
            return encryptedPayload.combined
        } catch let error as CryptoError {
            throw RepositoryError.encryptionFailed(error.localizedDescription)
        } catch {
            throw RepositoryError.serializationFailed(error.localizedDescription)
        }
    }

    func decrypt(_ encryptedData: Data, using fmk: SymmetricKey) throws -> RecordContentEnvelope {
        let start = ContinuousClock.now
        logger.entry("decrypt")
        do {
            let payload = try EncryptedPayload(combined: encryptedData)
            let jsonData = try encryptionService.decrypt(payload, using: fmk)
            let envelope = try JSONDecoder().decode(RecordContentEnvelope.self, from: jsonData)
            logger.exit("decrypt", duration: ContinuousClock.now - start)
            return envelope
        } catch let error as CryptoError {
            throw RepositoryError.decryptionFailed(error.localizedDescription)
        } catch {
            throw RepositoryError.deserializationFailed(error.localizedDescription)
        }
    }
}
