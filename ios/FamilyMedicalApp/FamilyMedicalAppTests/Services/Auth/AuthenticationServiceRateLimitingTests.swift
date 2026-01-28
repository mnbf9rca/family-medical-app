// swiftlint:disable password_in_code force_unwrapping
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
        let userDefaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let opaqueAuthService = MockOpaqueAuthService()
        let service = AuthenticationService(
            keychainService: MockAuthKeychainService(),
            opaqueAuthService: opaqueAuthService,
            userDefaults: userDefaults
        )

        try await service.setUp(password: "CorrectPassword123!", username: "testuser", enableBiometric: false)

        // Make OPAQUE fail for wrong password
        opaqueAuthService.shouldFailLogin = true

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
        let opaqueAuthService = MockOpaqueAuthService()
        let service = AuthenticationService(
            keychainService: MockAuthKeychainService(),
            opaqueAuthService: opaqueAuthService,
            userDefaults: userDefaults
        )

        let password = "CorrectPassword123!"
        try await service.setUp(password: password, username: "testuser", enableBiometric: false)

        // Trigger lockout with failed attempts
        opaqueAuthService.shouldFailLogin = true
        for _ in 1 ... 3 {
            try? await service.unlockWithPassword("WrongPassword123!")
        }

        #expect(service.isLockedOut == true)

        // Even with correct credentials (reset mock), lockout prevents unlock
        opaqueAuthService.shouldFailLogin = false
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
        let opaqueAuthService = MockOpaqueAuthService()
        let service = AuthenticationService(
            keychainService: MockAuthKeychainService(),
            opaqueAuthService: opaqueAuthService,
            userDefaults: userDefaults
        )

        let password = "CorrectPassword123!"
        try await service.setUp(password: password, username: "testuser", enableBiometric: false)

        // Two failed attempts
        opaqueAuthService.shouldFailLogin = true
        for _ in 1 ... 2 {
            try? await service.unlockWithPassword("WrongPassword123!")
        }

        #expect(service.failedAttemptCount == 2)

        // Successful unlock (reset mock)
        opaqueAuthService.shouldFailLogin = false
        try await service.unlockWithPassword(password)

        #expect(service.failedAttemptCount == 0)
    }
}

// swiftlint:enable password_in_code force_unwrapping
