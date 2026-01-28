import Testing
@testable import FamilyMedicalApp

/// Tests for AuthenticationViewModel OPAQUE-based authentication flow
@MainActor
struct AuthenticationViewModelFlowTests {
    // MARK: - Test Constants

    private let validUsername = "testuser"
    private let validPassphrase = "valid-test-passphrase-123"

    // MARK: - Initial Flow State Tests

    @Test
    func initialFlowStateIsUsernameEntryWhenNotSetUp() {
        let authService = MockAuthenticationService(isSetUp: false)
        let viewModel = AuthenticationViewModel(authService: authService)

        #expect(viewModel.flowState == .usernameEntry)
    }

    @Test
    func initialFlowStateIsUnlockWhenSetUp() {
        let authService = MockAuthenticationService(isSetUp: true)
        let viewModel = AuthenticationViewModel(authService: authService)

        #expect(viewModel.flowState == .unlock)
    }

    // MARK: - Submit Username Tests

    @Test
    func submitUsernameTransitionsToPassphraseCreationForNewUser() async {
        let authService = MockAuthenticationService(isSetUp: false)
        let viewModel = AuthenticationViewModel(authService: authService)
        viewModel.username = validUsername

        await viewModel.submitUsername()

        #expect(viewModel.flowState == .passphraseCreation(username: validUsername))
    }

    @Test
    func submitUsernameShowsErrorForInvalidUsername() async {
        let authService = MockAuthenticationService(isSetUp: false)
        let viewModel = AuthenticationViewModel(authService: authService)
        viewModel.username = "ab" // Too short

        await viewModel.submitUsername()

        #expect(viewModel.flowState == .usernameEntry)
        #expect(viewModel.errorMessage != nil)
    }

    @Test
    func proceedAsReturningUserTransitionsToPassphraseEntry() {
        let authService = MockAuthenticationService(isSetUp: false)
        let viewModel = AuthenticationViewModel(authService: authService)
        viewModel.username = validUsername

        viewModel.proceedAsReturningUser()

        #expect(viewModel.flowState == .passphraseEntry(username: validUsername, isReturningUser: true))
    }

    // MARK: - Passphrase Creation Tests

    @Test
    func submitPassphraseCreationTransitionsToConfirmation() async {
        let authService = MockAuthenticationService(isSetUp: false)
        let viewModel = AuthenticationViewModel(authService: authService)
        viewModel.flowState = .passphraseCreation(username: validUsername)
        viewModel.passphrase = validPassphrase

        await viewModel.submitPassphraseCreation()

        #expect(viewModel.flowState == .passphraseConfirmation(username: validUsername, passphrase: validPassphrase))
    }

    @Test
    func submitPassphraseCreationShowsErrorForWeakPassphrase() async {
        let authService = MockAuthenticationService(isSetUp: false)
        let viewModel = AuthenticationViewModel(authService: authService)
        viewModel.flowState = .passphraseCreation(username: validUsername)
        viewModel.passphrase = "short" // Too weak

        await viewModel.submitPassphraseCreation()

        #expect(viewModel.flowState == .passphraseCreation(username: validUsername))
        #expect(viewModel.errorMessage != nil)
    }

    // MARK: - Passphrase Confirmation Tests

    @Test
    func submitPassphraseConfirmationTransitionsToBiometricSetup() async {
        let authService = MockAuthenticationService(isSetUp: false)
        let viewModel = AuthenticationViewModel(authService: authService)
        viewModel.flowState = .passphraseConfirmation(username: validUsername, passphrase: validPassphrase)
        viewModel.confirmPassphrase = validPassphrase

        await viewModel.submitPassphraseConfirmation()

        #expect(viewModel.flowState == .biometricSetup(username: validUsername, passphrase: validPassphrase))
    }

    @Test
    func submitPassphraseConfirmationShowsErrorForMismatch() async {
        let authService = MockAuthenticationService(isSetUp: false)
        let viewModel = AuthenticationViewModel(authService: authService)
        viewModel.flowState = .passphraseConfirmation(username: validUsername, passphrase: validPassphrase)
        viewModel.confirmPassphrase = "different-passphrase"

        await viewModel.submitPassphraseConfirmation()

        #expect(viewModel.flowState == .passphraseConfirmation(username: validUsername, passphrase: validPassphrase))
        #expect(viewModel.errorMessage != nil)
    }

    // MARK: - Complete Setup Tests

    @Test
    func completeSetupWithBiometricEnabled() async {
        let authService = MockAuthenticationService(isSetUp: false)
        let biometricService = MockViewModelBiometricService(isAvailable: true)
        let viewModel = AuthenticationViewModel(
            authService: authService,
            biometricService: biometricService
        )
        viewModel.flowState = .biometricSetup(username: validUsername, passphrase: validPassphrase)

        await viewModel.completeSetup(enableBiometric: true)

        #expect(viewModel.flowState == .authenticated)
        #expect(viewModel.isSetUp == true)
        #expect(viewModel.isAuthenticated == true)
    }

