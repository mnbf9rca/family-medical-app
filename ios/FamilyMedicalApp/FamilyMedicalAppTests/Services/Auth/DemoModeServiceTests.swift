import CryptoKit
import Foundation
import Testing
@testable import FamilyMedicalApp

struct DemoModeServiceTests {
    // MARK: - Setup

    private func makeTestDefaults() throws -> UserDefaults {
        let suiteName = "test-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    // MARK: - Demo Credentials Tests

    @Test
    func demoCredentials_areDeterministic() {
        #expect(DemoModeService.demoUsername == "demo-user")
        #expect(DemoModeService.demoPassphrase == "Demo-Mode-Sample-2024!")
    }

    @Test
    func demoPrimaryKeyIdentifier_usesDemoPrefix() {
        #expect(DemoModeService.demoPrimaryKeyIdentifier.contains(".demo."))
    }

    @Test
    func demoIdentityPrivateKeyIdentifier_usesDemoPrefix() {
        #expect(DemoModeService.demoIdentityPrivateKeyIdentifier.contains(".demo."))
    }

    @Test
    func demoVerificationTokenIdentifier_usesDemoPrefix() {
        #expect(DemoModeService.demoVerificationTokenIdentifier.contains(".demo."))
    }

    // MARK: - Enter Demo Mode Tests

    @Test
    func enterDemoMode_setsIsDemoModeTrue() async throws {
        let testDefaults = try makeTestDefaults()
        let mockKeychainService = MockDemoKeychainService()
        let mockLockStateService = MockLockStateService()
        let sut = DemoModeService(
            keychainService: mockKeychainService,
            lockStateService: mockLockStateService,
            userDefaults: testDefaults
        )

        try await sut.enterDemoMode()

        #expect(mockLockStateService.isDemoMode == true)
    }

    @Test
    func enterDemoMode_storesDemoKeyInKeychain() async throws {
        let testDefaults = try makeTestDefaults()
        let mockKeychainService = MockDemoKeychainService()
        let mockLockStateService = MockLockStateService()
        let sut = DemoModeService(
            keychainService: mockKeychainService,
            lockStateService: mockLockStateService,
            userDefaults: testDefaults
        )

        try await sut.enterDemoMode()

        #expect(mockKeychainService.storeKeyIdentifiers.contains(DemoModeService.demoPrimaryKeyIdentifier))
    }

    @Test
    func enterDemoMode_storesDemoUsername() async throws {
        let testDefaults = try makeTestDefaults()
        let mockKeychainService = MockDemoKeychainService()
        let mockLockStateService = MockLockStateService()
        let sut = DemoModeService(
            keychainService: mockKeychainService,
            lockStateService: mockLockStateService,
            userDefaults: testDefaults
        )

        try await sut.enterDemoMode()

        #expect(testDefaults.string(forKey: "com.family-medical-app.demo.username") == "demo-user")
    }

    // MARK: - Exit Demo Mode Tests

    @Test
    func exitDemoMode_clearsIsDemoMode() async throws {
        let testDefaults = try makeTestDefaults()
        let mockKeychainService = MockDemoKeychainService()
        let mockLockStateService = MockLockStateService()
        let sut = DemoModeService(
            keychainService: mockKeychainService,
            lockStateService: mockLockStateService,
            userDefaults: testDefaults
        )

        // Enter demo mode first
        try await sut.enterDemoMode()

        // Exit demo mode
        await sut.exitDemoMode()

        #expect(mockLockStateService.isDemoMode == false)
    }

    @Test
    func exitDemoMode_deletesDemoKeyFromKeychain() async throws {
        let testDefaults = try makeTestDefaults()
        let mockKeychainService = MockDemoKeychainService()
        let mockLockStateService = MockLockStateService()
        let sut = DemoModeService(
            keychainService: mockKeychainService,
            lockStateService: mockLockStateService,
            userDefaults: testDefaults
        )

        // Enter demo mode first
        try await sut.enterDemoMode()

        // Exit demo mode
        await sut.exitDemoMode()

        #expect(mockKeychainService.deletedKeyIdentifiers.contains(DemoModeService.demoPrimaryKeyIdentifier))
    }

    @Test
    func exitDemoMode_clearsDemoUsername() async throws {
        let testDefaults = try makeTestDefaults()
        let mockKeychainService = MockDemoKeychainService()
        let mockLockStateService = MockLockStateService()
        let sut = DemoModeService(
            keychainService: mockKeychainService,
            lockStateService: mockLockStateService,
            userDefaults: testDefaults
        )

        // Enter demo mode first
        try await sut.enterDemoMode()

        // Exit demo mode
        await sut.exitDemoMode()

        #expect(testDefaults.string(forKey: "com.family-medical-app.demo.username") == nil)
    }

    // MARK: - isInDemoMode Tests

    @Test
    func isInDemoMode_returnsFalseInitially() {
        let testDefaults = try makeTestDefaults()
        let mockKeychainService = MockDemoKeychainService()
        let mockLockStateService = MockLockStateService()
        let sut = DemoModeService(
            keychainService: mockKeychainService,
            lockStateService: mockLockStateService,
            userDefaults: testDefaults
        )

        #expect(sut.isInDemoMode == false)
    }

    @Test
    func isInDemoMode_returnsTrueAfterEnterDemoMode() async throws {
        let testDefaults = try makeTestDefaults()
        let mockKeychainService = MockDemoKeychainService()
        let mockLockStateService = MockLockStateService()
        let sut = DemoModeService(
            keychainService: mockKeychainService,
            lockStateService: mockLockStateService,
            userDefaults: testDefaults
        )

        try await sut.enterDemoMode()

        #expect(sut.isInDemoMode == true)
    }
}
