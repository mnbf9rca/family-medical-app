import Testing
import ViewInspector
@testable import FamilyMedicalApp

@MainActor
struct PassphraseConfirmViewTests {
    private let testUsername = "testuser"
    private let testPassphrase = "valid-test-passphrase-123"

    // MARK: - View Structure Tests

    @Test
    func viewContainsConfirmField() throws {
        let viewModel = AuthenticationViewModel()
        let view = PassphraseConfirmView(viewModel: viewModel, username: testUsername, passphrase: testPassphrase)

        let sut = try view.inspect()
        // find() throws if not found
        _ = try sut.find(viewWithAccessibilityIdentifier: "confirmPassphraseField")
    }

    @Test
    func viewContainsContinueButton() throws {
        let viewModel = AuthenticationViewModel()
        let view = PassphraseConfirmView(viewModel: viewModel, username: testUsername, passphrase: testPassphrase)

        let sut = try view.inspect()
        // find() throws if not found
        _ = try sut.find(viewWithAccessibilityIdentifier: "continueButton")
    }

    @Test
    func viewContainsBackButton() throws {
        let viewModel = AuthenticationViewModel()
        let view = PassphraseConfirmView(viewModel: viewModel, username: testUsername, passphrase: testPassphrase)

        let sut = try view.inspect()
        // find() throws if not found
        _ = try sut.find(viewWithAccessibilityIdentifier: "backButton")
    }

    // MARK: - Button State Tests

    @Test
    func continueButtonDisabledWhenConfirmEmpty() throws {
        let viewModel = AuthenticationViewModel()
        viewModel.confirmPassphrase = ""
        let view = PassphraseConfirmView(viewModel: viewModel, username: testUsername, passphrase: testPassphrase)

        let sut = try view.inspect()
        let button = try sut.find(viewWithAccessibilityIdentifier: "continueButton").button()

        #expect(try button.isDisabled() == true)
    }

    @Test
    func continueButtonDisabledWhenMismatch() throws {
        let viewModel = AuthenticationViewModel()
        viewModel.confirmPassphrase = "wrong-passphrase"
        let view = PassphraseConfirmView(viewModel: viewModel, username: testUsername, passphrase: testPassphrase)

        let sut = try view.inspect()
        let button = try sut.find(viewWithAccessibilityIdentifier: "continueButton").button()

        #expect(try button.isDisabled() == true)
    }

    @Test
    func continueButtonEnabledWhenMatch() throws {
        let viewModel = AuthenticationViewModel()
        viewModel.confirmPassphrase = testPassphrase
        let view = PassphraseConfirmView(viewModel: viewModel, username: testUsername, passphrase: testPassphrase)

        let sut = try view.inspect()
        let button = try sut.find(viewWithAccessibilityIdentifier: "continueButton").button()

        #expect(try button.isDisabled() == false)
    }

    // MARK: - Match/Mismatch Indicator Tests

    @Test
    func mismatchLabelShownWhenMismatch() throws {
        let viewModel = AuthenticationViewModel()
        viewModel.confirmPassphrase = "wrong"
        let view = PassphraseConfirmView(viewModel: viewModel, username: testUsername, passphrase: testPassphrase)

        let sut = try view.inspect()
        // find() throws if not found
        _ = try sut.find(viewWithAccessibilityIdentifier: "mismatchLabel")
    }

    @Test
    func matchLabelShownWhenMatch() throws {
        let viewModel = AuthenticationViewModel()
        viewModel.confirmPassphrase = testPassphrase
        let view = PassphraseConfirmView(viewModel: viewModel, username: testUsername, passphrase: testPassphrase)

        let sut = try view.inspect()
        // find() throws if not found
        _ = try sut.find(viewWithAccessibilityIdentifier: "matchLabel")
    }

    @Test
    func noIndicatorWhenEmpty() throws {
        let viewModel = AuthenticationViewModel()
        viewModel.confirmPassphrase = ""
        let view = PassphraseConfirmView(viewModel: viewModel, username: testUsername, passphrase: testPassphrase)

        let sut = try view.inspect()

        #expect(throws: InspectionError.self) {
            try sut.find(viewWithAccessibilityIdentifier: "mismatchLabel")
        }
        #expect(throws: InspectionError.self) {
            try sut.find(viewWithAccessibilityIdentifier: "matchLabel")
        }
    }
}
