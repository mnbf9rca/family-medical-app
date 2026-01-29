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

        #expect(viewModel.flowState == .biometricSetup(
            username: validUsername,
            passphrase: validPassphrase,
            isReturningUser: false
        ))
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
        viewModel.flowState = .biometricSetup(
            username: validUsername,
            passphrase: validPassphrase,
            isReturningUser: false
        )

        await viewModel.completeSetup(enableBiometric: true)

        #expect(viewModel.flowState == .authenticated)
        #expect(viewModel.isSetUp == true)
        #expect(viewModel.isAuthenticated == true)
    }

    @Test
    func completeSetupWithoutBiometric() async {
        let authService = MockAuthenticationService(isSetUp: false)
        let viewModel = AuthenticationViewModel(authService: authService)
        viewModel.flowState = .biometricSetup(
            username: validUsername,
            passphrase: validPassphrase,
            isReturningUser: false
        )

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

        #expect(viewModel.flowState == .biometricSetup(
            username: "testuser",
            passphrase: validPassphrase,
            isReturningUser: true
        ))
    }

    @Test
    func submitExistingPassphraseTransitionsToBiometricSetup() async {
        // Note: Per the new flow, submitExistingPassphrase no longer validates the password
        // immediately. It transitions to biometricSetup, and completeSetup performs the actual
        // OPAQUE login. Password validation errors are now handled in completeSetup.
        let authService = MockAuthenticationService(isSetUp: false)
        let viewModel = AuthenticationViewModel(authService: authService)
        viewModel.flowState = .passphraseEntry(username: "testuser", isReturningUser: true)
        viewModel.passphrase = "anypassphrase"

        await viewModel.submitExistingPassphrase()

        // Should transition to biometricSetup with isReturningUser: true
        #expect(viewModel.flowState == .biometricSetup(
            username: "testuser",
            passphrase: "anypassphrase",
            isReturningUser: true
        ))
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
        viewModel.flowState = .biometricSetup(
            username: validUsername,
            passphrase: validPassphrase,
            isReturningUser: false
        )

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

    // MARK: - Returning User on New Device Tests

    @Test
    func submitExistingPassphraseTransitionsToBiometricSetupWithReturningUser() async {
        let authService = MockAuthenticationService(isSetUp: false)
        let viewModel = AuthenticationViewModel(authService: authService)
        viewModel.flowState = .passphraseEntry(username: "existinguser", isReturningUser: true)
        viewModel.passphrase = "ValidPassphrase123!"

        await viewModel.submitExistingPassphrase()

        #expect(viewModel.flowState == .biometricSetup(
            username: "existinguser",
            passphrase: "ValidPassphrase123!",
            isReturningUser: true
        ))
    }

    @Test
    func completeSetupForReturningUserCallsLoginAndSetup() async {
        let authService = MockAuthenticationService(isSetUp: false)
        let viewModel = AuthenticationViewModel(authService: authService)
        viewModel.flowState = .biometricSetup(
            username: "existinguser",
            passphrase: "ValidPassphrase123!",
            isReturningUser: true
        )

        await viewModel.completeSetup(enableBiometric: false)

        #expect(viewModel.flowState == .authenticated)
        #expect(viewModel.isSetUp == true)
        #expect(viewModel.isAuthenticated == true)
    }

    @Test
    func completeSetupForReturningUserFailureShowsError() async {
        let authService = MockAuthenticationService(isSetUp: false, shouldFailLoginAndSetup: true)
        let viewModel = AuthenticationViewModel(authService: authService)
        viewModel.flowState = .biometricSetup(
            username: "existinguser",
            passphrase: "ValidPassphrase123!",
            isReturningUser: true
        )

        await viewModel.completeSetup(enableBiometric: false)

        #expect(viewModel.flowState == .biometricSetup(
            username: "existinguser",
            passphrase: "ValidPassphrase123!",
            isReturningUser: true
        ))
        #expect(viewModel.errorMessage != nil)
    }

    @Test
    func goBackFromBiometricSetupReturningUserReturnsToPassphraseEntry() {
        let authService = MockAuthenticationService(isSetUp: false)
        let viewModel = AuthenticationViewModel(authService: authService)
        viewModel.flowState = .biometricSetup(
            username: "existinguser",
            passphrase: "ValidPassphrase123!",
            isReturningUser: true
        )

        viewModel.goBack()

        #expect(viewModel.flowState == .passphraseEntry(username: "existinguser", isReturningUser: true))
    }
}
