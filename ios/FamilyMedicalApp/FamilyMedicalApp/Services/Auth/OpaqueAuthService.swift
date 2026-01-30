import CryptoKit
import Foundation
import OpaqueSwift

/// Result from starting the OPAQUE login protocol
struct LoginStartResult {
    let loginState: ClientLogin
    let responseData: Data
    let stateKey: String
}

/// OPAQUE authentication service implementation
///
/// Handles OPAQUE protocol communication with the backend server.
/// Uses OpaqueSwift (UniFFI-wrapped opaque-ke) for client-side cryptography.
///
/// ## Test Username Bypass
/// In DEBUG builds, usernames matching `testuser` or `test_*` patterns
/// bypass actual API calls for testing purposes.
final class OpaqueAuthService: OpaqueAuthServiceProtocol, @unchecked Sendable {
    let baseURL: URL
    let session: URLSession
    let logger: CategoryLoggerProtocol

    /// Default API base URL
    private static let defaultBaseURL =
        URL(string: "https://api.recordwell.app/auth/opaque")! // swiftlint:disable:this force_unwrapping

    init(
        baseURL: URL = OpaqueAuthService.defaultBaseURL,
        session: URLSession = .shared,
        logger: CategoryLoggerProtocol? = nil
    ) {
        self.baseURL = baseURL
        self.session = session
        self.logger = logger ?? LoggingService.shared.logger(category: .auth)
    }

    // MARK: - Protocol Methods

    func register(username: String, passwordBytes: [UInt8]) async throws -> OpaqueRegistrationResult {
        logger.logOperation("register", state: "started")
        logger.debug("Registering user with base URL: \(baseURL.absoluteString)")

        // Bypass for test usernames in DEBUG builds
        if Self.shouldBypassForTestUsername(username) {
            return makeTestRegistrationResult(passwordBytes: passwordBytes)
        }

        // Generate client identifier and start registration
        let clientIdentifier = try generateClientIdentifier(username: username)
        logger.debug("Generated client identifier: \(clientIdentifier.prefix(8))...")

        let (registration, responseData) = try await startRegistration(
            clientIdentifier: clientIdentifier,
            passwordBytes: passwordBytes
        )

        // Finish registration and handle existing account detection
        return try await finishRegistration(
            registration: registration,
            responseData: responseData,
            passwordBytes: passwordBytes,
            clientIdentifier: clientIdentifier,
            username: username
        )
    }

    func login(username: String, passwordBytes: [UInt8]) async throws -> OpaqueLoginResult {
        logger.logOperation("login", state: "started")
        logger.debug("Attempting OPAQUE login for user")

        // Bypass for test usernames in DEBUG builds
        if Self.shouldBypassForTestUsername(username) {
            logger.debug("Using test username bypass for login")
            return makeTestLoginResult(passwordBytes: passwordBytes)
        }

        let clientIdentifier = try generateClientIdentifier(username: username)
        logger.debug("Generated client identifier: \(clientIdentifier.prefix(8))...")

        // Step 1: Start login
        let loginStart = try await performLoginStart(
            clientIdentifier: clientIdentifier,
            passwordBytes: passwordBytes
        )

        // Step 2: Finish login
        return try await performLoginFinish(
            loginStart: loginStart,
            passwordBytes: passwordBytes,
            clientIdentifier: clientIdentifier
        )
    }

    // MARK: - Test Helpers

    private func makeTestLoginResult(passwordBytes: [UInt8]) -> OpaqueLoginResult {
        let passwordKey = Self.deriveTestExportKey(from: passwordBytes)
        return OpaqueLoginResult(
            exportKey: passwordKey,
            sessionKey: Data(repeating: 0xCD, count: 32),
            encryptedBundle: nil
        )
    }

    private func makeTestRegistrationResult(passwordBytes: [UInt8]) -> OpaqueRegistrationResult {
        logger.debug("Using test username bypass for registration")
        let passwordKey = Self.deriveTestExportKey(from: passwordBytes)
        return OpaqueRegistrationResult(exportKey: passwordKey)
    }

