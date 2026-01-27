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

    var flowState: AuthenticationFlowState = .emailEntry

    // MARK: - Email Verification State

    var verificationCode = ""
    var passphrase = ""
    var confirmPassphrase = ""

    // MARK: - Password Setup State (legacy, kept for backward compatibility)

    var email = ""
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

    // Email validation (basic check for @ and .)
    var isEmailValid: Bool {
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        return trimmedEmail.contains("@") && trimmedEmail.contains(".")
    }

    var emailValidationError: String? {
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        if trimmedEmail.isEmpty {
            return nil // Don't show error for empty (show on submit)
        }
        if !isEmailValid {
            return "Please enter a valid email address"
        }
        return nil
    }

    var enableBiometric = false

    // MARK: - Unlock State

    var unlockPassword = ""
    var storedEmail: String {
        authService.storedEmail ?? ""
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
    private let emailVerificationService: EmailVerificationServiceProtocol
    let lockStateService: LockStateServiceProtocol

    // MARK: - Initialization

    init(
        authService: AuthenticationServiceProtocol? = nil,
        biometricService: BiometricServiceProtocol? = nil,
        passwordValidator: PasswordValidationServiceProtocol = PasswordValidationService(),
        lockStateService: LockStateServiceProtocol = LockStateService(),
        emailVerificationService: EmailVerificationServiceProtocol? = nil
    ) {
        self.authService = authService ?? AuthenticationService()
        self.biometricService = biometricService ?? BiometricService()
        self.passwordValidator = passwordValidator
        self.lockStateService = lockStateService
        self.emailVerificationService = emailVerificationService ?? EmailVerificationService()

        // Initialize setup state from authService
        isSetUp = self.authService.isSetUp

        // Set initial flow state based on setup status
        if self.authService.isSetUp {
            flowState = .unlock
        } else {
            flowState = .emailEntry
        }

        // Show biometric prompt on launch if enabled
        showBiometricPrompt = self.authService.isSetUp && self.authService.isBiometricEnabled
    }

    // MARK: - Setup Actions

    @MainActor
    func setUp() async {
        // Mark that user has attempted setup (enables error display)
        hasAttemptedSetup = true

        // Validate email
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        guard !trimmedEmail.isEmpty else {
            errorMessage = "Please enter an email address"
            return
        }
        guard isEmailValid else {
            errorMessage = "Please enter a valid email address"
            return
        }

        // Validate passwords - check for validation errors
        if !passwordValidationErrors.isEmpty {
            errorMessage = passwordValidationErrors.first?.errorDescription
            return
        }

        // Ensure passwords match
        guard password == confirmPassword else {
            errorMessage = AuthenticationError.passwordMismatch.errorDescription
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            try await authService.setUp(password: password, email: trimmedEmail, enableBiometric: enableBiometric)
            isSetUp = true // Update stored property to trigger view update
            isAuthenticated = true

            // Clear fields
            email = ""
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
            lockStateService.unlock()

            // Clear password field
            unlockPassword = ""
        } catch let error as AuthenticationError {
            errorMessage = error.errorDescription
            // Don't clear password on lockout so user can see their attempt
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
            lockStateService.unlock()
        } catch let error as AuthenticationError {
            // If biometric fails, show password option
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
        lockStateService.lock()
        errorMessage = nil
        unlockPassword = ""

        // Show biometric prompt again if enabled
        showBiometricPrompt = authService.isBiometricEnabled
    }

    @MainActor
    func logout() async {
        do {
            try authService.logout()
            isSetUp = false // Update stored property
            isAuthenticated = false
            lockStateService.unlock()
            errorMessage = nil

            // Clear all state
            password = ""
            confirmPassword = ""
            unlockPassword = ""
            showBiometricPrompt = false
        } catch {
            // Don't expose technical error details to users
            // TODO: Add proper logging when logging infrastructure is available
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

    func performSendVerificationCode(to email: String) async throws {
        try await emailVerificationService.sendVerificationCode(to: email)
    }

    func performVerifyCode(_ code: String, for email: String) async throws -> EmailVerificationResult {
        try await emailVerificationService.verifyCode(code, for: email)
    }

    func validatePassphrase(_ passphrase: String) -> [AuthenticationError] {
        passwordValidator.validate(passphrase)
    }

    func performUnlockWithPassword(_ password: String) async throws {
        try await authService.unlockWithPassword(password)
    }

    func performSetUp(password: String, email: String, enableBiometric: Bool) async throws {
        try await authService.setUp(password: password, email: email, enableBiometric: enableBiometric)
    }

    func clearSensitiveFields() {
        email = ""
        verificationCode = ""
        passphrase = ""
        confirmPassphrase = ""
        password = ""
        confirmPassword = ""
    }
}
