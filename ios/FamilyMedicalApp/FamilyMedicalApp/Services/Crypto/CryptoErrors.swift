import Foundation

/// Errors related to encryption and decryption operations
enum CryptoError: LocalizedError, Equatable {
    case encryptionFailed(String)
    case decryptionFailed(String)
    case keyDerivationFailed(String)
    case invalidSalt(String)
    case invalidPayload(String)
    case invalidKeySize

    var errorDescription: String? {
        switch self {
        case let .encryptionFailed(reason):
            "Encryption failed: \(reason)"
        case let .decryptionFailed(reason):
            "Decryption failed: \(reason)"
        case let .keyDerivationFailed(reason):
            "Key derivation failed: \(reason)"
        case let .invalidSalt(reason):
            "Invalid salt: \(reason)"
        case let .invalidPayload(reason):
            "Invalid payload: \(reason)"
        case .invalidKeySize:
            "Invalid key size - must be 256 bits"
        }
    }
}

/// Errors related to iOS Keychain operations
enum KeychainError: LocalizedError, Equatable {
    case storeFailed(OSStatus)
    case retrieveFailed(OSStatus)
    case deleteFailed(OSStatus)
    case keyNotFound(String)

    var errorDescription: String? {
        switch self {
        case let .storeFailed(status):
            "Keychain store failed with status: \(status)"
        case let .retrieveFailed(status):
            "Keychain retrieve failed with status: \(status)"
        case let .deleteFailed(status):
            "Keychain delete failed with status: \(status)"
        case let .keyNotFound(identifier):
            "Key not found in Keychain: \(identifier)"
        }
    }
}
