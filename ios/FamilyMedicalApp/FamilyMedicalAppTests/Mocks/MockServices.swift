import CryptoKit
import Foundation
@testable import FamilyMedicalApp

// swiftlint:disable unneeded_throws_rethrows

// MARK: - Mock Authentication Service

final class MockAuthenticationService: AuthenticationServiceProtocol {
    var isSetUp: Bool
    var isBiometricEnabled: Bool
    var failedAttemptCount: Int
    var isLockedOut: Bool
    var lockoutRemainingSeconds: Int
    var storedUsername: String?

    var shouldFailUnlock: Bool
    var shouldFailLogout: Bool
    var shouldFailLoginAndSetup: Bool

    private let biometricService: BiometricServiceProtocol?

    init(
        isSetUp: Bool = false,
        isBiometricEnabled: Bool = false,
        failedAttemptCount: Int = 0,
        isLockedOut: Bool = false,
        lockoutRemainingSeconds: Int = 0,
        storedUsername: String? = nil,
        shouldFailUnlock: Bool = false,
        shouldFailLogout: Bool = false,
        shouldFailLoginAndSetup: Bool = false,
        biometricService: BiometricServiceProtocol? = nil
    ) {
        self.isSetUp = isSetUp
        self.isBiometricEnabled = isBiometricEnabled
        self.failedAttemptCount = failedAttemptCount
        self.isLockedOut = isLockedOut
        self.lockoutRemainingSeconds = lockoutRemainingSeconds
        self.storedUsername = storedUsername
        self.shouldFailUnlock = shouldFailUnlock
        self.shouldFailLogout = shouldFailLogout
        self.shouldFailLoginAndSetup = shouldFailLoginAndSetup
        self.biometricService = biometricService
    }

    func setUp(passwordBytes: inout [UInt8], username: String, enableBiometric: Bool) async throws {
        for index in passwordBytes.indices {
            passwordBytes[index] = 0
        }
        isSetUp = true
        storedUsername = username
        if enableBiometric {
            if let biometricService {
                try await biometricService.authenticate(reason: "Enable biometric")
            }
            isBiometricEnabled = true
        }
    }

    func loginAndSetup(passwordBytes: inout [UInt8], username: String, enableBiometric: Bool) async throws {
        for index in passwordBytes.indices {
            passwordBytes[index] = 0
        }
        if shouldFailLoginAndSetup {
            throw AuthenticationError.wrongPassword
        }
        isSetUp = true
        storedUsername = username
        if enableBiometric {
            if let biometricService {
                try await biometricService.authenticate(reason: "Enable biometric")
            }
            isBiometricEnabled = true
        }
    }

    func completeLoginFromExistingAccount(
        loginResult: OpaqueLoginResult,
        username: String,
        enableBiometric: Bool
    ) async throws {
        // Complete login using pre-authenticated result
        isSetUp = true
        storedUsername = username
        if enableBiometric {
            if let biometricService {
                try await biometricService.authenticate(reason: "Enable biometric")
            }
            isBiometricEnabled = true
        }
    }

    func unlockWithPassword(_ passwordBytes: inout [UInt8]) async throws {
        for index in passwordBytes.indices {
            passwordBytes[index] = 0
        }
        if shouldFailUnlock {
            if isLockedOut {
                throw AuthenticationError.accountLocked(remainingSeconds: lockoutRemainingSeconds)
            }
            failedAttemptCount += 1
            throw AuthenticationError.wrongPassword
        }
    }

    func unlockWithBiometric() async throws {
        guard isBiometricEnabled else {
            throw AuthenticationError.biometricNotAvailable
        }

        if let biometricService {
            try await biometricService.authenticate(reason: "Unlock")
        }
    }

    func lock() {
        // No-op for mock
    }

    func enableBiometric() async throws {
        if let biometricService {
            try await biometricService.authenticate(reason: "Enable biometric")
        }
        isBiometricEnabled = true
    }

    func disableBiometric() {
        isBiometricEnabled = false
    }

    func logout() {
        if shouldFailLogout {
            throw AuthenticationError.keychainError("Logout failed")
        }
        isSetUp = false
        isBiometricEnabled = false
        failedAttemptCount = 0
        storedUsername = nil
    }
}

// MARK: - Mock Biometric Service for ViewModel Tests

@MainActor
final class MockViewModelBiometricService: BiometricServiceProtocol {
    var biometryType: BiometryType
    var isBiometricAvailable: Bool

    // These simple boolean flags are safe as nonisolated(unsafe) because:
    // 1. They're only used in tests (not production code)
    // 2. They're typically set once during initialization
    // 3. The protocol's authenticate method isn't @MainActor, so can't access MainActor properties
    nonisolated(unsafe) var shouldFailAuthentication: Bool
    nonisolated(unsafe) var shouldCancelAuthentication: Bool

    init(
        isAvailable: Bool = false,
        biometryType: BiometryType = .none,
        shouldFailAuthentication: Bool = false,
        shouldCancelAuthentication: Bool = false
    ) {
        isBiometricAvailable = isAvailable
        self.biometryType = isAvailable ? biometryType : .none
        self.shouldFailAuthentication = shouldFailAuthentication
        self.shouldCancelAuthentication = shouldCancelAuthentication
    }

    func authenticate(reason: String) async throws {
        if shouldCancelAuthentication {
            throw AuthenticationError.biometricCancelled
        }
        if shouldFailAuthentication {
            throw AuthenticationError.biometricFailed("Authentication failed")
        }
    }
}

// MARK: - Mock Lock State Service

final class MockLockStateService: LockStateServiceProtocol {
    var isLocked: Bool = false
    var lockTimeoutSeconds: Int = 300