    // MARK: - Registration Helpers

    func startRegistration(
        clientIdentifier: String,
        passwordBytes: [UInt8]
    ) async throws -> (registration: ClientRegistration, responseData: Data) {
        logger.debug("Starting OPAQUE registration (step 1)")
        let registration = try ClientRegistration.startWithBytes(password: Data(passwordBytes))
        let registrationRequest = registration.getRequest()
        logger.debug("Registration request size: \(registrationRequest.count) bytes")

        let startResponse = try await post(
            path: "register/start",
            body: [
                "clientIdentifier": clientIdentifier,
                "registrationRequest": registrationRequest.base64EncodedString()
            ]
        )
        logger.debug("Received register/start response")

        guard let responseBase64 = startResponse["registrationResponse"] as? String,
              let responseData = Data(base64Encoded: responseBase64)
        else {
            logger.error("Invalid response from register/start - missing registrationResponse")
            throw OpaqueAuthError.invalidResponse
        }

        return (registration, responseData)
    }

    func finishRegistration(
        registration: ClientRegistration,
        responseData: Data,
        passwordBytes: [UInt8],
        clientIdentifier: String,
        username: String
    ) async throws -> OpaqueRegistrationResult {
        logger.debug("Finishing OPAQUE registration (step 2)")
        let result = try registration.finishWithBytes(serverResponse: responseData, password: Data(passwordBytes))

        do {
            let finishResponse = try await post(
                path: "register/finish",
                body: [
                    "clientIdentifier": clientIdentifier,
                    "registrationRecord": result.registrationUpload.base64EncodedString()
                ]
            )

            guard finishResponse["success"] as? Bool == true else {
                logger.error("Registration finish failed - success != true")
                throw OpaqueAuthError.registrationFailed
            }

            logger.logOperation("register", state: "completed")
            return OpaqueRegistrationResult(exportKey: result.exportKey)
        } catch OpaqueAuthError.registrationFailed {
            // Registration failed - silently probe login to check if account exists with correct password
            // This reveals "account exists" ONLY if the user proves ownership (correct password)
            logger.info("Registration failed, probing login to check for existing account...")
            // probeLoginForExistingAccount always throws - either .accountExistsConfirmed or .registrationFailed
            try await probeLoginForExistingAccount(username: username, passwordBytes: passwordBytes)
            // This line is unreachable but satisfies the compiler
            throw OpaqueAuthError.registrationFailed
        }
    }

    // MARK: - Login Helpers

    func performLoginStart(
        clientIdentifier: String,
        passwordBytes: [UInt8]
    ) async throws -> LoginStartResult {
        logger.debug("Starting OPAQUE login (step 1)")
        let loginState = try ClientLogin.startWithBytes(password: Data(passwordBytes))
        let credentialRequest = loginState.getRequest()
        logger.debug("Credential request size: \(credentialRequest.count) bytes")

        do {
            let (responseData, stateKey) = try await startLoginRequest(
                clientIdentifier: clientIdentifier,
                credentialRequest: credentialRequest
            )
            logger.debug("Received login/start response, state key length: \(stateKey.count)")
            return LoginStartResult(loginState: loginState, responseData: responseData, stateKey: stateKey)
        } catch {
            logger.error("Login start failed: \(error.localizedDescription)")
            throw error
        }
    }

    func performLoginFinish(
        loginStart: LoginStartResult,
        passwordBytes: [UInt8],
        clientIdentifier: String
    ) async throws -> OpaqueLoginResult {
        logger.debug("Finishing OPAQUE login (step 2)")
        let result = try executeLoginFinish(loginStart: loginStart, passwordBytes: passwordBytes)

        try await sendLoginFinishRequest(
            clientIdentifier: clientIdentifier,
            stateKey: loginStart.stateKey,
            credentialFinalization: result.credentialFinalization
        )

        logger.logOperation("login", state: "completed")
        return OpaqueLoginResult(
            exportKey: result.exportKey,
            sessionKey: result.sessionKey,
            encryptedBundle: nil
        )
    }

