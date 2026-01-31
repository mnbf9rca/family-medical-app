// swiftlint:disable force_unwrapping
import CryptoKit
import Foundation
import Testing
@testable import FamilyMedicalApp

/// Tests for AuthenticationService duplicate registration handling
@MainActor
struct AuthenticationServiceDuplicateRegistrationTests {
    // MARK: - Duplicate Registration Tests

    @Test
    func setUpThrowsAccountExistsConfirmedWhenAccountExists() async throws {
        let userDefaults = try #require(UserDefaults(suiteName: "test-\(UUID().uuidString)"))
        let opaqueAuthService = MockOpaqueAuthService()
        opaqueAuthService.shouldThrowAccountExistsConfirmed = true

        let service = AuthenticationService(
            keychainService: MockAuthKeychainService(),
            opaqueAuthService: opaqueAuthService,
            userDefaults: userDefaults
        )

        // Should throw accountExistsConfirmed with the login result
        var passwordBytes = Array("MyPassword123!".utf8)
        await #expect(throws: AuthenticationError.self) {
            try await service.setUp(passwordBytes: &passwordBytes, username: "existinguser", enableBiometric: false)
        }

        // Verify registration was attempted
        #expect(opaqueAuthService.registerCallCount == 1)
        // Account should NOT be set up yet (user needs to confirm)
        #expect(service.isSetUp == false)
    }

    @Test
    func completeLoginFromExistingAccountSetsUpAccount() async throws {
        let userDefaults = try #require(UserDefaults(suiteName: "test-\(UUID().uuidString)"))
        let keychainService = MockAuthKeychainService()
        let opaqueAuthService = MockOpaqueAuthService()

        let service = AuthenticationService(
            keychainService: keychainService,
            opaqueAuthService: opaqueAuthService,
            userDefaults: userDefaults
        )

        // Create a login result (simulating what would come from accountExistsConfirmed)
        let loginResult = OpaqueLoginResult(
            exportKey: opaqueAuthService.testExportKey,
            sessionKey: opaqueAuthService.testSessionKey,
            encryptedBundle: nil
        )

        #expect(service.isSetUp == false)

        // Complete login from existing account
        try await service.completeLoginFromExistingAccount(
            loginResult: loginResult,
            username: "existinguser",
            enableBiometric: false
        )

        #expect(service.isSetUp == true)
        #expect(service.storedUsername == "existinguser")
        #expect(userDefaults.bool(forKey: "com.family-medical-app.use-opaque") == true)
        #expect(keychainService.keyExists(identifier: "com.family-medical-app.primary-key"))
    }

    @Test
    func completeLoginFromExistingAccountEnablesBiometric() async throws {
        let userDefaults = try #require(UserDefaults(suiteName: "test-\(UUID().uuidString)"))
        let biometricService = MockAuthBiometricService(isAvailable: true, shouldSucceed: true)
        let opaqueAuthService = MockOpaqueAuthService()

        let service = AuthenticationService(
            biometricService: biometricService,
            opaqueAuthService: opaqueAuthService,
            userDefaults: userDefaults
        )

        let loginResult = OpaqueLoginResult(
            exportKey: opaqueAuthService.testExportKey,
            sessionKey: opaqueAuthService.testSessionKey,
            encryptedBundle: nil
        )

        try await service.completeLoginFromExistingAccount(
            loginResult: loginResult,
            username: "existinguser",
            enableBiometric: true
        )

        #expect(service.isBiometricEnabled == true)
    }
}

// swiftlint:enable force_unwrapping