    @Test
    func completeSetupWithoutBiometric() async {
        let authService = MockAuthenticationService(isSetUp: false)
        let viewModel = AuthenticationViewModel(authService: authService)
        viewModel.flowState = .biometricSetup(username: validUsername, passphrase: validPassphrase)

        await viewModel.completeSetup(enableBiometric: false)

        #expect(viewModel.flowState == .authenticated)
        #expect(viewModel.isSetUp == true)
        #expect(viewModel.isAuthenticated == true)
    }

    // MARK: - Existing Passphrase Entry Tests

    @Test
    func submitExistingPassphraseSuccessTransitionsToBiometricSetup() async {
        let authService = MockAuthenticationService(isSetUp: true, storedUsername: "testuser")
        let viewModel = AuthenticationViewModel(authService: authService)
        viewModel.flowState = .passphraseEntry(username: "testuser", isReturningUser: true)
        viewModel.passphrase = validPassphrase

        await viewModel.submitExistingPassphrase()

        #expect(viewModel.flowState == .biometricSetup(username: "testuser", passphrase: validPassphrase))
    }

    @Test
    func submitExistingPassphraseFailureShowsError() async {
        let authService = MockAuthenticationService(isSetUp: true, storedUsername: "testuser", shouldFailUnlock: true)
        let viewModel = AuthenticationViewModel(authService: authService)
        viewModel.flowState = .passphraseEntry(username: "testuser", isReturningUser: true)
        viewModel.passphrase = "wrongpassphrase"

        await viewModel.submitExistingPassphrase()

        // Should stay on same screen with error
        #expect(viewModel.flowState == .passphraseEntry(username: "testuser", isReturningUser: true))
        #expect(viewModel.errorMessage != nil)
    }

    // MARK: - Back Navigation Tests

    @Test
    func goBackFromPassphraseCreationReturnsToUsernameEntry() {
        let authService = MockAuthenticationService(isSetUp: false)
        let viewModel = AuthenticationViewModel(authService: authService)
        viewModel.flowState = .passphraseCreation(username: validUsername)

        viewModel.goBack()

        #expect(viewModel.flowState == .usernameEntry)
    }

    @Test
    func goBackFromPassphraseConfirmationReturnsToCreation() {
        let authService = MockAuthenticationService(isSetUp: false)
        let viewModel = AuthenticationViewModel(authService: authService)
        viewModel.flowState = .passphraseConfirmation(username: validUsername, passphrase: validPassphrase)

        viewModel.goBack()

        #expect(viewModel.flowState == .passphraseCreation(username: validUsername))
    }

    @Test
    func goBackFromPassphraseEntryReturnsToUsernameEntry() {
        let authService = MockAuthenticationService(isSetUp: false)
        let viewModel = AuthenticationViewModel(authService: authService)
        viewModel.flowState = .passphraseEntry(username: validUsername, isReturningUser: true)

        viewModel.goBack()

        #expect(viewModel.flowState == .usernameEntry)
    }

    @Test
    func goBackFromBiometricSetupReturnsToConfirmation() {
        let authService = MockAuthenticationService(isSetUp: false)
        let viewModel = AuthenticationViewModel(authService: authService)
        viewModel.flowState = .biometricSetup(username: validUsername, passphrase: validPassphrase)

        viewModel.goBack()

        #expect(viewModel.flowState == .passphraseConfirmation(username: validUsername, passphrase: validPassphrase))
    }

    // MARK: - Sensitive Field Clearing Tests

    @Test
    func goBackClearsPassphraseFromCreation() {
        let authService = MockAuthenticationService(isSetUp: false)
        let viewModel = AuthenticationViewModel(authService: authService)
        viewModel.flowState = .passphraseCreation(username: validUsername)
        viewModel.passphrase = validPassphrase

        viewModel.goBack()

        #expect(viewModel.passphrase.isEmpty)
    }

    @Test
    func goBackClearsConfirmPassphraseFromConfirmation() {
        let authService = MockAuthenticationService(isSetUp: false)
        let viewModel = AuthenticationViewModel(authService: authService)
        viewModel.flowState = .passphraseConfirmation(username: validUsername, passphrase: validPassphrase)
        viewModel.confirmPassphrase = validPassphrase

        viewModel.goBack()

        #expect(viewModel.confirmPassphrase.isEmpty)
    }

    @Test
    func goBackClearsErrorMessage() {
        let authService = MockAuthenticationService(isSetUp: false)
        let viewModel = AuthenticationViewModel(authService: authService)
        viewModel.flowState = .passphraseCreation(username: validUsername)
        viewModel.errorMessage = "Some error"

        viewModel.goBack()

        #expect(viewModel.errorMessage == nil)
    }
}
