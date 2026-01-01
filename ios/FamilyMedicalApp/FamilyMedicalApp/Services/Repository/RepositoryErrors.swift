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

    // MARK: - Schema Validation Errors

    /// Schema ID conflicts with a built-in schema
    case schemaIdConflictsWithBuiltIn(String)

    /// Custom schema was not found
    case customSchemaNotFound(String)

    /// Attempted to change field type on schema update (breaking change)
    case fieldTypeChangeNotAllowed(fieldId: String, from: FieldType, to: FieldType)

    /// Attempted to change field ID on schema update (breaking change)
    case fieldIdChangeNotAllowed(oldId: String, newId: String)

    /// Attempted to make optional field required on schema update (breaking change)
    case requiredFieldChangeNotAllowed(fieldId: String)

    /// Schema version was not incremented on update
    case schemaVersionNotIncremented(current: Int, expected: Int)

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
        // Schema validation errors
        case let .schemaIdConflictsWithBuiltIn(schemaId):
            "Schema ID '\(schemaId)' conflicts with a built-in schema"
        case let .customSchemaNotFound(schemaId):
            "Custom schema '\(schemaId)' not found"
        case let .fieldTypeChangeNotAllowed(fieldId, from, to):
            "Cannot change field type for '\(fieldId)' from \(from) to \(to)"
        case let .fieldIdChangeNotAllowed(oldId, newId):
            "Cannot change field ID from '\(oldId)' to '\(newId)'"
        case let .requiredFieldChangeNotAllowed(fieldId):
            "Cannot make field '\(fieldId)' required (was optional)"
        case let .schemaVersionNotIncremented(current, expected):
            "Schema version must be incremented (current: \(current), expected: \(expected))"
        // Serialization errors
        case let .serializationFailed(details):
            "Serialization failed: \(details)"
        case let .deserializationFailed(details):
            "Deserialization failed: \(details)"
        }
    }
}
