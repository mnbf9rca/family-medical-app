// swiftlint:disable password_in_code
import Testing
@testable import FamilyMedicalApp

/// Tests for AuthenticationViewModel setup functionality
@MainActor
struct AuthenticationViewModelSetupTests {
    // MARK: - Test Constants

    private let validUsername = "testuser"
    private let shortUsername = "ab"
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

        viewModel.username = validUsername
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
    func setupWithShortUsername() async {
        let authService = MockAuthenticationService(isSetUp: false)
        let viewModel = AuthenticationViewModel(authService: authService)

        viewModel.username = shortUsername
        viewModel.password = validTestCredential
        viewModel.confirmPassword = validTestCredential

        await viewModel.setUp()

        #expect(viewModel.isSetUp == false)
        #expect(viewModel.errorMessage == "Username must be at least 3 characters")
    }

    @Test
    func setupWithPasswordMismatch() async {
        let authService = MockAuthenticationService(isSetUp: false)
        let viewModel = AuthenticationViewModel(authService: authService)

        viewModel.username = validUsername
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

        viewModel.username = validUsername
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

        viewModel.username = validUsername
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

        viewModel.username = validUsername
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

        viewModel.username = validUsername
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

        viewModel.username = validUsername
        viewModel.password = shortTestCredential
        viewModel.confirmPassword = shortTestCredential

        await viewModel.setUp()

        #expect(!viewModel.displayedValidationErrors.isEmpty)
    }

    // MARK: - Username Validation Tests

    @Test
    func usernameValidationWithValidUsername() {
        let authService = MockAuthenticationService(isSetUp: false)
        let viewModel = AuthenticationViewModel(authService: authService)

        viewModel.username = validUsername
        #expect(viewModel.isUsernameValid == true)
        #expect(viewModel.usernameValidationError == nil)
    }

    @Test
    func usernameValidationWithShortUsername() {
        let authService = MockAuthenticationService(isSetUp: false)
        let viewModel = AuthenticationViewModel(authService: authService)

        viewModel.username = shortUsername
        #expect(viewModel.isUsernameValid == false)
        #expect(viewModel.usernameValidationError == "Username must be at least 3 characters")
    }

    @Test
    func usernameValidationWithEmptyUsername() {
        let authService = MockAuthenticationService(isSetUp: false)
        let viewModel = AuthenticationViewModel(authService: authService)

        viewModel.username = ""
        #expect(viewModel.isUsernameValid == false)
        #expect(viewModel.usernameValidationError == nil) // No error for empty (shown on submit)
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

    // MARK: - Stored Username Tests

    @Test
    func storedUsernameReturnsValueFromService() {
        let authService = MockAuthenticationService(isSetUp: true, storedUsername: "storeduser")
        let viewModel = AuthenticationViewModel(authService: authService)

        #expect(viewModel.storedUsername == "storeduser")
    }

    @Test
    func storedUsernameReturnsEmptyWhenNil() {
        let authService = MockAuthenticationService(isSetUp: true, storedUsername: nil)
        let viewModel = AuthenticationViewModel(authService: authService)

        #expect(viewModel.storedUsername.isEmpty)
    }
}

// swiftlint:enable password_in_code