    private func executeLoginFinish(loginStart: LoginStartResult, passwordBytes: [UInt8]) throws -> LoginResult {
        do {
            let result = try finishLogin(
                login: loginStart.loginState,
                responseData: loginStart.responseData,
                passwordBytes: passwordBytes
            )
            logger.debug("Login finish crypto completed")
            return result
        } catch {
            logger.error("Login finish crypto failed: \(error.localizedDescription)")
            throw error
        }
    }

    func sendLoginFinishRequest(
        clientIdentifier: String,
        stateKey: String,
        credentialFinalization: Data
    ) async throws {
        do {
            try await finishLoginRequest(
                clientIdentifier: clientIdentifier,
                stateKey: stateKey,
                credentialFinalization: credentialFinalization
            )
            logger.debug("Login finish request completed")
        } catch {
            logger.error("Login finish request failed: \(error.localizedDescription)")
            throw error
        }
    }

    func startLoginRequest(
        clientIdentifier: String,
        credentialRequest: Data
    ) async throws -> (responseData: Data, stateKey: String) {
        let startResponse = try await post(
            path: "login/start",
            body: [
                "clientIdentifier": clientIdentifier,
                "startLoginRequest": credentialRequest.base64EncodedString()
            ]
        )

        guard let responseBase64 = startResponse["loginResponse"] as? String,
              let responseData = Data(base64Encoded: responseBase64),
              let stateKey = startResponse["stateKey"] as? String
        else {
            throw OpaqueAuthError.invalidResponse
        }
        return (responseData, stateKey)
    }

    private func finishLogin(
        login: ClientLogin,
        responseData: Data,
        passwordBytes: [UInt8]
    ) throws -> LoginResult {
        do {
            return try login.finishWithBytes(serverResponse: responseData, password: Data(passwordBytes))
        } catch {
            throw OpaqueAuthError.authenticationFailed
        }
    }

    private func finishLoginRequest(
        clientIdentifier: String,
        stateKey: String,
        credentialFinalization: Data
    ) async throws {
        let finishResponse = try await post(
            path: "login/finish",
            body: [
                "clientIdentifier": clientIdentifier,
                "stateKey": stateKey,
                "finishLoginRequest": credentialFinalization.base64EncodedString()
            ]
        )

        guard finishResponse["success"] as? Bool == true else {
            throw OpaqueAuthError.authenticationFailed
        }
    }

    func uploadBundle(username: String, bundle: Data) async throws {
        // Bypass for test usernames in DEBUG builds
        if Self.shouldBypassForTestUsername(username) { return }

        let clientIdentifier = try generateClientIdentifier(username: username)

        let response = try await post(
            path: "bundle",
            body: [
                "clientIdentifier": clientIdentifier,
                "encryptedBundle": bundle.base64EncodedString()
            ]
        )

        guard response["success"] as? Bool == true else {
            throw OpaqueAuthError.uploadFailed
        }
    }

    // MARK: - Internal Networking

    func post(path: String, body: [String: Any]) async throws -> [String: Any] {
        let url = baseURL.appendingPathComponent(path)
        logger.debug("POST \(url.absoluteString)")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            logger.error("Network error: \(error.localizedDescription)")
            throw OpaqueAuthError.networkError
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            logger.error("Invalid response type (not HTTPURLResponse)")
            throw OpaqueAuthError.networkError
        }

        logger.debug("Response status: \(httpResponse.statusCode)")

