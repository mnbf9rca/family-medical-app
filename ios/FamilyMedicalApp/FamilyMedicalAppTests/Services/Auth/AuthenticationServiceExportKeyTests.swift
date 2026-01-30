// swiftlint:disable force_unwrapping
import CryptoKit
import Foundation
import Testing
@testable import FamilyMedicalApp

/// Tests for RFC 9807 §6.4.4 export key validation in AuthenticationService
@MainActor
struct AuthenticationServiceExportKeyTests {
    // MARK: - Export Key Validation Tests (RFC 9807 §6.4.4)

    @Test
    func setUpRejectsEmptyExportKey() async throws {
        let userDefaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let opaqueAuthService = MockOpaqueAuthService()
        opaqueAuthService.testExportKey = Data() // Empty export key

        let service = AuthenticationService(
            keychainService: MockAuthKeychainService(),
            opaqueAuthService: opaqueAuthService,
            userDefaults: userDefaults
        )

        await #expect(throws: AuthenticationError.setupFailed) {
            try await service.setUp(password: "MySecurePassword123!", username: "testuser", enableBiometric: false)
        }
    }

    @Test
    func setUpRejectsInvalidExportKeyLength() async throws {
        let userDefaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let opaqueAuthService = MockOpaqueAuthService()
        opaqueAuthService.testExportKey = Data(repeating: 0x42, count: 16) // Wrong length (not 32 or 64)

        let service = AuthenticationService(
            keychainService: MockAuthKeychainService(),
            opaqueAuthService: opaqueAuthService,
            userDefaults: userDefaults
        )

        await #expect(throws: AuthenticationError.setupFailed) {
            try await service.setUp(password: "MySecurePassword123!", username: "testuser", enableBiometric: false)
        }
    }

    @Test
    func setUpAccepts32ByteExportKey() async throws {
        let userDefaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let opaqueAuthService = MockOpaqueAuthService()
        opaqueAuthService.testExportKey = Data(repeating: 0x42, count: 32)

        let service = AuthenticationService(
            keychainService: MockAuthKeychainService(),
            opaqueAuthService: opaqueAuthService,
            userDefaults: userDefaults
        )

        try await service.setUp(password: "MySecurePassword123!", username: "testuser", enableBiometric: false)
        #expect(service.isSetUp == true)
    }

    @Test
    func setUpAccepts64ByteExportKey() async throws {
        let userDefaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let opaqueAuthService = MockOpaqueAuthService()
        opaqueAuthService.testExportKey = Data(repeating: 0x42, count: 64)

        let service = AuthenticationService(
            keychainService: MockAuthKeychainService(),
            opaqueAuthService: opaqueAuthService,
            userDefaults: userDefaults
        )

        try await service.setUp(password: "MySecurePassword123!", username: "testuser", enableBiometric: false)
        #expect(service.isSetUp == true)
    }

    // MARK: - Unlock Path Export Key Validation Tests

    @Test
    func unlockRejectsEmptyExportKey() async throws {
        let userDefaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let opaqueAuthService = MockOpaqueAuthService()
        let keychainService = MockAuthKeychainService()

        // Set up with valid export key first
        opaqueAuthService.testExportKey = Data(repeating: 0x42, count: 32)
        let service = AuthenticationService(
            keychainService: keychainService,
            opaqueAuthService: opaqueAuthService,
            userDefaults: userDefaults
        )
        try await service.setUp(password: "MySecurePassword123!", username: "testuser", enableBiometric: false)
        #expect(service.isSetUp == true)

        // Change mock to return empty export key during login (unlock path)
        opaqueAuthService.testExportKey = Data()

        await #expect(throws: AuthenticationError.verificationFailed) {
            try await service.unlockWithPassword("MySecurePassword123!")
        }
    }

    @Test
    func unlockRejectsInvalidExportKeyLength() async throws {
        let userDefaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let opaqueAuthService = MockOpaqueAuthService()
        let keychainService = MockAuthKeychainService()

        // Set up with valid export key first
        opaqueAuthService.testExportKey = Data(repeating: 0x42, count: 32)
        let service = AuthenticationService(
            keychainService: keychainService,
            opaqueAuthService: opaqueAuthService,
            userDefaults: userDefaults
        )
        try await service.setUp(password: "MySecurePassword123!", username: "testuser", enableBiometric: false)
        #expect(service.isSetUp == true)

        // Change mock to return invalid length export key during login (unlock path)
        opaqueAuthService.testExportKey = Data(repeating: 0xAB, count: 16)

        await #expect(throws: AuthenticationError.verificationFailed) {
            try await service.unlockWithPassword("MySecurePassword123!")
        }
    }
}

// swiftlint:enable force_unwrapping
