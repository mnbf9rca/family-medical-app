import Foundation

/// Result of OPAQUE registration
struct OpaqueRegistrationResult: Equatable, Sendable {
    /// Export key derived from OPAQUE protocol (used as basis for Primary Key)
    let exportKey: Data
}

/// Result of OPAQUE login
struct OpaqueLoginResult: Equatable, Sendable {
    /// Export key derived from OPAQUE protocol (used as basis for Primary Key)
    let exportKey: Data

    /// Session key shared with server (for authenticated requests)
    let sessionKey: Data

    /// Encrypted user data bundle from server (if exists)
    let encryptedBundle: Data?
}

/// Protocol for OPAQUE authentication operations
///
/// OPAQUE (RFC 9807) is an augmented Password-Authenticated Key Exchange that provides
/// zero-knowledge authentication where the server never learns the username or password.
///
/// ## Security Properties
/// - Password never transmitted to server (even encrypted)
/// - Server cannot perform offline dictionary attacks
/// - Mutual authentication (client verifies server, server verifies client)
/// - Forward secrecy via fresh session keys
///
/// ## Usage Flow
/// 1. Registration: `register(username:password:)` creates server-side credential
/// 2. Login: `login(username:password:)` authenticates and retrieves export key
/// 3. Export key is used to derive Primary Key (per ADR-0002 key hierarchy)
protocol OpaqueAuthServiceProtocol: Sendable {
    /// Register a new user with OPAQUE protocol
    ///
    /// Performs two round-trips to server:
    /// 1. Start: Client sends registration request, server responds with registration response
    /// 2. Finish: Client sends registration record, server stores credential
    ///
    /// - Parameters:
    ///   - username: User's chosen username (hashed before sending to server)
    ///   - password: User's password (never leaves device)
    /// - Returns: Registration result containing export key
    /// - Throws: `OpaqueAuthError.registrationFailed` if server rejects registration
    func register(username: String, password: String) async throws -> OpaqueRegistrationResult

    /// Login an existing user with OPAQUE protocol
    ///
    /// Performs two round-trips to server:
    /// 1. Start: Client sends credential request, server responds with credential response
    /// 2. Finish: Client sends finalization, server verifies and returns session key
    ///
    /// - Parameters:
    ///   - username: User's username (hashed before sending to server)
    ///   - password: User's password (never leaves device)
    /// - Returns: Login result containing export key, session key, and optional bundle
    /// - Throws: `OpaqueAuthError.authenticationFailed` for wrong username OR password
    func login(username: String, password: String) async throws -> OpaqueLoginResult

    /// Upload encrypted bundle after registration or key change
    ///
    /// - Parameters:
    ///   - username: User's username
    ///   - bundle: Encrypted data bundle (FMKs, settings, sync state)
    /// - Throws: `OpaqueAuthError.uploadFailed` if server rejects upload
    func uploadBundle(username: String, bundle: Data) async throws
}

/// Errors specific to OPAQUE authentication
enum OpaqueAuthError: Error, Equatable {
    /// Registration failed (username may already exist)
    case registrationFailed

    /// Authentication failed (wrong username OR wrong password - intentionally ambiguous)
    case authenticationFailed

    /// Network error during OPAQUE protocol
    case networkError

    /// Invalid response from server
    case invalidResponse

    /// Server returned error status
    case serverError(statusCode: Int)

    /// OPAQUE protocol error (cryptographic failure)
    case protocolError

    /// Rate limited by server
    case rateLimited(retryAfter: Int?)

    /// Session expired during login flow
    case sessionExpired

    /// Bundle upload failed
    case uploadFailed
}

extension OpaqueAuthError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .registrationFailed:
            "Registration failed. Please try a different username."
        case .authenticationFailed:
            "Authentication failed. Please check your username and password."
        case .networkError:
            "Network error. Please check your connection and try again."
        case .invalidResponse:
            "Invalid response from server."
        case let .serverError(statusCode):
            "Server error (status \(statusCode))."
        case .protocolError:
            "Authentication protocol error."
        case let .rateLimited(retryAfter):
            if let seconds = retryAfter {
                "Too many attempts. Please wait \(seconds) seconds."
            } else {
                "Too many attempts. Please try again later."
            }
        case .sessionExpired:
            "Session expired. Please try again."
        case .uploadFailed:
            "Failed to upload data."
        }
    }
}
