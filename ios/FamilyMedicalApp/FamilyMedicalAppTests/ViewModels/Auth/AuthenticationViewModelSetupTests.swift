import Testing
@testable import FamilyMedicalApp

/// Tests for AuthenticationViewModel setup functionality
@MainActor
struct AuthenticationViewModelSetupTests {
    // MARK: - Test Constants

    private let validTestCredential = "valid-test-credential-123"
    private let shortTestCredential = "short"
    private let differentTestCredential = "different-credential"

    // MARK: - Setup State Tests

    @Test
    func initialStateIsNotSetUp() {
        let authService = MockAuthenticationService(isSetUp: false)
        let viewModel = AuthenticationViewModel(authService: authService)

        #expect(viewModel.isSetUp == false)
        #expect(viewModel.isAuthenticated == false)
    }

    @Test
    func initialStateIsSetUp() {
        let authService = MockAuthenticationService(isSetUp: true)
        let viewModel = AuthenticationViewModel(authService: authService)

        #expect(viewModel.isSetUp == true)
        #expect(viewModel.isAuthenticated == false)
    }

    @Test
    func setupWithValidCredentials() async {
        let authService = MockAuthenticationService(isSetUp: false)
        let viewModel = AuthenticationViewModel(authService: authService)

        viewModel.username = "testuser"
        viewModel.password = validTestCredential
        viewModel.confirmPassword = validTestCredential

        await viewModel.setUp()

        #expect(viewModel.isSetUp == true)
        #expect(viewModel.isAuthenticated == true)
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    func setupWithEmptyUsername() async {
        let authService = MockAuthenticationService(isSetUp: false)
        let viewModel = AuthenticationViewModel(authService: authService)

        viewModel.username = ""
        viewModel.password = validTestCredential
        viewModel.confirmPassword = validTestCredential

        await viewModel.setUp()

        #expect(viewModel.isSetUp == false)
        #expect(viewModel.errorMessage == "Please enter a username")
    }

    @Test
    func setupWithWhitespaceUsername() async {
        let authService = MockAuthenticationService(isSetUp: false)
        let viewModel = AuthenticationViewModel(authService: authService)

        viewModel.username = "   "
        viewModel.password = validTestCredential
        viewModel.confirmPassword = validTestCredential

        await viewModel.setUp()

        #expect(viewModel.isSetUp == false)
        #expect(viewModel.errorMessage == "Please enter a username")
    }

    @Test
    func setupWithPasswordMismatch() async {
        let authService = MockAuthenticationService(isSetUp: false)
        let viewModel = AuthenticationViewModel(authService: authService)

        viewModel.username = "testuser"
        viewModel.password = validTestCredential
        viewModel.confirmPassword = differentTestCredential

        await viewModel.setUp()

        #expect(viewModel.isSetUp == false)
        #expect(viewModel.errorMessage != nil)
    }

    @Test
    func setupWithInvalidPassword() async {
        let authService = MockAuthenticationService(isSetUp: false)
        let viewModel = AuthenticationViewModel(authService: authService)

        viewModel.username = "testuser"
        viewModel.password = shortTestCredential
        viewModel.confirmPassword = shortTestCredential

        await viewModel.setUp()

        #expect(viewModel.isSetUp == false)
        #expect(viewModel.errorMessage != nil)
    }

    @Test
    func setupClearsFieldsOnSuccess() async {
        let authService = MockAuthenticationService(isSetUp: false)
        let viewModel = AuthenticationViewModel(authService: authService)

        viewModel.username = "testuser"
        viewModel.password = validTestCredential
        viewModel.confirmPassword = validTestCredential

        await viewModel.setUp()

        #expect(viewModel.username.isEmpty)
        #expect(viewModel.password.isEmpty)
        #expect(viewModel.confirmPassword.isEmpty)
    }

    @Test
    func setupWithBiometricEnabled() async {
        let authService = MockAuthenticationService(isSetUp: false)
        let biometricService = MockViewModelBiometricService(isAvailable: true)
        let viewModel = AuthenticationViewModel(
            authService: authService,
            biometricService: biometricService
        )

        viewModel.username = "testuser"
        viewModel.password = validTestCredential
        viewModel.confirmPassword = validTestCredential
        viewModel.enableBiometric = true

        await viewModel.setUp()

        #expect(viewModel.isSetUp == true)
        #expect(viewModel.isAuthenticated == true)
    }

    @Test
    func setupSetsHasAttemptedSetupFlag() async {
        let authService = MockAuthenticationService(isSetUp: false)
        let viewModel = AuthenticationViewModel(authService: authService)

        #expect(viewModel.hasAttemptedSetup == false)

        viewModel.username = "testuser"
        viewModel.password = validTestCredential
        viewModel.confirmPassword = validTestCredential

        await viewModel.setUp()

        #expect(viewModel.hasAttemptedSetup == false)
    }

    @Test
    func displayedValidationErrorsEmptyBeforeAttempt() {
        let authService = MockAuthenticationService(isSetUp: false)
        let viewModel = AuthenticationViewModel(authService: authService)

        viewModel.password = shortTestCredential

        #expect(viewModel.displayedValidationErrors.isEmpty)
    }

    @Test
    func displayedValidationErrorsShownAfterAttempt() async {
        let authService = MockAuthenticationService(isSetUp: false)
        let viewModel = AuthenticationViewModel(authService: authService)

        viewModel.username = "testuser"
        viewModel.password = shortTestCredential
        viewModel.confirmPassword = shortTestCredential

        await viewModel.setUp()

        #expect(!viewModel.displayedValidationErrors.isEmpty)
    }
}
