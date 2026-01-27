import Testing
@testable import FamilyMedicalApp

/// Tests for AuthenticationViewModel email verification flow
@MainActor
struct AuthenticationViewModelFlowTests {
    // MARK: - Test Constants

    private let validEmail = "test@example.com"
    private let validCode = "123456"
    private let validPassphrase = "valid-test-passphrase-123"

    // MARK: - Initial Flow State Tests

    @Test
    func initialFlowStateIsEmailEntryWhenNotSetUp() {
        let authService = MockAuthenticationService(isSetUp: false)
        let viewModel = AuthenticationViewModel(authService: authService)

        #expect(viewModel.flowState == .emailEntry)
    }

    @Test
    func initialFlowStateIsUnlockWhenSetUp() {
        let authService = MockAuthenticationService(isSetUp: true)
        let viewModel = AuthenticationViewModel(authService: authService)

        #expect(viewModel.flowState == .unlock)
    }

    // MARK: - Submit Email Tests

    @Test
    func submitEmailTransitionsToCodeVerification() async {
        let mockEmailService = MockEmailVerificationService()
        let authService = MockAuthenticationService(isSetUp: false)
        let viewModel = AuthenticationViewModel(
            authService: authService,
            emailVerificationService: mockEmailService
        )
        viewModel.email = validEmail

        await viewModel.submitEmail()

        #expect(viewModel.flowState == .codeVerification(email: validEmail))
        #expect(mockEmailService.sendCodeCallCount == 1)
        #expect(mockEmailService.sendCodeEmail == validEmail)
    }

    @Test
    func submitEmailShowsErrorForInvalidEmail() async {
        let mockEmailService = MockEmailVerificationService()
        let authService = MockAuthenticationService(isSetUp: false)
        let viewModel = AuthenticationViewModel(
            authService: authService,
            emailVerificationService: mockEmailService
        )
        viewModel.email = "not-an-email"

        await viewModel.submitEmail()

        #expect(viewModel.flowState == .emailEntry)
        #expect(viewModel.errorMessage != nil)
        #expect(mockEmailService.sendCodeCallCount == 0)
    }

    @Test
    func submitEmailHandlesServiceError() async {
        let mockEmailService = MockEmailVerificationService()
        mockEmailService.sendCodeShouldThrow = .emailVerificationFailed
        let authService = MockAuthenticationService(isSetUp: false)
        let viewModel = AuthenticationViewModel(
            authService: authService,
            emailVerificationService: mockEmailService
        )
        viewModel.email = validEmail

        await viewModel.submitEmail()

        #expect(viewModel.flowState == .emailEntry)
        #expect(viewModel.errorMessage != nil)
    }

    @Test
    func submitEmailHandlesRateLimiting() async {
        let mockEmailService = MockEmailVerificationService()
        mockEmailService.sendCodeShouldThrow = .tooManyVerificationAttempts
        let authService = MockAuthenticationService(isSetUp: false)
        let viewModel = AuthenticationViewModel(
            authService: authService,
            emailVerificationService: mockEmailService
        )
        viewModel.email = validEmail

        await viewModel.submitEmail()

        #expect(viewModel.flowState == .emailEntry)
        #expect(viewModel.errorMessage?.contains("many") == true || viewModel.errorMessage?.contains("wait") == true)
    }

    // MARK: - Submit Verification Code Tests

    @Test
    func submitCodeTransitionsToPassphraseCreationForNewUser() async {
        let mockEmailService = MockEmailVerificationService()
        mockEmailService.verifyCodeResult = EmailVerificationResult(isValid: true, isReturningUser: false)
        let authService = MockAuthenticationService(isSetUp: false)
        let viewModel = AuthenticationViewModel(
            authService: authService,
            emailVerificationService: mockEmailService
        )
        viewModel.flowState = .codeVerification(email: validEmail)
        viewModel.verificationCode = validCode

        await viewModel.submitVerificationCode()

        #expect(viewModel.flowState == .passphraseCreation(email: validEmail))
        #expect(mockEmailService.verifyCodeCallCount == 1)
    }

    @Test
    func submitCodeTransitionsToPassphraseEntryForReturningUser() async {
        let mockEmailService = MockEmailVerificationService()
        mockEmailService.verifyCodeResult = EmailVerificationResult(isValid: true, isReturningUser: true)
        let authService = MockAuthenticationService(isSetUp: false)
        let viewModel = AuthenticationViewModel(
            authService: authService,
            emailVerificationService: mockEmailService
        )
        viewModel.flowState = .codeVerification(email: validEmail)
        viewModel.verificationCode = validCode

        await viewModel.submitVerificationCode()

        #expect(viewModel.flowState == .passphraseEntry(email: validEmail, isReturningUser: true))
    }

    @Test
    func submitCodeShowsErrorForInvalidCode() async {
        let mockEmailService = MockEmailVerificationService()
        mockEmailService.verifyCodeShouldThrow = .invalidVerificationCode
        let authService = MockAuthenticationService(isSetUp: false)
        let viewModel = AuthenticationViewModel(
            authService: authService,
            emailVerificationService: mockEmailService
        )
        viewModel.flowState = .codeVerification(email: validEmail)
        viewModel.verificationCode = "000000"

        await viewModel.submitVerificationCode()

        #expect(viewModel.flowState == .codeVerification(email: validEmail))
        #expect(viewModel.errorMessage != nil)
    }

