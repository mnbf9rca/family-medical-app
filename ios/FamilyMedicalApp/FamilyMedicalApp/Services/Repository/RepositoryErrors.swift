import Foundation

/// Errors that can occur during repository operations
enum RepositoryError: LocalizedError, Equatable {
    // MARK: - Core Data Errors

    /// Entity was not found in the persistent store
    case entityNotFound(String)

    /// Failed to save changes to the persistent store
    case saveFailed(String)

    /// Failed to fetch entities from the persistent store
    case fetchFailed(String)

    /// Failed to delete entity from the persistent store
    case deleteFailed(String)

    // MARK: - Encryption Errors

    /// Failed to encrypt data before saving
    case encryptionFailed(String)

    /// Failed to decrypt data after retrieval
    case decryptionFailed(String)

    /// Required encryption key is not available
    case keyNotAvailable(String)

    // MARK: - Validation Errors

    /// Data failed validation before save
    case validationFailed(String)

    /// Attempted to create entity with duplicate ID
    case duplicateEntity(UUID)

    // MARK: - Serialization Errors

    /// Failed to serialize data to JSON or binary format
    case serializationFailed(String)

    /// Failed to deserialize data from JSON or binary format
    case deserializationFailed(String)

    // MARK: - LocalizedError Conformance

    var errorDescription: String? {
        switch self {
        // Core Data errors
        case let .entityNotFound(details):
            "Entity not found: \(details)"
        case let .saveFailed(details):
            "Failed to save to database: \(details)"
        case let .fetchFailed(details):
            "Failed to fetch from database: \(details)"
        case let .deleteFailed(details):
            "Failed to delete from database: \(details)"
        // Encryption errors
        case let .encryptionFailed(details):
            "Encryption failed: \(details)"
        case let .decryptionFailed(details):
            "Decryption failed: \(details)"
        case let .keyNotAvailable(details):
            "Encryption key not available: \(details)"
        // Validation errors
        case let .validationFailed(details):
            "Validation failed: \(details)"
        case let .duplicateEntity(id):
            "Entity with ID \(id) already exists"
        // Serialization errors
        case let .serializationFailed(details):
            "Serialization failed: \(details)"
        case let .deserializationFailed(details):
            "Deserialization failed: \(details)"
        }
    }
}
