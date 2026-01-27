import CryptoKit
import Foundation
@testable import FamilyMedicalApp

// MARK: - Mock Authentication Service

final class MockAuthenticationService: AuthenticationServiceProtocol {
    var isSetUp: Bool
    var isBiometricEnabled: Bool
    var failedAttemptCount: Int
    var isLockedOut: Bool
    var lockoutRemainingSeconds: Int
    var storedEmail: String?

    var shouldFailUnlock: Bool
    var shouldFailLogout: Bool

    private let biometricService: BiometricServiceProtocol?

    init(
        isSetUp: Bool = false,
        isBiometricEnabled: Bool = false,
        failedAttemptCount: Int = 0,
        isLockedOut: Bool = false,
        lockoutRemainingSeconds: Int = 0,
        storedEmail: String? = nil,
        shouldFailUnlock: Bool = false,
        shouldFailLogout: Bool = false,
        biometricService: BiometricServiceProtocol? = nil
    ) {
        self.isSetUp = isSetUp
        self.isBiometricEnabled = isBiometricEnabled
        self.failedAttemptCount = failedAttemptCount
        self.isLockedOut = isLockedOut
        self.lockoutRemainingSeconds = lockoutRemainingSeconds
        self.storedEmail = storedEmail
        self.shouldFailUnlock = shouldFailUnlock
        self.shouldFailLogout = shouldFailLogout
        self.biometricService = biometricService
    }

    func setUp(password: String, email: String, enableBiometric: Bool) async throws {
        isSetUp = true
        storedEmail = email
        if enableBiometric {
            if let biometricService {
                try await biometricService.authenticate(reason: "Enable biometric")
            }
            isBiometricEnabled = true
        }
    }

    func unlockWithPassword(_ password: String) async throws {
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

    func logout() throws {
        if shouldFailLogout {
            throw AuthenticationError.keychainError("Logout failed")
        }
        isSetUp = false
        isBiometricEnabled = false
        failedAttemptCount = 0
        storedEmail = nil
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

// MARK: - Mock Email Verification Service

final class MockEmailVerificationService: EmailVerificationServiceProtocol, @unchecked Sendable {
    var sendCodeCallCount = 0
    var sendCodeEmail: String?
    var sendCodeShouldThrow: AuthenticationError?

    var verifyCodeCallCount = 0
    var verifyCodeInput: (code: String, email: String)?
    var verifyCodeResult = EmailVerificationResult(isValid: true, isReturningUser: false)
    var verifyCodeShouldThrow: AuthenticationError?

    func sendVerificationCode(to email: String) async throws {
        sendCodeCallCount += 1
        sendCodeEmail = email
        if let error = sendCodeShouldThrow {
            throw error
        }
    }

    func verifyCode(_ code: String, for email: String) async throws -> EmailVerificationResult {
        verifyCodeCallCount += 1
        verifyCodeInput = (code, email)
        if let error = verifyCodeShouldThrow {
            throw error
        }
        return verifyCodeResult
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
