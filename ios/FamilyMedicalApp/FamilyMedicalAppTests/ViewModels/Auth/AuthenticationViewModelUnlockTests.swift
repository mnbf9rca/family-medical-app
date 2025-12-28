import Testing
@testable import FamilyMedicalApp

/// Tests for AuthenticationViewModel unlock functionality
@MainActor
struct AuthenticationViewModelUnlockTests {
    // MARK: - Test Constants

    private let correctTestCredential = "correct-credential"
    private let wrongTestCredential = "wrong-credential"
    private let attemptTestCredential = "attempt-credential"

    // MARK: - Password Unlock Tests

    @Test
    func unlockWithCorrectPassword() async {
        let authService = MockAuthenticationService(isSetUp: true)
        let viewModel = AuthenticationViewModel(authService: authService)

        viewModel.unlockPassword = correctTestCredential

        await viewModel.unlockWithPassword()

        #expect(viewModel.isAuthenticated == true)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.unlockPassword.isEmpty)
    }

    @Test
    func unlockWithEmptyPassword() async {
        let authService = MockAuthenticationService(isSetUp: true)
        let viewModel = AuthenticationViewModel(authService: authService)

        viewModel.unlockPassword = ""

        await viewModel.unlockWithPassword()

        #expect(viewModel.isAuthenticated == false)
        #expect(viewModel.errorMessage == "Please enter your password")
    }

    @Test
    func unlockWithWrongPassword() async {
        let authService = MockAuthenticationService(isSetUp: true, shouldFailUnlock: true)
        let viewModel = AuthenticationViewModel(authService: authService)

        viewModel.unlockPassword = wrongTestCredential

        await viewModel.unlockWithPassword()

        #expect(viewModel.isAuthenticated == false)
        #expect(viewModel.errorMessage != nil)
    }

    @Test
    func unlockClearsPasswordOnSuccess() async {
        let authService = MockAuthenticationService(isSetUp: true)
        let viewModel = AuthenticationViewModel(authService: authService)

        viewModel.unlockPassword = correctTestCredential

        await viewModel.unlockWithPassword()

        #expect(viewModel.unlockPassword.isEmpty)
    }

    @Test
    func unlockClearsPasswordOnWrongPassword() async {
        let authService = MockAuthenticationService(isSetUp: true, shouldFailUnlock: true)
        let viewModel = AuthenticationViewModel(authService: authService)

        viewModel.unlockPassword = wrongTestCredential

        await viewModel.unlockWithPassword()

        #expect(viewModel.unlockPassword.isEmpty)
    }

    @Test
    func unlockKeepsPasswordOnLockout() async {
        let authService = MockAuthenticationService(
            isSetUp: true,
            isLockedOut: true,
            shouldFailUnlock: true
        )
        let viewModel = AuthenticationViewModel(authService: authService)

        viewModel.unlockPassword = attemptTestCredential

        await viewModel.unlockWithPassword()

        #expect(viewModel.unlockPassword == attemptTestCredential)
    }

    // MARK: - Biometric Unlock Tests

    @Test
    func unlockWithBiometricSuccess() async {
        let biometricService = MockViewModelBiometricService(isAvailable: true)
        let authService = MockAuthenticationService(
            isSetUp: true,
            isBiometricEnabled: true,
            biometricService: biometricService
        )
        let viewModel = AuthenticationViewModel(
            authService: authService,
            biometricService: biometricService
        )

        await viewModel.unlockWithBiometric()

        #expect(viewModel.isAuthenticated == true)
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    func unlockWithBiometricFailure() async {
        let biometricService = MockViewModelBiometricService(
            isAvailable: true,
            shouldFailAuthentication: true
        )
        let authService = MockAuthenticationService(
            isSetUp: true,
            isBiometricEnabled: true,
            biometricService: biometricService
        )
        let viewModel = AuthenticationViewModel(
            authService: authService,
            biometricService: biometricService
        )

        await viewModel.unlockWithBiometric()

        #expect(viewModel.isAuthenticated == false)
        #expect(viewModel.errorMessage != nil)
    }

    @Test
    func unlockWithBiometricCancelled() async {
        let biometricService = MockViewModelBiometricService(
            isAvailable: true,
            shouldCancelAuthentication: true
        )
        let authService = MockAuthenticationService(
            isSetUp: true,
            isBiometricEnabled: true,
            biometricService: biometricService
        )
        let viewModel = AuthenticationViewModel(
            authService: authService,
            biometricService: biometricService
        )

        await viewModel.unlockWithBiometric()

        #expect(viewModel.isAuthenticated == false)
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    func attemptBiometricOnAppearWhenPromptShown() async {
        let biometricService = MockViewModelBiometricService(isAvailable: true)
        let authService = MockAuthenticationService(
            isSetUp: true,
            isBiometricEnabled: true,
            biometricService: biometricService
        )
        let viewModel = AuthenticationViewModel(
            authService: authService,
            biometricService: biometricService
        )

        await viewModel.attemptBiometricOnAppear()

        #expect(viewModel.isAuthenticated == true)
    }

    @Test
    func attemptBiometricOnAppearWhenAlreadyAuthenticated() async {
        let authService = MockAuthenticationService(isSetUp: true, isBiometricEnabled: true)
        let biometricService = MockViewModelBiometricService(isAvailable: true)
        let viewModel = AuthenticationViewModel(
            authService: authService,
            biometricService: biometricService
        )

        viewModel.isAuthenticated = true

        await viewModel.attemptBiometricOnAppear()

        #expect(viewModel.isAuthenticated == true)
    }

    @Test
    func attemptBiometricOnAppearWhenPromptNotShown() async {
        let authService = MockAuthenticationService(isSetUp: true, isBiometricEnabled: false)
        let biometricService = MockViewModelBiometricService(isAvailable: true)
        let viewModel = AuthenticationViewModel(
            authService: authService,
            biometricService: biometricService
        )

        await viewModel.attemptBiometricOnAppear()

        #expect(viewModel.isAuthenticated == false)
    }

    // MARK: - Lockout Tests

    @Test
    func failedAttemptsReflectsServiceState() {
        let authService = MockAuthenticationService(isSetUp: true, failedAttemptCount: 3)
        let viewModel = AuthenticationViewModel(authService: authService)

        #expect(viewModel.failedAttempts == 3)
    }

    @Test
    func isLockedOutReflectsServiceState() {
        let authService = MockAuthenticationService(isSetUp: true, isLockedOut: true)
        let viewModel = AuthenticationViewModel(authService: authService)

        #expect(viewModel.isLockedOut == true)
    }

    @Test
    func lockoutTimeRemainingReflectsServiceState() {
        let authService = MockAuthenticationService(
            isSetUp: true,
            lockoutRemainingSeconds: 30
        )
        let viewModel = AuthenticationViewModel(authService: authService)

        #expect(viewModel.lockoutTimeRemaining == 30)
    }
}
