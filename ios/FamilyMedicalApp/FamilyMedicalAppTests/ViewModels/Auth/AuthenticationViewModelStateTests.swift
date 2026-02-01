import Testing
@testable import FamilyMedicalApp

/// Tests for AuthenticationViewModel state management and lock/logout
@MainActor
struct AuthenticationViewModelStateTests {
    // MARK: - Test Constants

    private let longTestCredential = "unique-very-strong-credential-with-many-characters-2024"
    private let mediumTestCredential = "unique-good-credential-123"
    private let shortTestCredential = "short"
    private let genericTestCredential = "credential"

    // MARK: - Biometric State Tests

    @Test
    func biometryTypeReflectsServiceState() {
        let biometricService = MockViewModelBiometricService(
            isAvailable: true,
            biometryType: .faceID
        )
        let viewModel = AuthenticationViewModel(biometricService: biometricService)

        #expect(viewModel.biometryType == .faceID)
    }

    @Test
    func isBiometricAvailableReflectsServiceState() {
        let biometricService = MockViewModelBiometricService(isAvailable: true)
        let viewModel = AuthenticationViewModel(biometricService: biometricService)

        #expect(viewModel.isBiometricAvailable == true)
    }

    @Test
    func isBiometricEnabledReflectsServiceState() {
        let authService = MockAuthenticationService(isSetUp: true, isBiometricEnabled: true)
        let viewModel = AuthenticationViewModel(authService: authService)

        #expect(viewModel.isBiometricEnabled == true)
    }

    @Test
    func showBiometricPromptWhenSetUpAndEnabled() {
        let authService = MockAuthenticationService(isSetUp: true, isBiometricEnabled: true)
        let viewModel = AuthenticationViewModel(authService: authService)

        #expect(viewModel.showBiometricPrompt == true)
    }

    @Test
    func noBiometricPromptWhenNotSetUp() {
        let authService = MockAuthenticationService(isSetUp: false, isBiometricEnabled: true)
        let viewModel = AuthenticationViewModel(authService: authService)

        #expect(viewModel.showBiometricPrompt == false)
    }

    @Test
    func noBiometricPromptWhenNotEnabled() {
        let authService = MockAuthenticationService(isSetUp: true, isBiometricEnabled: false)
        let viewModel = AuthenticationViewModel(authService: authService)

        #expect(viewModel.showBiometricPrompt == false)
    }

    // MARK: - Password Validation Tests

    @Test
    func passwordStrengthReflectsPassword() {
        let viewModel = AuthenticationViewModel()

        viewModel.password = longTestCredential
        #expect(viewModel.passwordStrength >= .good)

        viewModel.password = mediumTestCredential
        #expect(viewModel.passwordStrength >= .fair)

        viewModel.password = shortTestCredential
        #expect(viewModel.passwordStrength == .weak)
    }

    @Test
    func passwordValidationErrorsReflectPassword() {
        let viewModel = AuthenticationViewModel()

        viewModel.password = shortTestCredential
        #expect(!viewModel.passwordValidationErrors.isEmpty)

        viewModel.password = mediumTestCredential
        #expect(viewModel.passwordValidationErrors.isEmpty)
    }

    // MARK: - Lock Tests

    @Test
    func lockSetsAuthenticatedToFalse() {
        let authService = MockAuthenticationService(isSetUp: true)
        let viewModel = AuthenticationViewModel(authService: authService)

        viewModel.isAuthenticated = true

        viewModel.lock()

        #expect(viewModel.isAuthenticated == false)
    }

    @Test
    func lockClearsUnlockPassword() {
        let authService = MockAuthenticationService(isSetUp: true)
        let viewModel = AuthenticationViewModel(authService: authService)

        viewModel.unlockPassword = genericTestCredential

        viewModel.lock()

        #expect(viewModel.unlockPassword.isEmpty)
    }

    @Test
    func lockClearsErrorMessage() {
        let authService = MockAuthenticationService(isSetUp: true)
        let viewModel = AuthenticationViewModel(authService: authService)

        viewModel.errorMessage = "Some error"

        viewModel.lock()

        #expect(viewModel.errorMessage == nil)
    }

    @Test
    func lockShowsBiometricPromptIfEnabled() {
        let authService = MockAuthenticationService(isSetUp: true, isBiometricEnabled: true)
        let viewModel = AuthenticationViewModel(authService: authService)

        viewModel.showBiometricPrompt = false

        viewModel.lock()

        #expect(viewModel.showBiometricPrompt == true)
    }

    @Test
    func lockDoesNotShowBiometricPromptIfDisabled() {
        let authService = MockAuthenticationService(isSetUp: true, isBiometricEnabled: false)
        let viewModel = AuthenticationViewModel(authService: authService)

        viewModel.showBiometricPrompt = true

        viewModel.lock()

        #expect(viewModel.showBiometricPrompt == false)
    }

    // MARK: - Logout Tests

    @Test
    func logoutClearsAllState() async {
        let authService = MockAuthenticationService(isSetUp: true)
        let viewModel = AuthenticationViewModel(authService: authService)

        viewModel.isAuthenticated = true
        viewModel.password = genericTestCredential
        viewModel.confirmPassword = genericTestCredential
        viewModel.unlockPassword = genericTestCredential
        viewModel.showBiometricPrompt = true
        viewModel.errorMessage = "error"

        await viewModel.logout()

        #expect(viewModel.isSetUp == false)
        #expect(viewModel.isAuthenticated == false)
        #expect(viewModel.password.isEmpty)
        #expect(viewModel.confirmPassword.isEmpty)
        #expect(viewModel.unlockPassword.isEmpty)
        #expect(viewModel.showBiometricPrompt == false)
        #expect(viewModel.errorMessage == nil)
    }

    // MARK: - Biometric Toggle Tests

    @Test
    func toggleBiometricEnablesWhenDisabled() async {
        let authService = MockAuthenticationService(isSetUp: true, isBiometricEnabled: false)
        let biometricService = MockViewModelBiometricService(isAvailable: true)
        let viewModel = AuthenticationViewModel(
            authService: authService,
            biometricService: biometricService
        )

        await viewModel.toggleBiometric()

        #expect(viewModel.showBiometricPrompt == true)
    }

    @Test
    func toggleBiometricDisablesWhenEnabled() async {
        let authService = MockAuthenticationService(isSetUp: true, isBiometricEnabled: true)
        let biometricService = MockViewModelBiometricService(isAvailable: true)
        let viewModel = AuthenticationViewModel(
            authService: authService,
            biometricService: biometricService
        )

        await viewModel.toggleBiometric()

        #expect(viewModel.showBiometricPrompt == false)
    }

    @Test
    func toggleBiometricHandlesEnableFailure() async {
        let biometricService = MockViewModelBiometricService(
            isAvailable: true,
            shouldFailAuthentication: true
        )
        let authService = MockAuthenticationService(
            isSetUp: true,
            isBiometricEnabled: false,
            biometricService: biometricService
        )
        let viewModel = AuthenticationViewModel(
            authService: authService,
            biometricService: biometricService
        )

        await viewModel.toggleBiometric()

        #expect(viewModel.errorMessage != nil)
    }
}