    // Tracking properties for testing
    var recordBackgroundTimeCalled = false
    var shouldLockOnForegroundReturnValue = false

    func recordBackgroundTime() {
        recordBackgroundTimeCalled = true
    }

    func shouldLockOnForeground() -> Bool {
        shouldLockOnForegroundReturnValue
    }

    func lock() {
        isLocked = true
    }

    func unlock() {
        isLocked = false
    }
}

// MARK: - Mock OPAQUE Auth Service

final class MockOpaqueAuthService: OpaqueAuthServiceProtocol, @unchecked Sendable {
    // Configurable behavior
    var shouldFailRegistration = false
    var shouldFailLogin = false
    var shouldFailUpload = false
    /// When true, registration fails but login succeeds (simulates existing account with correct password)
    var shouldThrowAccountExistsConfirmed = false

    // Call tracking
    var registerCallCount = 0
    var loginCallCount = 0
    var uploadCallCount = 0
    var lastRegisteredUsername: String?
    var lastLoginUsername: String?
    var lastUploadedBundle: Data?

    // Configurable export key for testing (default: 32 bytes)
    var testExportKey = Data(repeating: 0x42, count: 32)
    let testSessionKey = Data(repeating: 0x43, count: 32)

    func register(username: String, passwordBytes: [UInt8]) async throws -> OpaqueRegistrationResult {
        registerCallCount += 1
        lastRegisteredUsername = username

        if shouldThrowAccountExistsConfirmed {
            // Simulate: registration failed but login succeeded (account exists, correct password)
            let loginResult = OpaqueLoginResult(
                exportKey: testExportKey,
                sessionKey: testSessionKey,
                encryptedBundle: nil
            )
            throw OpaqueAuthError.accountExistsConfirmed(loginResult: loginResult)
        }

        if shouldFailRegistration {
            throw OpaqueAuthError.registrationFailed
        }

        return OpaqueRegistrationResult(exportKey: testExportKey)
    }

    func login(username: String, passwordBytes: [UInt8]) async throws -> OpaqueLoginResult {
        loginCallCount += 1
        lastLoginUsername = username

        if shouldFailLogin {
            throw OpaqueAuthError.authenticationFailed
        }

        return OpaqueLoginResult(
            exportKey: testExportKey,
            sessionKey: testSessionKey,
            encryptedBundle: nil
        )
    }

    func uploadBundle(username: String, bundle: Data) async throws {
        uploadCallCount += 1
        lastUploadedBundle = bundle

        if shouldFailUpload {
            throw OpaqueAuthError.uploadFailed
        }
    }
}

// MARK: - Mock Keychain Service

/// Mock keychain service for testing authentication flows
/// Named MockAuthKeychainService to avoid conflict with file-local mocks in other test files
final class MockAuthKeychainService: KeychainServiceProtocol, @unchecked Sendable {
    private var keys: [String: SymmetricKey] = [:]
    private var data: [String: Data] = [:]

    func storeKey(_ key: SymmetricKey, identifier: String, accessControl: KeychainAccessControl) throws {
        keys[identifier] = key
    }

    func retrieveKey(identifier: String) throws -> SymmetricKey {
        guard let key = keys[identifier] else {
            throw KeychainError.keyNotFound(identifier)
        }
        return key
    }

    func deleteKey(identifier: String) throws {
        guard keys[identifier] != nil else {
            throw KeychainError.keyNotFound(identifier)
        }
        keys.removeValue(forKey: identifier)
    }

    func keyExists(identifier: String) -> Bool {
        keys[identifier] != nil
    }

    func storeData(_ dataToStore: Data, identifier: String, accessControl: KeychainAccessControl) throws {
        data[identifier] = dataToStore
    }

    func retrieveData(identifier: String) throws -> Data {
        guard let storedData = data[identifier] else {
            throw KeychainError.keyNotFound(identifier)
        }
        return storedData
    }

    func deleteData(identifier: String) throws {
        guard data[identifier] != nil else {
            throw KeychainError.keyNotFound(identifier)
        }
        data.removeValue(forKey: identifier)
    }

    func dataExists(identifier: String) -> Bool {
        data[identifier] != nil
    }
}

// MARK: - Mock Biometric Service

/// Mock biometric service for testing authentication flows
/// Named MockAuthBiometricService to avoid conflict with file-local mocks in other test files
final class MockAuthBiometricService: BiometricServiceProtocol {
    let isAvailable: Bool
    let shouldSucceed: Bool

    init(isAvailable: Bool, shouldSucceed: Bool = true) {
        self.isAvailable = isAvailable
        self.shouldSucceed = shouldSucceed
    }

    var biometryType: BiometryType {
        isAvailable ? .faceID : .none
    }

    var isBiometricAvailable: Bool {
        isAvailable
    }

    func authenticate(reason: String) async throws {
        if !shouldSucceed {
            throw AuthenticationError.biometricFailed("Mock failure")
        }
    }
}

// MARK: - Mock Primary Key Provider

final class MockPrimaryKeyProvider: PrimaryKeyProviderProtocol, @unchecked Sendable {
    var primaryKey: SymmetricKey?
    var shouldFail = false

    init(primaryKey: SymmetricKey? = nil, shouldFail: Bool = false) {
        self.primaryKey = primaryKey
        self.shouldFail = shouldFail
    }

    func getPrimaryKey() throws -> SymmetricKey {
        if shouldFail {
            throw KeychainError.keyNotFound("com.family-medical-app.primary-key")
        }

        guard let key = primaryKey else {
            throw KeychainError.keyNotFound("com.family-medical-app.primary-key")
        }

        return key
    }
}

// swiftlint:enable unneeded_throws_rethrows
