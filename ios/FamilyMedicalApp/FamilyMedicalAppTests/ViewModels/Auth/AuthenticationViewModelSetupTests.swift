// swiftlint:disable password_in_code
import Testing
@testable import FamilyMedicalApp

/// Tests for AuthenticationViewModel setup functionality
@MainActor
struct AuthenticationViewModelSetupTests {
    // MARK: - Test Constants

    private let validEmail = "test@example.com"
    private let invalidEmail = "notanemail"
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

        viewModel.email = validEmail
        viewModel.password = validTestCredential
        viewModel.confirmPassword = validTestCredential

        await viewModel.setUp()

        #expect(viewModel.isSetUp == true)
        #expect(viewModel.isAuthenticated == true)
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    func setupWithEmptyEmail() async {
        let authService = MockAuthenticationService(isSetUp: false)
        let viewModel = AuthenticationViewModel(authService: authService)

        viewModel.email = ""
        viewModel.password = validTestCredential
        viewModel.confirmPassword = validTestCredential

        await viewModel.setUp()

        #expect(viewModel.isSetUp == false)
        #expect(viewModel.errorMessage == "Please enter an email address")
    }

    @Test
    func setupWithWhitespaceEmail() async {
        let authService = MockAuthenticationService(isSetUp: false)
        let viewModel = AuthenticationViewModel(authService: authService)

        viewModel.email = "   "
        viewModel.password = validTestCredential
        viewModel.confirmPassword = validTestCredential

        await viewModel.setUp()

        #expect(viewModel.isSetUp == false)
        #expect(viewModel.errorMessage == "Please enter an email address")
    }

    @Test
    func setupWithInvalidEmail() async {
        let authService = MockAuthenticationService(isSetUp: false)
        let viewModel = AuthenticationViewModel(authService: authService)

        viewModel.email = invalidEmail
        viewModel.password = validTestCredential
        viewModel.confirmPassword = validTestCredential

        await viewModel.setUp()

        #expect(viewModel.isSetUp == false)
        #expect(viewModel.errorMessage == "Please enter a valid email address")
    }

    @Test
    func setupWithPasswordMismatch() async {
        let authService = MockAuthenticationService(isSetUp: false)
        let viewModel = AuthenticationViewModel(authService: authService)

        viewModel.email = validEmail
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

        viewModel.email = validEmail
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

        viewModel.email = validEmail
        viewModel.password = validTestCredential
        viewModel.confirmPassword = validTestCredential

        await viewModel.setUp()

        #expect(viewModel.email.isEmpty)
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

        viewModel.email = validEmail
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

        viewModel.email = validEmail
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

        viewModel.email = validEmail
        viewModel.password = shortTestCredential
        viewModel.confirmPassword = shortTestCredential

        await viewModel.setUp()

        #expect(!viewModel.displayedValidationErrors.isEmpty)
    }

    // MARK: - Email Validation Tests

    @Test
    func emailValidationWithValidEmail() {
        let authService = MockAuthenticationService(isSetUp: false)
        let viewModel = AuthenticationViewModel(authService: authService)

        viewModel.email = validEmail
        #expect(viewModel.isEmailValid == true)
        #expect(viewModel.emailValidationError == nil)
    }

    @Test
    func emailValidationWithInvalidEmail() {
        let authService = MockAuthenticationService(isSetUp: false)
        let viewModel = AuthenticationViewModel(authService: authService)

        viewModel.email = invalidEmail
        #expect(viewModel.isEmailValid == false)
        #expect(viewModel.emailValidationError == "Please enter a valid email address")
    }

    @Test
    func emailValidationWithEmptyEmail() {
        let authService = MockAuthenticationService(isSetUp: false)
        let viewModel = AuthenticationViewModel(authService: authService)

        viewModel.email = ""
        #expect(viewModel.isEmailValid == false)
        #expect(viewModel.emailValidationError == nil) // No error for empty (shown on submit)
    }

    @Test
    func emailValidationWithMissingAt() {
        let authService = MockAuthenticationService(isSetUp: false)
        let viewModel = AuthenticationViewModel(authService: authService)

        viewModel.email = "test.example.com"
        #expect(viewModel.isEmailValid == false)
    }

    @Test
    func emailValidationWithMissingDot() {
        let authService = MockAuthenticationService(isSetUp: false)
        let viewModel = AuthenticationViewModel(authService: authService)

        viewModel.email = "test@examplecom"
        #expect(viewModel.isEmailValid == false)
    }

    // MARK: - Password Mismatch Tests

    @Test
    func shouldShowPasswordMismatchWhenConfirmFieldLostFocus() {
        let authService = MockAuthenticationService(isSetUp: false)
        let viewModel = AuthenticationViewModel(authService: authService)

        viewModel.password = "password123"
        viewModel.confirmPassword = "different123"
        viewModel.hasConfirmFieldLostFocus = true

        #expect(viewModel.shouldShowPasswordMismatch == true)
    }

    @Test
    func shouldNotShowPasswordMismatchBeforeFocusLost() {
        let authService = MockAuthenticationService(isSetUp: false)
        let viewModel = AuthenticationViewModel(authService: authService)

        viewModel.password = "password123"
        viewModel.confirmPassword = ""
        viewModel.hasConfirmFieldLostFocus = false

        #expect(viewModel.shouldShowPasswordMismatch == false)
    }

    @Test
    func shouldShowPasswordMismatchWhenConfirmHasContent() {
        let authService = MockAuthenticationService(isSetUp: false)
        let viewModel = AuthenticationViewModel(authService: authService)

        viewModel.password = "password123"
        viewModel.confirmPassword = "different"
        viewModel.hasConfirmFieldLostFocus = false

        #expect(viewModel.shouldShowPasswordMismatch == true)
    }

    @Test
    func shouldNotShowPasswordMismatchWhenPasswordsMatch() {
        let authService = MockAuthenticationService(isSetUp: false)
        let viewModel = AuthenticationViewModel(authService: authService)

        viewModel.password = "password123"
        viewModel.confirmPassword = "password123"
        viewModel.hasConfirmFieldLostFocus = true

        #expect(viewModel.shouldShowPasswordMismatch == false)
    }

    // MARK: - Stored Email Tests

    @Test
    func storedEmailReturnsValueFromService() {
        let authService = MockAuthenticationService(isSetUp: true, storedEmail: "stored@example.com")
        let viewModel = AuthenticationViewModel(authService: authService)

        #expect(viewModel.storedEmail == "stored@example.com")
    }

    @Test
    func storedEmailReturnsEmptyWhenNil() {
        let authService = MockAuthenticationService(isSetUp: true, storedEmail: nil)
        let viewModel = AuthenticationViewModel(authService: authService)

        #expect(viewModel.storedEmail.isEmpty)
    }
}

// swiftlint:enable password_in_code
