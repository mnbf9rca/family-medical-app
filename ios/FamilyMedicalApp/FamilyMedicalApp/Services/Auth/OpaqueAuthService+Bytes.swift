import CryptoKit
import Foundation
import OpaqueSwift

// MARK: - Bytes-Based Methods (RFC 9807 Compliance)

/// Extension providing bytes-based authentication methods for secure password handling.
/// These methods accept `[UInt8]` instead of String, enabling callers to securely zero
/// the password buffer after use.
extension OpaqueAuthService {
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

        let (registration, responseData) = try await startRegistrationWithBytes(
            clientIdentifier: clientIdentifier,
            passwordBytes: passwordBytes
        )

        // Finish registration and handle existing account detection
        return try await finishRegistrationWithBytes(
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

        // Step 1: Start login with bytes
        let loginStart = try await performLoginStartWithBytes(
            clientIdentifier: clientIdentifier,
            passwordBytes: passwordBytes
        )

        // Step 2: Finish login with bytes
        return try await performLoginFinishWithBytes(
            loginStart: loginStart,
            passwordBytes: passwordBytes,
            clientIdentifier: clientIdentifier
        )
    }
}

// MARK: - Bytes-Based Registration Helpers

extension OpaqueAuthService {
    func startRegistrationWithBytes(
        clientIdentifier: String,
        passwordBytes: [UInt8]
    ) async throws -> (registration: ClientRegistration, responseData: Data) {
        logger.debug("Starting OPAQUE registration with bytes (step 1)")
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

    func finishRegistrationWithBytes(
        registration: ClientRegistration,
        responseData: Data,
        passwordBytes: [UInt8],
        clientIdentifier: String,
        username: String
    ) async throws -> OpaqueRegistrationResult {
        logger.debug("Finishing OPAQUE registration with bytes (step 2)")
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
            logger.info("Registration failed, probing login to check for existing account...")
            try await probeLoginForExistingAccountWithBytes(username: username, passwordBytes: passwordBytes)
            throw OpaqueAuthError.registrationFailed
        }
    }
}

// MARK: - Bytes-Based Login Helpers

extension OpaqueAuthService {
    func performLoginStartWithBytes(
        clientIdentifier: String,
        passwordBytes: [UInt8]
    ) async throws -> LoginStartResult {
        logger.debug("Starting OPAQUE login with bytes (step 1)")
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

    func performLoginFinishWithBytes(
        loginStart: LoginStartResult,
        passwordBytes: [UInt8],
        clientIdentifier: String
    ) async throws -> OpaqueLoginResult {
        logger.debug("Finishing OPAQUE login with bytes (step 2)")
        let result = try executeLoginFinishWithBytes(loginStart: loginStart, passwordBytes: passwordBytes)

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

    private func executeLoginFinishWithBytes(
        loginStart: LoginStartResult,
        passwordBytes: [UInt8]
    ) throws -> LoginResult {
        do {
            let result = try finishLoginWithBytes(
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

    private func finishLoginWithBytes(
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
}

// MARK: - Bytes-Based Test Helpers

extension OpaqueAuthService {
    func makeTestLoginResult(passwordBytes: [UInt8]) -> OpaqueLoginResult {
        let passwordKey = Self.deriveTestExportKey(from: passwordBytes)
        return OpaqueLoginResult(
            exportKey: passwordKey,
            sessionKey: Data(repeating: 0xCD, count: 32),
            encryptedBundle: nil
        )
    }

    func makeTestRegistrationResult(passwordBytes: [UInt8]) -> OpaqueRegistrationResult {
        logger.debug("Using test username bypass for registration")
        let passwordKey = Self.deriveTestExportKey(from: passwordBytes)
        return OpaqueRegistrationResult(exportKey: passwordKey)
    }

    /// Derive a deterministic test export key from password bytes
    static func deriveTestExportKey(from passwordBytes: [UInt8]) -> Data {
        var hasher = CryptoKit.SHA256()
        hasher.update(data: Data("test-opaque-salt".utf8))
        hasher.update(data: Data(passwordBytes))
        return Data(hasher.finalize())
    }

    /// Bytes-based version of account probing for RFC 9807 compliance
    func probeLoginForExistingAccountWithBytes(
        username: String,
        passwordBytes: [UInt8]
    ) async throws {
        do {
            let loginResult = try await login(username: username, passwordBytes: passwordBytes)
            logger.info("Login probe succeeded - account exists and password is correct")
            throw OpaqueAuthError.accountExistsConfirmed(loginResult: loginResult)
        } catch let error as OpaqueAuthError {
            switch error {
            case .accountExistsConfirmed:
                throw error
            case .networkError, .rateLimited:
                logger.info("Login probe failed with transport error - exposing for user feedback")
                throw error
            case .authenticationFailed, .invalidResponse, .protocolError, .registrationFailed,
                 .serverError, .sessionExpired, .uploadFailed:
                logger.info("Login probe failed - returning generic registration failure")
                throw OpaqueAuthError.registrationFailed
            }
        }
    }
}
