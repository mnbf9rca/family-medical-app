import Foundation
import Observation

/// ViewModel coordinating authentication UI state and actions
@Observable
final class AuthenticationViewModel {
    // MARK: - Authentication State

    var isAuthenticated = false
    var isSetUp: Bool {
        authService.isSetUp
    }

    // MARK: - Password Setup State

    var password = ""
    var confirmPassword = ""
    var passwordStrength: PasswordStrength {
        passwordValidator.passwordStrength(password)
    }

    var passwordValidationErrors: [AuthenticationError] {
        passwordValidator.validate(password)
    }

    var enableBiometric = false

    // MARK: - Unlock State

    var unlockPassword = ""
    var failedAttempts: Int {
        authService.failedAttemptCount
    }

    var isLockedOut: Bool {
        authService.isLockedOut
    }

    var lockoutTimeRemaining: Int {
        authService.lockoutRemainingSeconds
    }

    // MARK: - UI State

    var errorMessage: String?
    var isLoading = false
    var showBiometricPrompt = false

    // MARK: - Dependencies

    private let authService: AuthenticationServiceProtocol
    private let biometricService: BiometricServiceProtocol
    private let passwordValidator: PasswordValidationServiceProtocol
    private let lockStateService: LockStateServiceProtocol

    // MARK: - Initialization

    init(
        authService: AuthenticationServiceProtocol = AuthenticationService(),
        biometricService: BiometricServiceProtocol = BiometricService(),
        passwordValidator: PasswordValidationServiceProtocol = PasswordValidationService(),
        lockStateService: LockStateServiceProtocol = LockStateService()
    ) {
        self.authService = authService
        self.biometricService = biometricService
        self.passwordValidator = passwordValidator
        self.lockStateService = lockStateService

        // Show biometric prompt on launch if enabled
        showBiometricPrompt = authService.isSetUp && authService.isBiometricEnabled
    }

    // MARK: - Setup Actions

    @MainActor
    func setUp() async {
        // Validate passwords
        guard !passwordValidationErrors.isEmpty == false else {
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
            try await authService.setUp(password: password, enableBiometric: enableBiometric)
            isAuthenticated = true

            // Clear password fields
            password = ""
            confirmPassword = ""
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
            isAuthenticated = false
            lockStateService.unlock()
            errorMessage = nil

            // Clear all state
            password = ""
            confirmPassword = ""
            unlockPassword = ""
            showBiometricPrompt = false
        } catch {
            errorMessage = "Failed to logout: \(error.localizedDescription)"
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
}
