import Foundation
import Observation

/// ViewModel coordinating authentication UI state and actions
@MainActor
@Observable
final class AuthenticationViewModel {
    // MARK: - Authentication State

    var isAuthenticated = false
    var isSetUp = false

    // MARK: - Flow State

    var flowState: AuthenticationFlowState = .welcome

    // MARK: - Username/Passphrase State

    var username = ""
    var passphrase = ""
    var confirmPassphrase = ""

    // MARK: - Password Setup State (legacy, kept for backward compatibility)

    var password = ""
    var confirmPassword = ""
    var hasAttemptedSetup = false // Track if user has tried to submit
    var hasConfirmFieldLostFocus = false // Track if confirm field has lost focus for validation

    var passwordStrength: PasswordStrength {
        passwordValidator.passwordStrength(password)
    }

    var passwordValidationErrors: [AuthenticationError] {
        passwordValidator.validate(password)
    }

    // MARK: - Passphrase Validation (for new flow)

    var passphraseStrength: PasswordStrength {
        passwordValidator.passwordStrength(passphrase)
    }

    var passphraseValidationErrors: [AuthenticationError] {
        passwordValidator.validate(passphrase)
    }

    // Only show validation errors after user attempts setup
    var displayedValidationErrors: [AuthenticationError] {
        hasAttemptedSetup ? passwordValidationErrors : []
    }

    // Show password mismatch only after confirm field loses focus or has content
    var shouldShowPasswordMismatch: Bool {
        (hasConfirmFieldLostFocus || !confirmPassword.isEmpty) &&
            !password.isEmpty &&
            password != confirmPassword
    }

    // Username validation (basic check for non-empty)
    var isUsernameValid: Bool {
        let trimmed = username.trimmingCharacters(in: .whitespaces)
        return trimmed.count >= 3
    }

