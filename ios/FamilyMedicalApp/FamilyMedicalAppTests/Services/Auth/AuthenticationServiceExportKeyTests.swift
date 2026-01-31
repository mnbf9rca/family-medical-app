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
        let userDefaults = try #require(UserDefaults(suiteName: "test-\(UUID().uuidString)"))
        let opaqueAuthService = MockOpaqueAuthService()
        opaqueAuthService.testExportKey = Data() // Empty export key

        let service = AuthenticationService(
            keychainService: MockAuthKeychainService(),
            opaqueAuthService: opaqueAuthService,
            userDefaults: userDefaults
        )

        var passwordBytes = Array("MySecurePassword123!".utf8)
        await #expect(throws: AuthenticationError.setupFailed) {
            try await service.setUp(passwordBytes: &passwordBytes, username: "testuser", enableBiometric: false)
        }
    }

    @Test
    func setUpRejectsInvalidExportKeyLength() async throws {
        let userDefaults = try #require(UserDefaults(suiteName: "test-\(UUID().uuidString)"))
        let opaqueAuthService = MockOpaqueAuthService()
        opaqueAuthService.testExportKey = Data(repeating: 0x42, count: 16) // Wrong length (not 32 or 64)

        let service = AuthenticationService(
            keychainService: MockAuthKeychainService(),
            opaqueAuthService: opaqueAuthService,
            userDefaults: userDefaults
        )

        var passwordBytes = Array("MySecurePassword123!".utf8)
        await #expect(throws: AuthenticationError.setupFailed) {
            try await service.setUp(passwordBytes: &passwordBytes, username: "testuser", enableBiometric: false)
        }
    }

    @Test
    func setUpAccepts32ByteExportKey() async throws {
        let userDefaults = try #require(UserDefaults(suiteName: "test-\(UUID().uuidString)"))
        let opaqueAuthService = MockOpaqueAuthService()
        opaqueAuthService.testExportKey = Data(repeating: 0x42, count: 32)

        let service = AuthenticationService(
            keychainService: MockAuthKeychainService(),
            opaqueAuthService: opaqueAuthService,
            userDefaults: userDefaults
        )

        var passwordBytes = Array("MySecurePassword123!".utf8)
        try await service.setUp(passwordBytes: &passwordBytes, username: "testuser", enableBiometric: false)
        #expect(service.isSetUp == true)
    }

    @Test
    func setUpAccepts64ByteExportKey() async throws {
        let userDefaults = try #require(UserDefaults(suiteName: "test-\(UUID().uuidString)"))
        let opaqueAuthService = MockOpaqueAuthService()
        opaqueAuthService.testExportKey = Data(repeating: 0x42, count: 64)

        let service = AuthenticationService(
            keychainService: MockAuthKeychainService(),
            opaqueAuthService: opaqueAuthService,
            userDefaults: userDefaults
        )

        var passwordBytes = Array("MySecurePassword123!".utf8)
        try await service.setUp(passwordBytes: &passwordBytes, username: "testuser", enableBiometric: false)
        #expect(service.isSetUp == true)
    }

    // MARK: - Unlock Path Export Key Validation Tests

    @Test
    func unlockRejectsEmptyExportKey() async throws {
        let userDefaults = try #require(UserDefaults(suiteName: "test-\(UUID().uuidString)"))
        let opaqueAuthService = MockOpaqueAuthService()
        let keychainService = MockAuthKeychainService()

        // Set up with valid export key first
        opaqueAuthService.testExportKey = Data(repeating: 0x42, count: 32)
        let service = AuthenticationService(
            keychainService: keychainService,
            opaqueAuthService: opaqueAuthService,
            userDefaults: userDefaults
        )
        var setUpPasswordBytes = Array("MySecurePassword123!".utf8)
        try await service.setUp(passwordBytes: &setUpPasswordBytes, username: "testuser", enableBiometric: false)
        #expect(service.isSetUp == true)

        // Change mock to return empty export key during login (unlock path)
        opaqueAuthService.testExportKey = Data()

        var unlockPasswordBytes = Array("MySecurePassword123!".utf8)
        await #expect(throws: AuthenticationError.verificationFailed) {
            try await service.unlockWithPassword(&unlockPasswordBytes)
        }
    }

    @Test
    func unlockRejectsInvalidExportKeyLength() async throws {
        let userDefaults = try #require(UserDefaults(suiteName: "test-\(UUID().uuidString)"))
        let opaqueAuthService = MockOpaqueAuthService()
        let keychainService = MockAuthKeychainService()

        // Set up with valid export key first
        opaqueAuthService.testExportKey = Data(repeating: 0x42, count: 32)
        let service = AuthenticationService(
            keychainService: keychainService,
            opaqueAuthService: opaqueAuthService,
            userDefaults: userDefaults
        )
        var setUpPasswordBytes = Array("MySecurePassword123!".utf8)
        try await service.setUp(passwordBytes: &setUpPasswordBytes, username: "testuser", enableBiometric: false)
        #expect(service.isSetUp == true)

        // Change mock to return invalid length export key during login (unlock path)
        opaqueAuthService.testExportKey = Data(repeating: 0xAB, count: 16)

        var unlockPasswordBytes = Array("MySecurePassword123!".utf8)
        await #expect(throws: AuthenticationError.verificationFailed) {
            try await service.unlockWithPassword(&unlockPasswordBytes)
        }
    }
}

// swiftlint:enable force_unwrapping
