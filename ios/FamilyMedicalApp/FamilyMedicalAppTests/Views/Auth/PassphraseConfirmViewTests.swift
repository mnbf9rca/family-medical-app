import Testing
import ViewInspector
@testable import FamilyMedicalApp

@MainActor
struct PassphraseConfirmViewTests {
    private let testEmail = "test@example.com"
    private let testPassphrase = "valid-test-passphrase-123"

    // MARK: - View Structure Tests

    @Test
    func viewContainsConfirmField() throws {
        let viewModel = AuthenticationViewModel()
        let view = PassphraseConfirmView(viewModel: viewModel, email: testEmail, passphrase: testPassphrase)

        let sut = try view.inspect()
        let field = try sut.find(viewWithAccessibilityIdentifier: "confirmPassphraseField")

        #expect(field != nil)
    }

    @Test
    func viewContainsContinueButton() throws {
        let viewModel = AuthenticationViewModel()
        let view = PassphraseConfirmView(viewModel: viewModel, email: testEmail, passphrase: testPassphrase)

        let sut = try view.inspect()
        let button = try sut.find(viewWithAccessibilityIdentifier: "continueButton")

        #expect(button != nil)
    }

    @Test
    func viewContainsBackButton() throws {
        let viewModel = AuthenticationViewModel()
        let view = PassphraseConfirmView(viewModel: viewModel, email: testEmail, passphrase: testPassphrase)

        let sut = try view.inspect()
        let button = try sut.find(viewWithAccessibilityIdentifier: "backButton")

        #expect(button != nil)
    }

    // MARK: - Button State Tests

    @Test
    func continueButtonDisabledWhenConfirmEmpty() throws {
        let viewModel = AuthenticationViewModel()
        viewModel.confirmPassphrase = ""
        let view = PassphraseConfirmView(viewModel: viewModel, email: testEmail, passphrase: testPassphrase)

        let sut = try view.inspect()
        let button = try sut.find(viewWithAccessibilityIdentifier: "continueButton").button()

        #expect(try button.isDisabled() == true)
    }

    @Test
    func continueButtonDisabledWhenMismatch() throws {
        let viewModel = AuthenticationViewModel()
        viewModel.confirmPassphrase = "wrong-passphrase"
        let view = PassphraseConfirmView(viewModel: viewModel, email: testEmail, passphrase: testPassphrase)

        let sut = try view.inspect()
        let button = try sut.find(viewWithAccessibilityIdentifier: "continueButton").button()

        #expect(try button.isDisabled() == true)
    }

    @Test
    func continueButtonEnabledWhenMatch() throws {
        let viewModel = AuthenticationViewModel()
        viewModel.confirmPassphrase = testPassphrase
        let view = PassphraseConfirmView(viewModel: viewModel, email: testEmail, passphrase: testPassphrase)

        let sut = try view.inspect()
        let button = try sut.find(viewWithAccessibilityIdentifier: "continueButton").button()

        #expect(try button.isDisabled() == false)
    }

    // MARK: - Match/Mismatch Indicator Tests

    @Test
    func mismatchLabelShownWhenMismatch() throws {
        let viewModel = AuthenticationViewModel()
        viewModel.confirmPassphrase = "wrong"
        let view = PassphraseConfirmView(viewModel: viewModel, email: testEmail, passphrase: testPassphrase)

        let sut = try view.inspect()
        let label = try sut.find(viewWithAccessibilityIdentifier: "mismatchLabel")

        #expect(label != nil)
    }

    @Test
    func matchLabelShownWhenMatch() throws {
        let viewModel = AuthenticationViewModel()
        viewModel.confirmPassphrase = testPassphrase
        let view = PassphraseConfirmView(viewModel: viewModel, email: testEmail, passphrase: testPassphrase)

        let sut = try view.inspect()
        let label = try sut.find(viewWithAccessibilityIdentifier: "matchLabel")

        #expect(label != nil)
    }

    @Test
    func noIndicatorWhenEmpty() throws {
        let viewModel = AuthenticationViewModel()
        viewModel.confirmPassphrase = ""
        let view = PassphraseConfirmView(viewModel: viewModel, email: testEmail, passphrase: testPassphrase)

        let sut = try view.inspect()

        #expect(throws: InspectionError.self) {
            try sut.find(viewWithAccessibilityIdentifier: "mismatchLabel")
        }
        #expect(throws: InspectionError.self) {
            try sut.find(viewWithAccessibilityIdentifier: "matchLabel")
        }
    }
}
