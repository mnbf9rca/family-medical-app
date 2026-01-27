import Testing
import ViewInspector
@testable import FamilyMedicalApp

@MainActor
struct PassphraseEntryViewTests {
    private let testEmail = "test@example.com"

    // MARK: - View Structure Tests

    @Test
    func viewContainsPassphraseField() throws {
        let viewModel = AuthenticationViewModel()
        let view = PassphraseEntryView(viewModel: viewModel, email: testEmail)

        let sut = try view.inspect()
        let field = try sut.find(viewWithAccessibilityIdentifier: "passphraseField")

        #expect(field != nil)
    }

    @Test
    func viewContainsContinueButton() throws {
        let viewModel = AuthenticationViewModel()
        let view = PassphraseEntryView(viewModel: viewModel, email: testEmail)

        let sut = try view.inspect()
        let button = try sut.find(viewWithAccessibilityIdentifier: "continueButton")

        #expect(button != nil)
    }

    @Test
    func viewContainsBackButton() throws {
        let viewModel = AuthenticationViewModel()
        let view = PassphraseEntryView(viewModel: viewModel, email: testEmail)

        let sut = try view.inspect()
        let button = try sut.find(viewWithAccessibilityIdentifier: "backButton")

        #expect(button != nil)
    }

    // MARK: - Button State Tests

    @Test
    func continueButtonDisabledWhenEmpty() throws {
        let viewModel = AuthenticationViewModel()
        viewModel.passphrase = ""
        let view = PassphraseEntryView(viewModel: viewModel, email: testEmail)

        let sut = try view.inspect()
        let button = try sut.find(viewWithAccessibilityIdentifier: "continueButton").button()

        #expect(try button.isDisabled() == true)
    }

    @Test
    func continueButtonEnabledWhenPassphraseEntered() throws {
        let viewModel = AuthenticationViewModel()
        viewModel.passphrase = "any-passphrase"
        let view = PassphraseEntryView(viewModel: viewModel, email: testEmail)

        let sut = try view.inspect()
        let button = try sut.find(viewWithAccessibilityIdentifier: "continueButton").button()

        #expect(try button.isDisabled() == false)
    }

    // MARK: - Error Display Tests

    @Test
    func errorLabelShownWhenErrorPresent() throws {
        let viewModel = AuthenticationViewModel()
        viewModel.errorMessage = "Invalid passphrase"
        let view = PassphraseEntryView(viewModel: viewModel, email: testEmail)

        let sut = try view.inspect()
        let errorLabel = try sut.find(viewWithAccessibilityIdentifier: "errorLabel")

        #expect(errorLabel != nil)
    }

    @Test
    func errorLabelHiddenWhenNoError() throws {
        let viewModel = AuthenticationViewModel()
        viewModel.errorMessage = nil
        let view = PassphraseEntryView(viewModel: viewModel, email: testEmail)

        let sut = try view.inspect()

        #expect(throws: InspectionError.self) {
            try sut.find(viewWithAccessibilityIdentifier: "errorLabel")
        }
    }
}
