import CryptoKit
import Foundation
import Observation

/// Protocol for authentication service
protocol AuthenticationServiceProtocol {
    /// Whether user account has been set up
    var isSetUp: Bool { get }

    /// Whether biometric authentication is enabled
    var isBiometricEnabled: Bool { get }

    /// Number of failed authentication attempts
    var failedAttemptCount: Int { get }

    /// Whether account is currently locked out
    var isLockedOut: Bool { get }

    /// Remaining seconds until lockout expires
    var lockoutRemainingSeconds: Int { get }

    /// Stored username for display on unlock screen
    var storedUsername: String? { get }

    /// Set up user account with password (OPAQUE registration)
    /// - Parameters:
    ///   - password: User's password
    ///   - username: User's username
    ///   - enableBiometric: Whether to enable biometric authentication
    /// - Throws: AuthenticationError if setup fails
    func setUp(password: String, username: String, enableBiometric: Bool) async throws

    /// Login with OPAQUE and set up local account (for returning users on new device)
    /// - Parameters:
    ///   - password: User's password
    ///   - username: User's username
    ///   - enableBiometric: Whether to enable biometric authentication
    /// - Throws: AuthenticationError if login or setup fails
    func loginAndSetup(password: String, username: String, enableBiometric: Bool) async throws

    /// Complete setup using a pre-authenticated login result (from duplicate registration recovery)
    /// - Parameters:
    ///   - loginResult: The OPAQUE login result from successful login probe
    ///   - username: User's username
    ///   - enableBiometric: Whether to enable biometric authentication
    /// - Throws: AuthenticationError if setup fails
    func completeLoginFromExistingAccount(
        loginResult: OpaqueLoginResult,
        username: String,
        enableBiometric: Bool
    ) async throws

    /// Unlock with password
    /// - Parameter password: User's password
    /// - Throws: AuthenticationError if authentication fails
    func unlockWithPassword(_ password: String) async throws

    // MARK: - Bytes-Based Methods (RFC 9807)

    /// Set up authentication with password bytes - preferred for secure zeroing
    /// - Parameters:
    ///   - passwordBytes: Password as bytes (will be zeroed after use)
    ///   - username: User identifier
    ///   - enableBiometric: Whether to enable biometric unlock
    func setUp(passwordBytes: inout [UInt8], username: String, enableBiometric: Bool) async throws

    /// Login and set up with password bytes - preferred for secure zeroing
    /// - Parameters:
    ///   - passwordBytes: Password as bytes (will be zeroed after use)
    ///   - username: User identifier
    ///   - enableBiometric: Whether to enable biometric unlock
    func loginAndSetup(passwordBytes: inout [UInt8], username: String, enableBiometric: Bool) async throws

    /// Unlock with password bytes - preferred for secure zeroing
    /// - Parameter passwordBytes: Password as bytes (will be zeroed after use)
    func unlockWithPassword(_ passwordBytes: inout [UInt8]) async throws

    /// Unlock with biometric authentication
    /// - Throws: AuthenticationError if authentication fails
    func unlockWithBiometric() async throws

    /// Lock the account
    func lock()

    /// Logout and clear all authentication data
    func logout() throws

    /// Disable biometric authentication
    func disableBiometric()

    /// Enable biometric authentication
    /// - Throws: AuthenticationError if biometric not available
    func enableBiometric() async throws
}

/// Main authentication orchestration service
@Observable
final class AuthenticationService: AuthenticationServiceProtocol {
    // MARK: - Constants

    private static let primaryKeyIdentifier = "com.family-medical-app.primary-key"
    private static let identityPrivateKeyIdentifier = "com.family-medical-app.identity-private-key"
    private static let identityPublicKeyIdentifier = "com.family-medical-app.identity-public-key"
    private static let verificationTokenIdentifier = "com.family-medical-app.verification-token"
    private static let saltKey = "com.family-medical-app.salt"
    private static let usernameKey = "com.family-medical-app.username"
    private static let biometricEnabledKey = "com.family-medical-app.biometric-enabled"
    private static let failedAttemptsKey = "com.family-medical-app.failed-attempts"
    private static let lockoutEndTimeKey = "com.family-medical-app.lockout-end-time"
    private static let verificationPlaintext = "family-medical-app-verification"
    private static let useOpaqueKey = "com.family-medical-app.use-opaque"

    /// Rate limiting thresholds
    private static let rateLimitThresholds: [(attempts: Int, lockoutSeconds: Int)] = [
        (3, 30), // 3 fails = 30 seconds
        (4, 60), // 4 fails = 1 minute
        (5, 300), // 5 fails = 5 minutes
        (6, 900) // 6+ fails = 15 minutes
    ]