    @Test
    func submitCodeShowsErrorForShortCode() async {
        let mockEmailService = MockEmailVerificationService()
        let authService = MockAuthenticationService(isSetUp: false)
        let viewModel = AuthenticationViewModel(
            authService: authService,
            emailVerificationService: mockEmailService
        )
        viewModel.flowState = .codeVerification(email: validEmail)
        viewModel.verificationCode = "123" // Too short

        await viewModel.submitVerificationCode()

        #expect(viewModel.errorMessage != nil)
        #expect(mockEmailService.verifyCodeCallCount == 0)
    }

    // MARK: - Passphrase Creation Tests

    @Test
    func submitPassphraseCreationTransitionsToConfirmation() async {
        let authService = MockAuthenticationService(isSetUp: false)
        let viewModel = AuthenticationViewModel(authService: authService)
        viewModel.flowState = .passphraseCreation(email: validEmail)
        viewModel.passphrase = validPassphrase

        await viewModel.submitPassphraseCreation()

        #expect(viewModel.flowState == .passphraseConfirmation(email: validEmail, passphrase: validPassphrase))
    }

    @Test
    func submitPassphraseCreationShowsErrorForWeakPassphrase() async {
        let authService = MockAuthenticationService(isSetUp: false)
        let viewModel = AuthenticationViewModel(authService: authService)
        viewModel.flowState = .passphraseCreation(email: validEmail)
        viewModel.passphrase = "short" // Too weak

        await viewModel.submitPassphraseCreation()

        #expect(viewModel.flowState == .passphraseCreation(email: validEmail))
        #expect(viewModel.errorMessage != nil)
    }

    // MARK: - Passphrase Confirmation Tests

    @Test
    func submitPassphraseConfirmationTransitionsToBiometricSetup() async {
        let authService = MockAuthenticationService(isSetUp: false)
        let viewModel = AuthenticationViewModel(authService: authService)
        viewModel.flowState = .passphraseConfirmation(email: validEmail, passphrase: validPassphrase)
        viewModel.confirmPassphrase = validPassphrase

        await viewModel.submitPassphraseConfirmation()

        #expect(viewModel.flowState == .biometricSetup(email: validEmail, passphrase: validPassphrase))
    }

    @Test
    func submitPassphraseConfirmationShowsErrorForMismatch() async {
        let authService = MockAuthenticationService(isSetUp: false)
        let viewModel = AuthenticationViewModel(authService: authService)
        viewModel.flowState = .passphraseConfirmation(email: validEmail, passphrase: validPassphrase)
        viewModel.confirmPassphrase = "different-passphrase"

        await viewModel.submitPassphraseConfirmation()

        #expect(viewModel.flowState == .passphraseConfirmation(email: validEmail, passphrase: validPassphrase))
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
        viewModel.flowState = .biometricSetup(email: validEmail, passphrase: validPassphrase)

        await viewModel.completeSetup(enableBiometric: true)

        #expect(viewModel.flowState == .authenticated)
        #expect(viewModel.isSetUp == true)
        #expect(viewModel.isAuthenticated == true)
    }

    @Test
    func completeSetupWithoutBiometric() async {
        let authService = MockAuthenticationService(isSetUp: false)
        let viewModel = AuthenticationViewModel(authService: authService)
        viewModel.flowState = .biometricSetup(email: validEmail, passphrase: validPassphrase)

        await viewModel.completeSetup(enableBiometric: false)

        #expect(viewModel.flowState == .authenticated)
        #expect(viewModel.isSetUp == true)
        #expect(viewModel.isAuthenticated == true)
    }

    // MARK: - Resend Code Tests

    @Test
    func resendCodeCallsEmailService() async {
        let mockEmailService = MockEmailVerificationService()
        let authService = MockAuthenticationService(isSetUp: false)
        let viewModel = AuthenticationViewModel(
            authService: authService,
            emailVerificationService: mockEmailService
        )
        viewModel.flowState = .codeVerification(email: validEmail)

        await viewModel.resendVerificationCode()

        #expect(mockEmailService.sendCodeCallCount == 1)
        #expect(mockEmailService.sendCodeEmail == validEmail)
    }

    // MARK: - Back Navigation Tests

    @Test
    func goBackFromCodeVerificationReturnsToEmailEntry() {
        let authService = MockAuthenticationService(isSetUp: false)
        let viewModel = AuthenticationViewModel(authService: authService)
        viewModel.flowState = .codeVerification(email: validEmail)

        viewModel.goBack()

        #expect(viewModel.flowState == .emailEntry)
    }

    @Test
    func goBackFromPassphraseCreationReturnsToCodeVerification() {
        let authService = MockAuthenticationService(isSetUp: false)
        let viewModel = AuthenticationViewModel(authService: authService)
        viewModel.flowState = .passphraseCreation(email: validEmail)

        viewModel.goBack()

        #expect(viewModel.flowState == .codeVerification(email: validEmail))
    }
}
