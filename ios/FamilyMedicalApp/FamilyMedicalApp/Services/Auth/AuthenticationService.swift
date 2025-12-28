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

    /// Set up user account with password
    /// - Parameters:
    ///   - password: User's password
    ///   - enableBiometric: Whether to enable biometric authentication
    /// - Throws: AuthenticationError if setup fails
    func setUp(password: String, enableBiometric: Bool) async throws

    /// Unlock with password
    /// - Parameter password: User's password
    /// - Throws: AuthenticationError if authentication fails
    func unlockWithPassword(_ password: String) async throws

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
    private static let biometricEnabledKey = "com.family-medical-app.biometric-enabled"
    private static let failedAttemptsKey = "com.family-medical-app.failed-attempts"
    private static let lockoutEndTimeKey = "com.family-medical-app.lockout-end-time"
    private static let verificationPlaintext = "family-medical-app-verification"

    // Rate limiting thresholds
    private static let rateLimitThresholds: [(attempts: Int, lockoutSeconds: Int)] = [
        (3, 30), // 3 fails = 30 seconds
        (4, 60), // 4 fails = 1 minute
        (5, 300), // 5 fails = 5 minutes
        (6, 900) // 6+ fails = 15 minutes
    ]

    // MARK: - Dependencies

    private let keyDerivationService: KeyDerivationServiceProtocol
    private let keychainService: KeychainServiceProtocol
    private let encryptionService: EncryptionServiceProtocol
    private let biometricService: BiometricServiceProtocol
    private let userDefaults: UserDefaults
    private let logger: CategoryLoggerProtocol

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
        userDefaults.data(forKey: Self.saltKey) != nil
    }

    var isBiometricEnabled: Bool {
        userDefaults.bool(forKey: Self.biometricEnabledKey)
    }

    // MARK: - Initialization

    init(
        keyDerivationService: KeyDerivationServiceProtocol = KeyDerivationService(),
        keychainService: KeychainServiceProtocol = KeychainService(),
        encryptionService: EncryptionServiceProtocol = EncryptionService(),
        biometricService: BiometricServiceProtocol = BiometricService(),
        userDefaults: UserDefaults = .standard,
        logger: CategoryLoggerProtocol? = nil
    ) {
        self.keyDerivationService = keyDerivationService
        self.keychainService = keychainService
        self.encryptionService = encryptionService
        self.biometricService = biometricService
        self.userDefaults = userDefaults
        self.logger = logger ?? LoggingService.shared.logger(category: .auth)
    }

    // MARK: - AuthenticationServiceProtocol

    func setUp(password: String, enableBiometric: Bool) async throws {
        logger.logOperation("setUp", state: "started")

        // Generate salt
        let salt = try keyDerivationService.generateSalt()

        // Derive primary key from password
        let primaryKey = try keyDerivationService.derivePrimaryKey(from: password, salt: salt)

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

        // Store encrypted private key as Data in Keychain
        try keychainService.storeData(
            encryptedPrivateKey.combined,
            identifier: Self.identityPrivateKeyIdentifier,
            accessControl: .whenUnlockedThisDeviceOnly
        )

        // Store verification token
        try keychainService.storeData(
            encryptedVerificationToken.combined,
            identifier: Self.verificationTokenIdentifier,
            accessControl: .whenUnlockedThisDeviceOnly
        )

        // Store public key in UserDefaults (not sensitive)
        userDefaults.set(publicKey.rawRepresentation, forKey: Self.identityPublicKeyIdentifier)

        // Store salt in UserDefaults (not sensitive per ADR-0002)
        userDefaults.set(salt, forKey: Self.saltKey)

        // Set biometric preference
        userDefaults.set(enableBiometric && biometricService.isBiometricAvailable, forKey: Self.biometricEnabledKey)

        // Clear any previous failed attempts
        userDefaults.removeObject(forKey: Self.failedAttemptsKey)
        userDefaults.removeObject(forKey: Self.lockoutEndTimeKey)

        // Best-effort: zero out this local copy of the password bytes
        // Note: The original String instance may still remain in memory and
        // cannot be reliably cleared due to Swift String copy-on-write semantics
        var passwordBytes = Array(password.utf8)
        keyDerivationService.secureZero(&passwordBytes)

        logger.logOperation("setUp", state: "completed")
        logger.info("Account setup completed, biometric enabled: \(enableBiometric)")
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

        // Get salt
        guard let salt = userDefaults.data(forKey: Self.saltKey) else {
            throw AuthenticationError.notSetUp
        }

        // Prepare password bytes and ensure they're wiped after key derivation
        var passwordBytes = Array(password.utf8)
        defer {
            keyDerivationService.secureZero(&passwordBytes)
        }

        // Derive key from password
        let candidateKey = try keyDerivationService.derivePrimaryKey(from: password, salt: salt)

        // Verify by attempting to decrypt verification token
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

    private func handleFailedAttempt() throws {
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