    // MARK: - Dependencies

    let keyDerivationService: KeyDerivationServiceProtocol
    private let keychainService: KeychainServiceProtocol
    let encryptionService: EncryptionServiceProtocol
    private let biometricService: BiometricServiceProtocol
    let opaqueAuthService: OpaqueAuthServiceProtocol
    private let userDefaults: UserDefaults
    let logger: CategoryLoggerProtocol

    // MARK: - Properties

    var failedAttemptCount: Int {
        userDefaults.integer(forKey: Self.failedAttemptsKey)
    }

    var isLockedOut: Bool {
        lockoutRemainingSeconds > 0
    }

    var lockoutRemainingSeconds: Int {
        guard let lockoutEndTime = userDefaults.object(forKey: Self.lockoutEndTimeKey) as? Date else {
            return 0
        }

        let remaining = Int(lockoutEndTime.timeIntervalSinceNow)
        return max(0, remaining)
    }

    var isSetUp: Bool {
        // Check for OPAQUE setup (new) or legacy salt-based setup
        userDefaults.bool(forKey: Self.useOpaqueKey) || userDefaults.data(forKey: Self.saltKey) != nil
    }

    var isBiometricEnabled: Bool {
        userDefaults.bool(forKey: Self.biometricEnabledKey)
    }

    var storedUsername: String? {
        userDefaults.string(forKey: Self.usernameKey)
    }

    /// Whether this account uses OPAQUE authentication (vs legacy password+salt)
    var usesOpaque: Bool {
        userDefaults.bool(forKey: Self.useOpaqueKey)
    }

    // MARK: - Initialization

    @MainActor
    init(
        keyDerivationService: KeyDerivationServiceProtocol = KeyDerivationService(),
        keychainService: KeychainServiceProtocol = KeychainService(),
        encryptionService: EncryptionServiceProtocol = EncryptionService(),
        biometricService: BiometricServiceProtocol? = nil,
        opaqueAuthService: OpaqueAuthServiceProtocol = OpaqueAuthService(),
        userDefaults: UserDefaults = .standard,
        logger: CategoryLoggerProtocol? = nil
    ) {
        self.keyDerivationService = keyDerivationService
        self.keychainService = keychainService
        self.encryptionService = encryptionService
        self.biometricService = biometricService ?? BiometricService()
        self.opaqueAuthService = opaqueAuthService
        self.userDefaults = userDefaults
        self.logger = logger ?? LoggingService.shared.logger(category: .auth)
    }

    // MARK: - AuthenticationServiceProtocol

    func setUp(password: String, username: String, enableBiometric: Bool) async throws {
        logger.logOperation("setUp", state: "started")

        // Register with OPAQUE server
        let registrationResult: OpaqueRegistrationResult
        do {
            registrationResult = try await opaqueAuthService.register(username: username, password: password)
        } catch let OpaqueAuthError.accountExistsConfirmed(loginResult) {
            // Account exists and user proved ownership (correct password)
            // Convert to AuthenticationError so UI can handle it
            logger.info("Account exists (confirmed via login probe) - prompting user")
            throw AuthenticationError.accountExistsConfirmed(loginResult: loginResult)
        }

        // Complete local setup with export key
        try await completeLocalSetup(
            exportKey: registrationResult.exportKey,
            username: username,
            enableBiometric: enableBiometric
        )

        // Best-effort: zero out this local copy of the password bytes
        var passwordBytes = Array(password.utf8)
        keyDerivationService.secureZero(&passwordBytes)

        logger.logOperation("setUp", state: "completed")
        logger.info("Account setup completed with OPAQUE, biometric enabled: \(enableBiometric)")
    }

