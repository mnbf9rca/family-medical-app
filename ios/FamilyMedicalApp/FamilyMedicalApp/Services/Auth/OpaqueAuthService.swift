import CryptoKit
import Foundation
import OpaqueSwift

/// OPAQUE authentication service implementation
///
/// Handles OPAQUE protocol communication with the backend server.
/// Uses OpaqueSwift (UniFFI-wrapped opaque-ke) for client-side cryptography.
///
/// ## Test Username Bypass
/// In DEBUG builds, usernames matching `testuser` or `test_*` patterns
/// bypass actual API calls for testing purposes.
final class OpaqueAuthService: OpaqueAuthServiceProtocol, @unchecked Sendable {
    private let baseURL: URL
    private let session: URLSession
    private let logger: CategoryLoggerProtocol

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

    func register(username: String, password: String) async throws -> OpaqueRegistrationResult {
        logger.logOperation("register", state: "started")
        logger.debug("Registering user with base URL: \(baseURL.absoluteString)")

        // Bypass for test usernames in DEBUG builds
        if Self.shouldBypassForTestUsername(username) {
            logger.debug("Using test username bypass for registration")
            // Derive deterministic export key from password so login verification works
            let passwordKey = Self.deriveTestExportKey(from: password)
            return OpaqueRegistrationResult(exportKey: passwordKey)
        }

        // Generate client identifier (SHA256 hash of username)
        let clientIdentifier = try generateClientIdentifier(username: username)
        logger.debug("Generated client identifier: \(clientIdentifier.prefix(8))...")

        // Step 1: Start registration
        logger.debug("Starting OPAQUE registration (step 1)")
        let registration = try ClientRegistration.start(password: password)
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

        // Step 2: Finish registration
        logger.debug("Finishing OPAQUE registration (step 2)")
        let result = try registration.finish(serverResponse: responseData, password: password)

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
    }

    func login(username: String, password: String) async throws -> OpaqueLoginResult {
        logger.logOperation("login", state: "started")
        logger.debug("Attempting OPAQUE login for user")

        // Bypass for test usernames in DEBUG builds
        if Self.shouldBypassForTestUsername(username) {
            logger.debug("Using test username bypass for login")
            return makeTestLoginResult(password: password)
        }

        let clientIdentifier = try generateClientIdentifier(username: username)
        logger.debug("Generated client identifier: \(clientIdentifier.prefix(8))...")

        // Step 1: Start login
        logger.debug("Starting OPAQUE login (step 1)")
        let login = try ClientLogin.start(password: password)
        let credentialRequest = login.getRequest()
        logger.debug("Credential request size: \(credentialRequest.count) bytes")

        let (responseData, stateKey): (Data, String)
        do {
            (responseData, stateKey) = try await startLoginRequest(
                clientIdentifier: clientIdentifier,
                credentialRequest: credentialRequest
            )
            logger.debug("Received login/start response, state key length: \(stateKey.count)")
        } catch {
            logger.error("Login start failed: \(error.localizedDescription)")
            throw error
        }

        // Step 2: Finish login
        logger.debug("Finishing OPAQUE login (step 2)")
        let result: LoginResult
        do {
            result = try finishLogin(login: login, responseData: responseData, password: password)
            logger.debug("Login finish crypto completed")
        } catch {
            logger.error("Login finish crypto failed: \(error.localizedDescription)")
            throw error
        }

        do {
            try await finishLoginRequest(
                clientIdentifier: clientIdentifier,
                stateKey: stateKey,
                credentialFinalization: result.credentialFinalization
            )
            logger.debug("Login finish request completed")
        } catch {
            logger.error("Login finish request failed: \(error.localizedDescription)")
            throw error
        }

        logger.logOperation("login", state: "completed")
        return OpaqueLoginResult(
            exportKey: result.exportKey,
            sessionKey: result.sessionKey,
            encryptedBundle: nil
        )
    }

    private func makeTestLoginResult(password: String) -> OpaqueLoginResult {
        let passwordKey = Self.deriveTestExportKey(from: password)
        return OpaqueLoginResult(
            exportKey: passwordKey,
            sessionKey: Data(repeating: 0xCD, count: 32),
            encryptedBundle: nil
        )
    }

    private func startLoginRequest(
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
        password: String
    ) throws -> LoginResult {
        do {
            return try login.finish(serverResponse: responseData, password: password)
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

    // MARK: - Private

    private func post(path: String, body: [String: Any]) async throws -> [String: Any] {
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

    /// Check if test username bypass should be used
    private static func shouldBypassForTestUsername(_ username: String) -> Bool {
        let normalized = username.lowercased()
        let isTestUsername = normalized == "testuser" || normalized.hasPrefix("test_")

        guard isTestUsername else { return false }

        #if DEBUG
        return true
        #else
        return UITestingHelpers.isUITesting
        #endif
    }

    /// Derive a deterministic test export key from password
    /// This ensures wrong passwords produce different keys and fail verification
    private static func deriveTestExportKey(from password: String) -> Data {
        // Use SHA256 to deterministically map password to a 32-byte key
        // This simulates OPAQUE's behavior where different passwords produce different export keys
        var hasher = CryptoKit.SHA256()
        hasher.update(data: Data("test-opaque-salt".utf8))
        hasher.update(data: Data(password.utf8))
        return Data(hasher.finalize())
    }
}
