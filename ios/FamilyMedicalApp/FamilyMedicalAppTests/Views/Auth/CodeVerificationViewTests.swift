import Testing
import ViewInspector
@testable import FamilyMedicalApp

@MainActor
struct CodeVerificationViewTests {
    private let testEmail = "test@example.com"

    // MARK: - View Structure Tests

    @Test
    func viewDisplaysEmail() throws {
        let viewModel = AuthenticationViewModel()
        let view = CodeVerificationView(viewModel: viewModel, email: testEmail)

        let sut = try view.inspect()
        let emailDisplay = try sut.find(viewWithAccessibilityIdentifier: "emailDisplay")

        #expect(emailDisplay != nil)
    }

    @Test
    func viewContainsCodeField() throws {
        let viewModel = AuthenticationViewModel()
        let view = CodeVerificationView(viewModel: viewModel, email: testEmail)

        let sut = try view.inspect()
        let codeField = try sut.find(viewWithAccessibilityIdentifier: "codeField")

        #expect(codeField != nil)
    }

    @Test
    func viewContainsVerifyButton() throws {
        let viewModel = AuthenticationViewModel()
        let view = CodeVerificationView(viewModel: viewModel, email: testEmail)

        let sut = try view.inspect()
        let button = try sut.find(viewWithAccessibilityIdentifier: "verifyButton")

        #expect(button != nil)
    }

    @Test
    func viewContainsResendButton() throws {
        let viewModel = AuthenticationViewModel()
        let view = CodeVerificationView(viewModel: viewModel, email: testEmail)

        let sut = try view.inspect()
        let button = try sut.find(viewWithAccessibilityIdentifier: "resendButton")

        #expect(button != nil)
    }

    @Test
    func viewContainsBackButton() throws {
        let viewModel = AuthenticationViewModel()
        let view = CodeVerificationView(viewModel: viewModel, email: testEmail)

        let sut = try view.inspect()
        let button = try sut.find(viewWithAccessibilityIdentifier: "backButton")

        #expect(button != nil)
    }

    // MARK: - Button State Tests

    @Test
    func verifyButtonDisabledWhenCodeIncomplete() throws {
        let viewModel = AuthenticationViewModel()
        viewModel.verificationCode = "123"
        let view = CodeVerificationView(viewModel: viewModel, email: testEmail)

        let sut = try view.inspect()
        let button = try sut.find(viewWithAccessibilityIdentifier: "verifyButton").button()

        #expect(try button.isDisabled() == true)
    }

    @Test
    func verifyButtonEnabledWhenCodeComplete() throws {
        let viewModel = AuthenticationViewModel()
        viewModel.verificationCode = "123456"
        let view = CodeVerificationView(viewModel: viewModel, email: testEmail)

        let sut = try view.inspect()
        let button = try sut.find(viewWithAccessibilityIdentifier: "verifyButton").button()

        #expect(try button.isDisabled() == false)
    }

    // MARK: - Error Display Tests

    @Test
    func errorLabelShowsWhenErrorPresent() throws {
        let viewModel = AuthenticationViewModel()
        viewModel.errorMessage = "Invalid code"
        let view = CodeVerificationView(viewModel: viewModel, email: testEmail)

        let sut = try view.inspect()
        let errorLabel = try sut.find(viewWithAccessibilityIdentifier: "errorLabel")

        #expect(errorLabel != nil)
    }

    @Test
    func errorLabelHiddenWhenNoError() throws {
        let viewModel = AuthenticationViewModel()
        viewModel.errorMessage = nil
        let view = CodeVerificationView(viewModel: viewModel, email: testEmail)

        let sut = try view.inspect()

        #expect(throws: InspectionError.self) {
            try sut.find(viewWithAccessibilityIdentifier: "errorLabel")
        }
    }
}
