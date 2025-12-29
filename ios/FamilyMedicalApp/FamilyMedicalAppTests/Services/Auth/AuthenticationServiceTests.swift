// swiftlint:disable password_in_code force_unwrapping
import CryptoKit
import Foundation
import Testing
@testable import FamilyMedicalApp

@MainActor
struct AuthenticationServiceTests {
    // MARK: - Setup Tests

    @Test
    func setUpCreatesUserAccount() async throws {
        let userDefaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let keychainService = MockKeychainService()
        let service = AuthenticationService(
            keychainService: keychainService,
            userDefaults: userDefaults
        )

        #expect(service.isSetUp == false)

        try await service.setUp(password: "MySecurePassword123!", enableBiometric: false)

        #expect(service.isSetUp == true)
        #expect(userDefaults.data(forKey: "com.family-medical-app.salt") != nil)
        #expect(keychainService.keyExists(identifier: "com.family-medical-app.primary-key"))
        #expect(keychainService.dataExists(identifier: "com.family-medical-app.identity-private-key"))
        #expect(keychainService.dataExists(identifier: "com.family-medical-app.verification-token"))
    }

    @Test
    func setUpStoresCurve25519PublicKey() async throws {
        let userDefaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let service = AuthenticationService(
            keychainService: MockKeychainService(),
            userDefaults: userDefaults
        )

        try await service.setUp(password: "MySecurePassword123!", enableBiometric: false)

        let publicKeyData = userDefaults.data(forKey: "com.family-medical-app.identity-public-key")
        #expect(publicKeyData != nil)
        #expect(publicKeyData?.count == 32) // Curve25519 public key is 32 bytes
    }

    @Test
    func setUpEnablesBiometricWhenRequested() async throws {
        let userDefaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let biometricService = MockBiometricService(isAvailable: true)
        let service = AuthenticationService(
            biometricService: biometricService,
            userDefaults: userDefaults
        )

        try await service.setUp(password: "MySecurePassword123!", enableBiometric: true)

        #expect(service.isBiometricEnabled == true)
    }

    @Test
    func setUpDoesNotEnableBiometricWhenNotAvailable() async throws {
        let userDefaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let biometricService = MockBiometricService(isAvailable: false)
        let service = AuthenticationService(
            biometricService: biometricService,
            userDefaults: userDefaults
        )

        try await service.setUp(password: "MySecurePassword123!", enableBiometric: true)

        #expect(service.isBiometricEnabled == false)
    }

    // MARK: - Password Unlock Tests

    @Test
    func unlockWithCorrectPasswordSucceeds() async throws {
        let userDefaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let service = AuthenticationService(
            keychainService: MockKeychainService(),
            userDefaults: userDefaults
        )

        let password = "MySecurePassword123!"
        try await service.setUp(password: password, enableBiometric: false)
        try await service.unlockWithPassword(password)
        // No error thrown means success
    }

