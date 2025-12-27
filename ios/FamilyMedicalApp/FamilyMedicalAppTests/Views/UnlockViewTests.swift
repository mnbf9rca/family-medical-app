import SwiftUI
import Testing
@testable import FamilyMedicalApp

/// Tests for UnlockView rendering logic
@MainActor
struct UnlockViewTests {
    // MARK: - View Body Tests

    @Test
    func unlockViewRendersWithPasswordAuth() {
        let authService = MockAuthenticationService(isSetUp: true, isBiometricEnabled: false)
        let viewModel = AuthenticationViewModel(authService: authService)

        let view = UnlockView(viewModel: viewModel)

        // Access body to execute view code for coverage
        _ = view.body
    }

    @Test
    func unlockViewRendersWithBiometricAuth() {
        let biometricService = MockViewModelBiometricService(isAvailable: true, biometryType: .faceID)
        let authService = MockAuthenticationService(isSetUp: true, isBiometricEnabled: true)
        let viewModel = AuthenticationViewModel(
            authService: authService,
            biometricService: biometricService
        )

        let view = UnlockView(viewModel: viewModel)

        // Access body to execute view code for coverage
        _ = view.body
    }

    @Test
    func unlockViewRendersWithFailedAttempts() {
        let authService = MockAuthenticationService(isSetUp: true, failedAttemptCount: 2)
        let viewModel = AuthenticationViewModel(authService: authService)

        let view = UnlockView(viewModel: viewModel)

        // Access body to execute view code for coverage
        _ = view.body
    }

    @Test
    func unlockViewRendersWithLockout() {
        let authService = MockAuthenticationService(
            isSetUp: true,
            isLockedOut: true,
            lockoutRemainingSeconds: 30
        )
        let viewModel = AuthenticationViewModel(authService: authService)

        let view = UnlockView(viewModel: viewModel)

        // Access body to execute view code for coverage
        _ = view.body
    }

    @Test
    func unlockViewRendersWithError() {
        let authService = MockAuthenticationService(isSetUp: true)
        let viewModel = AuthenticationViewModel(authService: authService)
        viewModel.errorMessage = "Test error message"

        let view = UnlockView(viewModel: viewModel)

        // Access body to execute view code for coverage
        _ = view.body
    }

    @Test
    func unlockViewRendersWithBothAuthMethods() {
        let biometricService = MockViewModelBiometricService(isAvailable: true, biometryType: .touchID)
        let authService = MockAuthenticationService(isSetUp: true, isBiometricEnabled: true)
        let viewModel = AuthenticationViewModel(
            authService: authService,
            biometricService: biometricService
        )
        viewModel.showBiometricPrompt = false // Show password mode when biometric is available

        let view = UnlockView(viewModel: viewModel)

        // Access body to execute view code for coverage
        _ = view.body
    }
}