        switch httpResponse.statusCode {
        case 200 ... 299:
            break
        case 401:
            logger.notice("Authentication failed (401)")
            throw OpaqueAuthError.authenticationFailed
        case 429:
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After").flatMap(Int.init)
            logger.notice("Rate limited (429), retry after: \(retryAfter ?? -1)")
            throw OpaqueAuthError.rateLimited(retryAfter: retryAfter)
        default:
            // Log response body for debugging server errors
            let responseBody = String(data: data, encoding: .utf8) ?? "<non-utf8>"
            logger.error("Server error (\(httpResponse.statusCode)): \(responseBody)")

            // Check for registration failure (username already exists)
            if httpResponse.statusCode == 400, responseBody.contains("Registration failed") {
                throw OpaqueAuthError.registrationFailed
            }

            throw OpaqueAuthError.serverError(statusCode: httpResponse.statusCode)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            let responseBody = String(data: data, encoding: .utf8) ?? "<non-utf8>"
            logger.error("Invalid JSON response: \(responseBody)")
            throw OpaqueAuthError.invalidResponse
        }

        return json
    }
}

// MARK: - Static Utilities

extension OpaqueAuthService {
    /// Check if test username bypass should be used
    static func shouldBypassForTestUsername(_ username: String) -> Bool {
        let normalized = username.lowercased()
        let isTestUsername = normalized == "testuser" || normalized.hasPrefix("test_")

        guard isTestUsername else { return false }

        #if DEBUG
        return true
        #else
        return UITestingHelpers.isUITesting
        #endif
    }

    /// Derive a deterministic test export key from password bytes
    /// This ensures wrong passwords produce different keys and fail verification
    static func deriveTestExportKey(from passwordBytes: [UInt8]) -> Data {
        // Use SHA256 to deterministically map password to a 32-byte key
        // This simulates OPAQUE's behavior where different passwords produce different export keys
        var hasher = CryptoKit.SHA256()
        hasher.update(data: Data("test-opaque-salt".utf8))
        hasher.update(data: Data(passwordBytes))
        return Data(hasher.finalize())
    }
}

// MARK: - Account Probing

private extension OpaqueAuthService {
    /// Probe login after registration failure to detect existing accounts
    ///
    /// This implements secure duplicate registration handling:
    /// - If login succeeds: account exists AND user proved ownership (correct password)
    ///   → throw `.accountExistsConfirmed` with login result
    /// - If login fails with auth error: don't reveal whether account exists
    ///   → throw generic `.registrationFailed`
    /// - If login fails with transport error: expose for user feedback (doesn't reveal account existence)
    ///   → re-throw the original network/rate-limit error
    ///
    /// Security: Only reveals "account exists" when user proves they own it (correct password).
    /// Transport errors (network unreachable, rate limited) are safe to expose as they don't
    /// reveal whether the account exists.
    func probeLoginForExistingAccount(
        username: String,
        passwordBytes: [UInt8]
    ) async throws {
        do {
            // Try login with same credentials
            let loginResult = try await login(username: username, passwordBytes: passwordBytes)
            logger.info("Login probe succeeded - account exists and password is correct")
            // Login succeeded - account exists and password is correct
            // Throw special error so UI can offer to complete login
            throw OpaqueAuthError.accountExistsConfirmed(loginResult: loginResult)
        } catch let error as OpaqueAuthError {
            switch error {
            case .accountExistsConfirmed:
                // Re-throw this specific error (don't catch it as a generic failure)
                throw error
            case .networkError, .rateLimited:
                // Transport errors are safe to expose - they don't reveal account existence
                // User needs this feedback to know to retry
                logger.info("Login probe failed with transport error - exposing for user feedback")
                throw error
            case .authenticationFailed, .invalidResponse, .protocolError, .registrationFailed,
                 .serverError, .sessionExpired, .uploadFailed:
                // Server auth errors - return generic error to not reveal account existence
                // This is security-critical: don't reveal account existence to attackers
                logger.info("Login probe failed - returning generic registration failure")
                throw OpaqueAuthError.registrationFailed
            }
        }
    }
}
