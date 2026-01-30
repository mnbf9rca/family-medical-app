// swiftlint:disable force_unwrapping
import CryptoKit
import Foundation
import Testing
@testable import FamilyMedicalApp

/// Tests for AuthenticationService.loginAndSetup() - returning users on new devices
@MainActor
struct AuthenticationServiceLoginAndSetupTests {
    @Test
    func loginAndSetupSucceedsWithValidCredentials() async throws {
        let userDefaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let keychainService = MockKeychainService()
        let opaqueAuthService = MockOpaqueAuthService()
        let service = AuthenticationService(
            keychainService: keychainService,
            opaqueAuthService: opaqueAuthService,
            userDefaults: userDefaults
        )

        #expect(service.isSetUp == false)

        try await service.loginAndSetup(password: "MySecurePassword123!", username: "testuser", enableBiometric: false)

        #expect(service.isSetUp == true)
        #expect(opaqueAuthService.loginCallCount == 1)
        #expect(opaqueAuthService.lastLoginUsername == "testuser")
        #expect(userDefaults.bool(forKey: "com.family-medical-app.use-opaque") == true)
        #expect(keychainService.keyExists(identifier: "com.family-medical-app.primary-key"))
        #expect(keychainService.dataExists(identifier: "com.family-medical-app.identity-private-key"))
        #expect(keychainService.dataExists(identifier: "com.family-medical-app.verification-token"))
    }

    @Test
    func loginAndSetupStoresUsername() async throws {
        let userDefaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let opaqueAuthService = MockOpaqueAuthService()
        let service = AuthenticationService(
            keychainService: MockKeychainService(),
            opaqueAuthService: opaqueAuthService,
            userDefaults: userDefaults
        )

        try await service.loginAndSetup(password: "MySecurePassword123!", username: "testuser", enableBiometric: false)

        #expect(service.storedUsername == "testuser")
    }

    @Test
    func loginAndSetupEnablesBiometricWhenRequested() async throws {
        let userDefaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let biometricService = MockBiometricService(isAvailable: true)
        let opaqueAuthService = MockOpaqueAuthService()
        let service = AuthenticationService(
            biometricService: biometricService,
            opaqueAuthService: opaqueAuthService,
            userDefaults: userDefaults
        )

        try await service.loginAndSetup(password: "MySecurePassword123!", username: "testuser", enableBiometric: true)

        #expect(service.isBiometricEnabled == true)
    }

    @Test
    func loginAndSetupThrowsWrongPasswordOnAuthFailure() async throws {
        let userDefaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let opaqueAuthService = MockOpaqueAuthService()
        opaqueAuthService.shouldFailLogin = true
        let service = AuthenticationService(
            keychainService: MockKeychainService(),
            opaqueAuthService: opaqueAuthService,
            userDefaults: userDefaults
        )

        await #expect(throws: AuthenticationError.wrongPassword) {
            try await service.loginAndSetup(password: "WrongPassword123!", username: "testuser", enableBiometric: false)
        }

        #expect(service.isSetUp == false)
    }
}

// MARK: - Mock Services (file-local)

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

// swiftlint:enable force_unwrapping
