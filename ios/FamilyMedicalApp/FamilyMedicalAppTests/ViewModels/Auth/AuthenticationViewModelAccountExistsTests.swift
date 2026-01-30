import Foundation
import Testing
@testable import FamilyMedicalApp

/// Tests for AuthenticationViewModel account exists confirmation flow (duplicate registration)
@MainActor
struct AuthenticationViewModelAccountExistsTests {
    // MARK: - Test Constants

    private let validPassphrase = "valid-test-passphrase-123"

    // MARK: - Account Exists Confirmation Tests (Duplicate Registration)

    @Test
    func completeSetupTransitionsToAccountExistsConfirmationWhenAccountExists() async {
        // Create a mock service that throws accountExistsConfirmed
        let authService = MockAuthenticationServiceWithAccountExists(shouldThrowAccountExists: true)
        let viewModel = AuthenticationViewModel(authService: authService)
        viewModel.flowState = .biometricSetup(
            username: "existinguser",
            passphrase: validPassphrase,
            isReturningUser: false
        )

        await viewModel.completeSetup(enableBiometric: false)

        // Should transition to accountExistsConfirmation state
        if case let .accountExistsConfirmation(username, _, _) = viewModel.flowState {
            #expect(username == "existinguser")
        } else {
            Issue.record("Expected accountExistsConfirmation state but got \(viewModel.flowState)")
        }
        // Account should NOT be set up yet
        #expect(viewModel.isSetUp == false)
        #expect(viewModel.isAuthenticated == false)
    }

    @Test
    func confirmExistingAccountCompletesLogin() async {
        let authService = MockAuthenticationService(isSetUp: false)
        let viewModel = AuthenticationViewModel(authService: authService)
        let loginResult = OpaqueLoginResult(
            exportKey: Data(repeating: 0x42, count: 32),
            sessionKey: Data(repeating: 0x43, count: 32),
            encryptedBundle: nil
        )
        viewModel.flowState = .accountExistsConfirmation(
            username: "existinguser",
            loginResult: loginResult,
            enableBiometric: false
        )

        await viewModel.confirmExistingAccount()

        #expect(viewModel.flowState == .authenticated)
        #expect(viewModel.isSetUp == true)
        #expect(viewModel.isAuthenticated == true)
    }

    @Test
    func cancelExistingAccountConfirmationReturnsToUsernameEntry() {
        let authService = MockAuthenticationService(isSetUp: false)
        let viewModel = AuthenticationViewModel(authService: authService)
        let loginResult = OpaqueLoginResult(
            exportKey: Data(repeating: 0x42, count: 32),
            sessionKey: Data(repeating: 0x43, count: 32),
            encryptedBundle: nil
        )
        viewModel.flowState = .accountExistsConfirmation(
            username: "existinguser",
            loginResult: loginResult,
            enableBiometric: false
        )
        viewModel.passphrase = "somepassphrase"

        viewModel.cancelExistingAccountConfirmation()

        #expect(viewModel.flowState == .usernameEntry(isNewUser: true))
        // Sensitive fields should be cleared
        #expect(viewModel.passphrase.isEmpty)
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    func confirmExistingAccountWithBiometricEnabled() async {
        let authService = MockAuthenticationService(isSetUp: false)
        let biometricService = MockViewModelBiometricService(isAvailable: true)
        let viewModel = AuthenticationViewModel(
            authService: authService,
            biometricService: biometricService
        )
        let loginResult = OpaqueLoginResult(
            exportKey: Data(repeating: 0x42, count: 32),
            sessionKey: Data(repeating: 0x43, count: 32),
            encryptedBundle: nil
        )
        viewModel.flowState = .accountExistsConfirmation(
            username: "existinguser",
            loginResult: loginResult,
            enableBiometric: true
        )

        await viewModel.confirmExistingAccount()

        #expect(viewModel.flowState == .authenticated)
        #expect(viewModel.isSetUp == true)
        #expect(authService.isBiometricEnabled == true)
    }
}

// MARK: - Mock for Account Exists Test

/// Mock service that can throw accountExistsConfirmed error during setUp
/// Uses nonisolated(unsafe) for properties accessed from non-@MainActor protocol methods
private final class MockAuthenticationServiceWithAccountExists: AuthenticationServiceProtocol {
    nonisolated(unsafe) var isSetUp: Bool = false
    nonisolated(unsafe) var isBiometricEnabled: Bool = false
    nonisolated(unsafe) var failedAttemptCount: Int = 0
    nonisolated(unsafe) var isLockedOut: Bool = false
    nonisolated(unsafe) var lockoutRemainingSeconds: Int = 0
    nonisolated(unsafe) var storedUsername: String?

    nonisolated(unsafe) var shouldThrowAccountExists: Bool

    init(shouldThrowAccountExists: Bool) {
        self.shouldThrowAccountExists = shouldThrowAccountExists
    }

    func setUp(password: String, username: String, enableBiometric: Bool) async throws {
        if shouldThrowAccountExists {
            let loginResult = OpaqueLoginResult(
                exportKey: Data(repeating: 0x42, count: 32),
                sessionKey: Data(repeating: 0x43, count: 32),
                encryptedBundle: nil
            )
            throw AuthenticationError.accountExistsConfirmed(loginResult: loginResult)
        }
        isSetUp = true
        storedUsername = username
        isBiometricEnabled = enableBiometric
    }

    func loginAndSetup(password: String, username: String, enableBiometric: Bool) async throws {
        isSetUp = true
        storedUsername = username
        isBiometricEnabled = enableBiometric
    }

    func completeLoginFromExistingAccount(
        loginResult: OpaqueLoginResult,
        username: String,
        enableBiometric: Bool
    ) async throws {
        isSetUp = true
        storedUsername = username
        isBiometricEnabled = enableBiometric
    }

    func unlockWithPassword(_ password: String) async throws {}
    func unlockWithBiometric() async throws {}
    func lock() {}
    func logout() throws { isSetUp = false }
    func disableBiometric() { isBiometricEnabled = false }
    func enableBiometric() async throws { isBiometricEnabled = true }

    // MARK: - Bytes-Based Methods (RFC 9807)

    func setUp(passwordBytes: inout [UInt8], username: String, enableBiometric: Bool) async throws {
        for index in passwordBytes.indices {
            passwordBytes[index] = 0
        }
        try await setUp(password: "", username: username, enableBiometric: enableBiometric)
    }

    func loginAndSetup(passwordBytes: inout [UInt8], username: String, enableBiometric: Bool) async throws {
        for index in passwordBytes.indices {
            passwordBytes[index] = 0
        }
        try await loginAndSetup(password: "", username: username, enableBiometric: enableBiometric)
    }

    func unlockWithPassword(_ passwordBytes: inout [UInt8]) async throws {
        for index in passwordBytes.indices {
            passwordBytes[index] = 0
        }
    }
}