    @Test
    func unlockWithWrongPasswordFails() async throws {
        let userDefaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let service = AuthenticationService(
            keychainService: MockKeychainService(),
            userDefaults: userDefaults
        )

        try await service.setUp(password: "CorrectPassword123!", enableBiometric: false)

        await #expect(throws: AuthenticationError.wrongPassword) {
            try await service.unlockWithPassword("WrongPassword123!")
        }
    }

    @Test
    func unlockWithoutSetUpFails() async throws {
        let userDefaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let service = AuthenticationService(
            keychainService: MockKeychainService(),
            userDefaults: userDefaults
        )

        await #expect(throws: AuthenticationError.notSetUp) {
            try await service.unlockWithPassword("SomePassword123!")
        }
    }

    // MARK: - Rate Limiting Tests

    @Test
    func threeFailedAttemptsTriggersLockout() async throws {
        let userDefaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let service = AuthenticationService(
            keychainService: MockKeychainService(),
            userDefaults: userDefaults
        )

        try await service.setUp(password: "CorrectPassword123!", enableBiometric: false)

        // First two failures don't lock
        for _ in 1 ... 2 {
            try? await service.unlockWithPassword("WrongPassword123!")
            #expect(service.isLockedOut == false)
        }

        // Third failure locks
        do {
            try await service.unlockWithPassword("WrongPassword123!")
            Issue.record("Expected accountLocked error")
        } catch let error as AuthenticationError {
            if case .accountLocked = error {
                // Expected
            } else {
                Issue.record("Expected accountLocked, got \(error)")
            }
        }

        #expect(service.isLockedOut == true)
        #expect(service.failedAttemptCount == 3)
    }

    @Test
    func lockoutPreventsUnlockEvenWithCorrectPassword() async throws {
        let userDefaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let service = AuthenticationService(
            keychainService: MockKeychainService(),
            userDefaults: userDefaults
        )

        let password = "CorrectPassword123!"
        try await service.setUp(password: password, enableBiometric: false)

        // Trigger lockout
        for _ in 1 ... 3 {
            try? await service.unlockWithPassword("WrongPassword123!")
        }

        #expect(service.isLockedOut == true)

        // Correct password should still be blocked during lockout
        do {
            try await service.unlockWithPassword(password)
            Issue.record("Expected accountLocked error")
        } catch let error as AuthenticationError {
            if case .accountLocked = error {
                // Expected
            } else {
                Issue.record("Expected accountLocked, got \(error)")
            }
        }
    }

    @Test
    func successfulUnlockResetsFailedAttempts() async throws {
        let userDefaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let service = AuthenticationService(
            keychainService: MockKeychainService(),
            userDefaults: userDefaults
        )

        let password = "CorrectPassword123!"
        try await service.setUp(password: password, enableBiometric: false)

        // Two failed attempts
        for _ in 1 ... 2 {
            try? await service.unlockWithPassword("WrongPassword123!")
        }

        #expect(service.failedAttemptCount == 2)

        // Successful unlock
        try await service.unlockWithPassword(password)

        #expect(service.failedAttemptCount == 0)
    }

    // MARK: - Biometric Tests

    @Test
    func unlockWithBiometricSucceeds() async throws {
        let userDefaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let biometricService = MockBiometricService(isAvailable: true, shouldSucceed: true)
        let service = AuthenticationService(
            biometricService: biometricService,
            userDefaults: userDefaults
        )

        try await service.setUp(password: "MyPassword123!", enableBiometric: true)

        try await service.unlockWithBiometric()
        // No error thrown means success
    }

    @Test
    func unlockWithBiometricFailsWhenNotEnabled() async throws {
        let userDefaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let service = AuthenticationService(
            biometricService: MockBiometricService(isAvailable: true),
            userDefaults: userDefaults
        )

        try await service.setUp(password: "MyPassword123!", enableBiometric: false)

        await #expect(throws: AuthenticationError.biometricNotAvailable) {
            try await service.unlockWithBiometric()
        }
    }

    @Test
    func unlockWithBiometricResetsFailedAttempts() async throws {
        let userDefaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let biometricService = MockBiometricService(isAvailable: true, shouldSucceed: true)
        let service = AuthenticationService(
            biometricService: biometricService,
            userDefaults: userDefaults
        )

        try await service.setUp(password: "MyPassword123!", enableBiometric: true)

        // Create failed attempts
        for _ in 1 ... 2 {
            try? await service.unlockWithPassword("WrongPassword!")
        }

        #expect(service.failedAttemptCount == 2)

        // Biometric unlock should reset
        try await service.unlockWithBiometric()

        #expect(service.failedAttemptCount == 0)
    }

    // MARK: - Biometric Enable/Disable Tests

    @Test
    func enableBiometricSucceedsWhenAvailable() async throws {
        let userDefaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let biometricService = MockBiometricService(isAvailable: true, shouldSucceed: true)
        let service = AuthenticationService(
            biometricService: biometricService,
            userDefaults: userDefaults
        )

        #expect(service.isBiometricEnabled == false)

        try await service.enableBiometric()

        #expect(service.isBiometricEnabled == true)
    }

    @Test
    func enableBiometricFailsWhenNotAvailable() async throws {
        let userDefaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let service = AuthenticationService(
            biometricService: MockBiometricService(isAvailable: false),
            userDefaults: userDefaults
        )

        await #expect(throws: AuthenticationError.biometricNotAvailable) {
            try await service.enableBiometric()
        }

        #expect(service.isBiometricEnabled == false)
    }

    @Test
    func disableBiometricWorks() async throws {
        let userDefaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let service = AuthenticationService(
            biometricService: MockBiometricService(isAvailable: true),
            userDefaults: userDefaults
        )

        try await service.setUp(password: "MyPassword123!", enableBiometric: true)

        #expect(service.isBiometricEnabled == true)

        service.disableBiometric()

        #expect(service.isBiometricEnabled == false)
    }

    // MARK: - Logout Tests

    @Test
    func logoutClearsAllData() async throws {
        let userDefaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let keychainService = MockKeychainService()
        let service = AuthenticationService(
            keychainService: keychainService,
            userDefaults: userDefaults
        )

        try await service.setUp(password: "MyPassword123!", enableBiometric: true)

        #expect(service.isSetUp == true)

        try service.logout()

        #expect(service.isSetUp == false)
        #expect(userDefaults.data(forKey: "com.family-medical-app.salt") == nil)
        #expect(!keychainService.keyExists(identifier: "com.family-medical-app.primary-key"))
    }
}

// MARK: - Mock Services

/// @unchecked Sendable: Safe for tests where mocks are only used from MainActor test contexts
private final class MockKeychainService: KeychainServiceProtocol, @unchecked Sendable {
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

private final class MockBiometricService: BiometricServiceProtocol {
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

// swiftlint:enable password_in_code force_unwrapping
