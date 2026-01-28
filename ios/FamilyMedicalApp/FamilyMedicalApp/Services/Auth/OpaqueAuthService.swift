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

    /// Default API base URL
    private static let defaultBaseURL =
        URL(string: "https://family-medical.cynexia.com/api/auth/opaque")! // swiftlint:disable:this force_unwrapping

    init(
        baseURL: URL = OpaqueAuthService.defaultBaseURL,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.session = session
    }

    func register(username: String, password: String) async throws -> OpaqueRegistrationResult {
        // Bypass for test usernames in DEBUG builds
        if Self.shouldBypassForTestUsername(username) {
            return OpaqueRegistrationResult(exportKey: Data(repeating: 0xAB, count: 32))
        }

        // Generate client identifier (SHA256 hash of username)
        let clientIdentifier = try generateClientIdentifier(username: username)

        // Step 1: Start registration
        let registration = try ClientRegistration.start(password: password)
        let registrationRequest = registration.getRequest()

        let startResponse = try await post(
            path: "register/start",
            body: [
                "clientIdentifier": clientIdentifier,
                "registrationRequest": registrationRequest.base64EncodedString()
            ]
        )

        guard let responseBase64 = startResponse["registrationResponse"] as? String,
              let responseData = Data(base64Encoded: responseBase64)
        else {
            throw OpaqueAuthError.invalidResponse
        }

        // Step 2: Finish registration
        let result = try registration.finish(serverResponse: responseData, password: password)

        let finishResponse = try await post(
            path: "register/finish",
            body: [
                "clientIdentifier": clientIdentifier,
                "registrationRecord": result.registrationUpload.base64EncodedString()
            ]
        )

        guard finishResponse["success"] as? Bool == true else {
            throw OpaqueAuthError.registrationFailed
        }

        return OpaqueRegistrationResult(exportKey: result.exportKey)
    }

    func login(username: String, password: String) async throws -> OpaqueLoginResult {
        // Bypass for test usernames in DEBUG builds
        if Self.shouldBypassForTestUsername(username) {
            return OpaqueLoginResult(
                exportKey: Data(repeating: 0xAB, count: 32),
                sessionKey: Data(repeating: 0xCD, count: 32),
                encryptedBundle: nil
            )
        }

        // Generate client identifier (SHA256 hash of username)
        let clientIdentifier = try generateClientIdentifier(username: username)

        // Step 1: Start login
        let login = try ClientLogin.start(password: password)
        let credentialRequest = login.getRequest()

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

        // Step 2: Finish login
        let result: LoginResult
        do {
            result = try login.finish(serverResponse: responseData, password: password)
        } catch {
            // OPAQUE verification failed - wrong password
            throw OpaqueAuthError.authenticationFailed
        }

        let finishResponse = try await post(
            path: "login/finish",
            body: [
                "clientIdentifier": clientIdentifier,
                "stateKey": stateKey,
                "finishLoginRequest": result.credentialFinalization.base64EncodedString()
            ]
        )

        guard finishResponse["success"] as? Bool == true else {
            throw OpaqueAuthError.authenticationFailed
        }

        // Parse optional encrypted bundle
        let encryptedBundle: Data? = if let bundleBase64 = finishResponse["encryptedBundle"] as? String {
            Data(base64Encoded: bundleBase64)
        } else {
            nil
        }

        return OpaqueLoginResult(
            exportKey: result.exportKey,
            sessionKey: result.sessionKey,
            encryptedBundle: encryptedBundle
        )
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
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw OpaqueAuthError.networkError
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpaqueAuthError.networkError
        }

        switch httpResponse.statusCode {
        case 200 ... 299:
            break
        case 401:
            throw OpaqueAuthError.authenticationFailed
        case 429:
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After").flatMap(Int.init)
            throw OpaqueAuthError.rateLimited(retryAfter: retryAfter)
        default:
            throw OpaqueAuthError.serverError(statusCode: httpResponse.statusCode)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
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
}
