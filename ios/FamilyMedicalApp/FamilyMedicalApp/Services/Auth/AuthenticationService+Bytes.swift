import CryptoKit
import Foundation

// MARK: - Bytes-Based Methods (RFC 9807 Compliance)

/// Extension providing bytes-based authentication methods for secure password handling.
/// These methods accept `inout [UInt8]` instead of String, enabling secure zeroing
/// of the password buffer after use.
extension AuthenticationService {
    func setUp(passwordBytes: inout [UInt8], username: String, enableBiometric: Bool) async throws {
        defer {
            keyDerivationService.secureZero(&passwordBytes)
        }

        logger.logOperation("setUp", state: "started")

        // Register with OPAQUE server using bytes
        let registrationResult: OpaqueRegistrationResult
        do {
            registrationResult = try await opaqueAuthService.register(username: username, passwordBytes: passwordBytes)
        } catch let OpaqueAuthError.accountExistsConfirmed(loginResult) {
            logger.info("Account exists (confirmed via login probe) - prompting user")
            throw AuthenticationError.accountExistsConfirmed(loginResult: loginResult)
        }

        // Complete local setup with export key
        try await completeLocalSetup(
            exportKey: registrationResult.exportKey,
            username: username,
            enableBiometric: enableBiometric
        )

        logger.logOperation("setUp", state: "completed")
        logger.info("Account setup completed with OPAQUE (bytes), biometric enabled: \(enableBiometric)")
    }

    func loginAndSetup(passwordBytes: inout [UInt8], username: String, enableBiometric: Bool) async throws {
        defer {
            keyDerivationService.secureZero(&passwordBytes)
        }

        logger.logOperation("loginAndSetup", state: "started")

        // Attempt OPAQUE login with server using bytes
        let loginResult: OpaqueLoginResult
        do {
            loginResult = try await opaqueAuthService.login(username: username, passwordBytes: passwordBytes)
        } catch let error as OpaqueAuthError {
            logger.notice("OPAQUE login failed during loginAndSetup: \(error)")
            switch error {
            case .authenticationFailed:
                throw AuthenticationError.wrongPassword
            case .networkError:
                throw AuthenticationError.networkError("Unable to connect to server")
            default:
                throw AuthenticationError.opaqueError("Login failed")
            }
        }

        logger.debug("OPAQUE login successful, setting up local account")

        // Complete local setup with export key
        try await completeLocalSetup(
            exportKey: loginResult.exportKey,
            username: username,
            enableBiometric: enableBiometric
        )

        logger.logOperation("loginAndSetup", state: "completed")
        logger.info("Returning user setup completed with OPAQUE (bytes), biometric enabled: \(enableBiometric)")
    }

    func unlockWithPassword(_ passwordBytes: inout [UInt8]) async throws {
        defer {
            keyDerivationService.secureZero(&passwordBytes)
        }

        logger.logOperation("unlockWithPassword", state: "started")

        // Check if locked out
        if isLockedOut {
            logger.notice("Unlock attempt during lockout, remaining: \(lockoutRemainingSeconds)s")
            throw AuthenticationError.accountLocked(remainingSeconds: lockoutRemainingSeconds)
        }

        guard isSetUp else {
            throw AuthenticationError.notSetUp
        }

        let candidateKey = try await deriveCandidateKeyWithBytes(passwordBytes: passwordBytes)
        try verifyAndCompleteUnlock(candidateKey: candidateKey)
    }

    /// Derive candidate key using OPAQUE with password bytes
    func deriveCandidateKeyWithBytes(passwordBytes: [UInt8]) async throws -> SymmetricKey {
        if usesOpaque {
            return try await deriveKeyViaOpaqueWithBytes(passwordBytes: passwordBytes)
        } else {
            // Legacy: convert bytes to string and use legacy method
            let password = String(bytes: passwordBytes, encoding: .utf8) ?? ""
            return try deriveKeyViaLegacy(password: password)
        }
    }

    /// Derive key via OPAQUE authentication with bytes
    private func deriveKeyViaOpaqueWithBytes(passwordBytes: [UInt8]) async throws -> SymmetricKey {
        guard let username = storedUsername else {
            throw AuthenticationError.notSetUp
        }

        do {
            let loginResult = try await opaqueAuthService.login(username: username, passwordBytes: passwordBytes)

            // RFC 9807 §6.4.4: Validate export key before use
            guard !loginResult.exportKey.isEmpty,
                  loginResult.exportKey.count == 32 || loginResult.exportKey.count == 64
            else {
                logger.error("OPAQUE returned invalid export key length: \(loginResult.exportKey.count)")
                throw AuthenticationError.verificationFailed
            }

            return try keyDerivationService.derivePrimaryKey(fromExportKey: loginResult.exportKey)
        } catch is OpaqueAuthError {
            logger.notice("OPAQUE authentication failed")
            try handleFailedAttempt()
            throw AuthenticationError.wrongPassword
        }
    }
}