    var usernameValidationError: String? {
        let trimmed = username.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            return nil // Don't show error for empty (show on submit)
        }
        if trimmed.count < 3 {
            return "Username must be at least 3 characters"
        }
        return nil
    }

    var enableBiometric = false

    // MARK: - Unlock State

    var unlockPassword = ""
    var storedUsername: String {
        authService.storedUsername ?? ""
    }

    var failedAttempts: Int {
        authService.failedAttemptCount
    }

    var isLockedOut: Bool {
        authService.isLockedOut
    }

    var lockoutTimeRemaining: Int {
        authService.lockoutRemainingSeconds
    }

    // MARK: - Biometric Properties

    @MainActor var biometryType: BiometryType {
        biometricService.biometryType
    }

    @MainActor var isBiometricAvailable: Bool {
        biometricService.isBiometricAvailable
    }

    var isBiometricEnabled: Bool {
        authService.isBiometricEnabled
    }

    // MARK: - UI State

    var errorMessage: String?
    var isLoading = false
    var showBiometricPrompt = false

    // MARK: - Dependencies

    private let authService: AuthenticationServiceProtocol
    private let biometricService: BiometricServiceProtocol
    private let passwordValidator: PasswordValidationServiceProtocol
    let lockStateService: LockStateServiceProtocol

    // MARK: - Initialization

    init(
        authService: AuthenticationServiceProtocol? = nil,
        biometricService: BiometricServiceProtocol? = nil,
        passwordValidator: PasswordValidationServiceProtocol = PasswordValidationService(),
        lockStateService: LockStateServiceProtocol = LockStateService()
    ) {
        self.authService = authService ?? AuthenticationService()
        self.biometricService = biometricService ?? BiometricService()
        self.passwordValidator = passwordValidator
        self.lockStateService = lockStateService

        // Initialize setup state from authService
        isSetUp = self.authService.isSetUp

        // Set initial flow state based on setup status
        if self.authService.isSetUp {
            flowState = .unlock
        } else {
            flowState = .welcome
        }

        // Show biometric prompt on launch if enabled
        showBiometricPrompt = self.authService.isSetUp && self.authService.isBiometricEnabled
    }

    // MARK: - Setup Actions (legacy - kept for tests)

    @MainActor
    func setUp() async {
        hasAttemptedSetup = true

        let trimmedUsername = username.trimmingCharacters(in: .whitespaces)
        guard !trimmedUsername.isEmpty else {
            errorMessage = "Please enter a username"
            return
        }
        guard isUsernameValid else {
            errorMessage = "Username must be at least 3 characters"
            return
        }

        if !passwordValidationErrors.isEmpty {
            errorMessage = passwordValidationErrors.first?.errorDescription
            return
        }

        guard password == confirmPassword else {
            errorMessage = AuthenticationError.passwordMismatch.errorDescription
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            try await authService.setUp(password: password, username: trimmedUsername, enableBiometric: enableBiometric)
            isSetUp = true
            isAuthenticated = true

            username = ""
            password = ""
            confirmPassword = ""
            hasAttemptedSetup = false
            hasConfirmFieldLostFocus = false
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Unlock Actions

    @MainActor
    func unlockWithPassword() async {
        guard !unlockPassword.isEmpty else {
            errorMessage = "Please enter your password"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            try await authService.unlockWithPassword(unlockPassword)
            isAuthenticated = true
            flowState = .authenticated
            lockStateService.unlock()

            unlockPassword = ""
        } catch let error as AuthenticationError {
            errorMessage = error.errorDescription
            if case .accountLocked = error {
                // Keep password, show lockout message
            } else {
                unlockPassword = ""
            }
        } catch {
            errorMessage = error.localizedDescription
            unlockPassword = ""
        }

        isLoading = false
    }

    @MainActor
    func unlockWithBiometric() async {
        isLoading = true
        errorMessage = nil
        showBiometricPrompt = false

        do {
            try await authService.unlockWithBiometric()
            isAuthenticated = true
            flowState = .authenticated
            lockStateService.unlock()
        } catch let error as AuthenticationError {
            if error != .biometricCancelled {
                errorMessage = error.errorDescription
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    @MainActor
    func attemptBiometricOnAppear() async {
        guard showBiometricPrompt, !isAuthenticated else {
            return
        }

        await unlockWithBiometric()
    }

    // MARK: - Lock/Logout Actions

    func lock() {
        isAuthenticated = false
        flowState = .unlock
        lockStateService.lock()
        errorMessage = nil
        unlockPassword = ""

        showBiometricPrompt = authService.isBiometricEnabled
    }

    @MainActor
    func logout() async {
        do {
            try authService.logout()
            isSetUp = false
            isAuthenticated = false
            flowState = .welcome
            lockStateService.unlock()
            errorMessage = nil

            password = ""
            confirmPassword = ""
            unlockPassword = ""
            username = ""
            passphrase = ""
            confirmPassphrase = ""
            showBiometricPrompt = false
        } catch {
            errorMessage = "Unable to logout. Please try again or restart the app."
        }
    }

    // MARK: - Biometric Settings

    @MainActor
    func toggleBiometric() async {
        if authService.isBiometricEnabled {
            authService.disableBiometric()
            showBiometricPrompt = false
        } else {
            do {
                try await authService.enableBiometric()
                showBiometricPrompt = true
            } catch let error as AuthenticationError {
                errorMessage = error.errorDescription
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Internal Helpers for Extension

    func validatePassphrase(_ passphrase: String) -> [AuthenticationError] {
        passwordValidator.validate(passphrase)
    }

    func performUnlockWithPassword(_ password: String) async throws {
        try await authService.unlockWithPassword(password)
    }

    func performSetUp(password: String, username: String, enableBiometric: Bool) async throws {
        try await authService.setUp(password: password, username: username, enableBiometric: enableBiometric)
    }

    func performLoginAndSetup(password: String, username: String, enableBiometric: Bool) async throws {
        try await authService.loginAndSetup(password: password, username: username, enableBiometric: enableBiometric)
    }

    func performCompleteLoginFromExistingAccount(
        loginResult: OpaqueLoginResult,
        username: String,
        enableBiometric: Bool
    ) async throws {
        try await authService.completeLoginFromExistingAccount(
            loginResult: loginResult,
            username: username,
            enableBiometric: enableBiometric
        )
    }

    func clearSensitiveFields() {
        username = ""
        passphrase = ""
        confirmPassphrase = ""
        password = ""
        confirmPassword = ""
    }
}
