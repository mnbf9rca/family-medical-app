// swiftlint:disable force_unwrapping
import CryptoKit
import Foundation
import Testing
@testable import FamilyMedicalApp

/// Rate limiting tests for AuthenticationService
/// Extracted from AuthenticationServiceTests to comply with type_body_length
@MainActor
struct AuthenticationServiceRateLimitingTests {
    @Test
    func threeFailedAttemptsTriggersLockout() async throws {
        let userDefaults = try #require(UserDefaults(suiteName: "test-\(UUID().uuidString)"))
        let opaqueAuthService = MockOpaqueAuthService()
        let service = AuthenticationService(
            keychainService: MockAuthKeychainService(),
            opaqueAuthService: opaqueAuthService,
            userDefaults: userDefaults
        )

        var setUpPasswordBytes = Array("CorrectPassword123!".utf8)
        try await service.setUp(passwordBytes: &setUpPasswordBytes, username: "testuser", enableBiometric: false)

        // Make OPAQUE fail for wrong password
        opaqueAuthService.shouldFailLogin = true

        // First two failures don't lock
        for _ in 1 ... 2 {
            var wrongPasswordBytes = Array("WrongPassword123!".utf8)
            try? await service.unlockWithPassword(&wrongPasswordBytes)
            #expect(service.isLockedOut == false)
        }

        // Third failure locks
        do {
            var wrongPasswordBytes = Array("WrongPassword123!".utf8)
            try await service.unlockWithPassword(&wrongPasswordBytes)
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
        let userDefaults = try #require(UserDefaults(suiteName: "test-\(UUID().uuidString)"))
        let opaqueAuthService = MockOpaqueAuthService()
        let service = AuthenticationService(
            keychainService: MockAuthKeychainService(),
            opaqueAuthService: opaqueAuthService,
            userDefaults: userDefaults
        )

        var setUpPasswordBytes = Array("CorrectPassword123!".utf8)
        try await service.setUp(passwordBytes: &setUpPasswordBytes, username: "testuser", enableBiometric: false)

        // Trigger lockout with failed attempts
        opaqueAuthService.shouldFailLogin = true
        for _ in 1 ... 3 {
            var wrongPasswordBytes = Array("WrongPassword123!".utf8)
            try? await service.unlockWithPassword(&wrongPasswordBytes)
        }

        #expect(service.isLockedOut == true)

        // Even with correct credentials (reset mock), lockout prevents unlock
        opaqueAuthService.shouldFailLogin = false
        do {
            var correctPasswordBytes = Array("CorrectPassword123!".utf8)
            try await service.unlockWithPassword(&correctPasswordBytes)
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
        let userDefaults = try #require(UserDefaults(suiteName: "test-\(UUID().uuidString)"))
        let opaqueAuthService = MockOpaqueAuthService()
        let service = AuthenticationService(
            keychainService: MockAuthKeychainService(),
            opaqueAuthService: opaqueAuthService,
            userDefaults: userDefaults
        )

        var setUpPasswordBytes = Array("CorrectPassword123!".utf8)
        try await service.setUp(passwordBytes: &setUpPasswordBytes, username: "testuser", enableBiometric: false)

        // Two failed attempts
        opaqueAuthService.shouldFailLogin = true
        for _ in 1 ... 2 {
            var wrongPasswordBytes = Array("WrongPassword123!".utf8)
            try? await service.unlockWithPassword(&wrongPasswordBytes)
        }

        #expect(service.failedAttemptCount == 2)

        // Successful unlock (reset mock)
        opaqueAuthService.shouldFailLogin = false
        var correctPasswordBytes = Array("CorrectPassword123!".utf8)
        try await service.unlockWithPassword(&correctPasswordBytes)

        #expect(service.failedAttemptCount == 0)
    }
}

// swiftlint:enable force_unwrapping