    func loginAndSetup(password: String, username: String, enableBiometric: Bool) async throws {
        logger.logOperation("loginAndSetup", state: "started")

        // Attempt OPAQUE login with server
        let loginResult: OpaqueLoginResult
        do {
            loginResult = try await opaqueAuthService.login(username: username, password: password)
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

        // Secure zero password bytes
        var passwordBytes = Array(password.utf8)
        keyDerivationService.secureZero(&passwordBytes)

        logger.logOperation("loginAndSetup", state: "completed")
        logger.info("Returning user setup completed with OPAQUE, biometric enabled: \(enableBiometric)")
    }

    func completeLoginFromExistingAccount(
        loginResult: OpaqueLoginResult,
        username: String,
        enableBiometric: Bool
    ) async throws {
        logger.logOperation("completeLoginFromExistingAccount", state: "started")

        try await completeLocalSetup(
            exportKey: loginResult.exportKey,
            username: username,
            enableBiometric: enableBiometric
        )

        logger.logOperation("completeLoginFromExistingAccount", state: "completed")
        logger.info("Existing account setup completed, biometric enabled: \(enableBiometric)")
    }

    func unlockWithPassword(_ password: String) async throws {
        logger.logOperation("unlockWithPassword", state: "started")

        // Check if locked out
        if isLockedOut {
            logger.notice("Unlock attempt during lockout, remaining: \(lockoutRemainingSeconds)s")
            throw AuthenticationError.accountLocked(remainingSeconds: lockoutRemainingSeconds)
        }

        guard isSetUp else {
            throw AuthenticationError.notSetUp
        }

        // Prepare password bytes and ensure they're wiped after key derivation
        var passwordBytes = Array(password.utf8)
        defer {
            keyDerivationService.secureZero(&passwordBytes)
        }

        let candidateKey = try await deriveCandidateKey(password: password)
        try verifyAndCompleteUnlock(candidateKey: candidateKey)
    }

    /// Derive candidate key using OPAQUE or legacy authentication
    private func deriveCandidateKey(password: String) async throws -> SymmetricKey {
        if usesOpaque {
            try await deriveKeyViaOpaque(password: password)
        } else {
            try deriveKeyViaLegacy(password: password)
        }
    }

    /// Derive key via OPAQUE authentication with server
    private func deriveKeyViaOpaque(password: String) async throws -> SymmetricKey {
        guard let username = storedUsername else {
            throw AuthenticationError.notSetUp
        }

        do {
            let loginResult = try await opaqueAuthService.login(username: username, password: password)

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

    /// Derive key via legacy password + salt authentication
    func deriveKeyViaLegacy(password: String) throws -> SymmetricKey {
        guard let salt = userDefaults.data(forKey: Self.saltKey) else {
            throw AuthenticationError.notSetUp
        }
        return try keyDerivationService.derivePrimaryKey(from: password, salt: salt)
    }

    /// Verify candidate key and complete unlock
    func verifyAndCompleteUnlock(candidateKey: SymmetricKey) throws {
        guard let encryptedTokenData = try? keychainService.retrieveData(identifier: Self.verificationTokenIdentifier)
        else {
            throw AuthenticationError.verificationFailed
        }

        let encryptedToken = try EncryptedPayload(combined: encryptedTokenData)

        do {
            let decrypted = try encryptionService.decrypt(encryptedToken, using: candidateKey)
            let decryptedString = String(data: decrypted, encoding: .utf8)

            guard decryptedString == Self.verificationPlaintext else {
                throw AuthenticationError.wrongPassword
            }

            // Success - reset failed attempts
            userDefaults.removeObject(forKey: Self.failedAttemptsKey)
            userDefaults.removeObject(forKey: Self.lockoutEndTimeKey)

            logger.logOperation("unlockWithPassword", state: "success")
        } catch is CryptoError {
            // Decryption failed = wrong password
            logger.notice("Password verification failed")
            try handleFailedAttempt()
            throw AuthenticationError.wrongPassword
        }
    }

    func unlockWithBiometric() async throws {
        logger.logOperation("unlockWithBiometric", state: "started")

        guard isBiometricEnabled else {
            logger.notice("Biometric unlock attempted but not enabled")
            throw AuthenticationError.biometricNotAvailable
        }

        guard isSetUp else {
            throw AuthenticationError.notSetUp
        }

        // Authenticate with biometric
        try await biometricService.authenticate(reason: "Unlock Family Medical App")

        // Verify primary key is accessible (sanity check)
        _ = try keychainService.retrieveKey(identifier: Self.primaryKeyIdentifier)

        // Success - reset failed attempts
        userDefaults.removeObject(forKey: Self.failedAttemptsKey)
        userDefaults.removeObject(forKey: Self.lockoutEndTimeKey)

        logger.logOperation("unlockWithBiometric", state: "success")
    }

    func lock() {
        // No-op: Lock state is managed by AuthenticationViewModel.isAuthenticated
        // This service only manages persistent authentication state (Keychain),
        // not transient lock state which is handled at the UI layer
    }

    func logout() throws {
        logger.logOperation("logout", state: "started")

        // Delete all keys from Keychain
        try? keychainService.deleteKey(identifier: Self.primaryKeyIdentifier)
        try? keychainService.deleteData(identifier: Self.identityPrivateKeyIdentifier)
        try? keychainService.deleteData(identifier: Self.verificationTokenIdentifier)

        // Clear UserDefaults
        userDefaults.removeObject(forKey: Self.saltKey)
        userDefaults.removeObject(forKey: Self.usernameKey)
        userDefaults.removeObject(forKey: Self.useOpaqueKey)
        userDefaults.removeObject(forKey: Self.identityPublicKeyIdentifier)
        userDefaults.removeObject(forKey: Self.biometricEnabledKey)
        userDefaults.removeObject(forKey: Self.failedAttemptsKey)
        userDefaults.removeObject(forKey: Self.lockoutEndTimeKey)

        logger.logOperation("logout", state: "completed")
        logger.info("User account logged out")
    }

    func disableBiometric() {
        userDefaults.set(false, forKey: Self.biometricEnabledKey)
    }

    func enableBiometric() async throws {
        guard biometricService.isBiometricAvailable else {
            throw AuthenticationError.biometricNotAvailable
        }

        // Test biometric authentication
        try await biometricService.authenticate(reason: "Enable biometric authentication")

        userDefaults.set(true, forKey: Self.biometricEnabledKey)
    }

    // MARK: - Private Methods

    /// Complete local account setup with OPAQUE export key
    /// Shared by setUp, loginAndSetup, and completeLoginFromExistingAccount
    func completeLocalSetup(
        exportKey: Data,
        username: String,
        enableBiometric: Bool
    ) async throws {
        // RFC 9807 §6.4.4: Validate export key before use
        guard !exportKey.isEmpty,
              exportKey.count == 32 || exportKey.count == 64
        else {
            logger.error("OPAQUE returned invalid export key length: \(exportKey.count)")
            throw AuthenticationError.setupFailed
        }

        // Derive primary key from OPAQUE export key
        let primaryKey = try keyDerivationService.derivePrimaryKey(fromExportKey: exportKey)

        // Generate Curve25519 keypair (per ADR-0002)
        let privateKey = Curve25519.KeyAgreement.PrivateKey()
        let publicKey = privateKey.publicKey

        // Encrypt private key with primary key
        let privateKeyData = privateKey.rawRepresentation
        let encryptedPrivateKey = try encryptionService.encrypt(privateKeyData, using: primaryKey)

        // Create verification token
        let verificationData = Data(Self.verificationPlaintext.utf8)
        let encryptedVerificationToken = try encryptionService.encrypt(verificationData, using: primaryKey)

        // Store in Keychain
        try keychainService.storeKey(
            primaryKey,
            identifier: Self.primaryKeyIdentifier,
            accessControl: .whenUnlockedThisDeviceOnly
        )

        try keychainService.storeData(
            encryptedPrivateKey.combined,
            identifier: Self.identityPrivateKeyIdentifier,
            accessControl: .whenUnlockedThisDeviceOnly
        )

        try keychainService.storeData(
            encryptedVerificationToken.combined,
            identifier: Self.verificationTokenIdentifier,
            accessControl: .whenUnlockedThisDeviceOnly
        )

        // Store public key in UserDefaults (not sensitive)
        userDefaults.set(publicKey.rawRepresentation, forKey: Self.identityPublicKeyIdentifier)

        // Mark as using OPAQUE authentication
        userDefaults.set(true, forKey: Self.useOpaqueKey)

        // Store username in UserDefaults
        userDefaults.set(username, forKey: Self.usernameKey)

        // Set biometric preference and prompt for Face ID permission if enabled
        try await configureBiometric(enabled: enableBiometric)

        // Clear any previous failed attempts
        userDefaults.removeObject(forKey: Self.failedAttemptsKey)
        userDefaults.removeObject(forKey: Self.lockoutEndTimeKey)
    }

    private func configureBiometric(enabled: Bool) async throws {
        if enabled, biometricService.isBiometricAvailable {
            // Prompt for biometric to trigger system permission dialog
            try await biometricService.authenticate(reason: "Enable Face ID for quick unlock")
            userDefaults.set(true, forKey: Self.biometricEnabledKey)
        } else {
            userDefaults.set(false, forKey: Self.biometricEnabledKey)
        }
    }

    func handleFailedAttempt() throws {
        let currentAttempts = failedAttemptCount + 1
        userDefaults.set(currentAttempts, forKey: Self.failedAttemptsKey)

        logger.notice("Failed authentication attempt #\(currentAttempts)")

        // Find matching lockout threshold
        let lockoutSeconds = Self.rateLimitThresholds.last { currentAttempts >= $0.attempts }?
            .lockoutSeconds ?? 0

        if lockoutSeconds > 0 {
            let lockoutEndTime = Date().addingTimeInterval(TimeInterval(lockoutSeconds))
            userDefaults.set(lockoutEndTime, forKey: Self.lockoutEndTimeKey)
            logger.notice("Account locked for \(lockoutSeconds)s after \(currentAttempts) attempts")
            throw AuthenticationError.accountLocked(remainingSeconds: lockoutSeconds)
        }
    }
}
