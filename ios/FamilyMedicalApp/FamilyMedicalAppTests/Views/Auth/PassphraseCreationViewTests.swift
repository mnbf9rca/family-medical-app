import Testing
import ViewInspector
@testable import FamilyMedicalApp

@MainActor
struct PassphraseCreationViewTests {
    private let testUsername = "testuser"

    // MARK: - View Structure Tests

    @Test
    func viewContainsPassphraseField() throws {
        let viewModel = AuthenticationViewModel()
        let view = PassphraseCreationView(viewModel: viewModel, username: testUsername)

        let sut = try view.inspect()
        let field = try sut.find(viewWithAccessibilityIdentifier: "passphraseField")

        #expect(field != nil)
    }

    @Test
    func viewContainsStrengthIndicator() throws {
        let viewModel = AuthenticationViewModel()
        let view = PassphraseCreationView(viewModel: viewModel, username: testUsername)

        let sut = try view.inspect()
        let indicator = try sut.find(viewWithAccessibilityIdentifier: "strengthIndicator")

        #expect(indicator != nil)
    }

    @Test
    func viewContainsContinueButton() throws {
        let viewModel = AuthenticationViewModel()
        let view = PassphraseCreationView(viewModel: viewModel, username: testUsername)

        let sut = try view.inspect()
        let button = try sut.find(viewWithAccessibilityIdentifier: "continueButton")

        #expect(button != nil)
    }

    @Test
    func viewContainsBackButton() throws {
        let viewModel = AuthenticationViewModel()
        let view = PassphraseCreationView(viewModel: viewModel, username: testUsername)

        let sut = try view.inspect()
        let button = try sut.find(viewWithAccessibilityIdentifier: "backButton")

        #expect(button != nil)
    }

    // MARK: - Button State Tests

    @Test
    func continueButtonDisabledWhenPassphraseEmpty() throws {
        let viewModel = AuthenticationViewModel()
        viewModel.passphrase = ""
        let view = PassphraseCreationView(viewModel: viewModel, username: testUsername)

        let sut = try view.inspect()
        let button = try sut.find(viewWithAccessibilityIdentifier: "continueButton").button()

        #expect(try button.isDisabled() == true)
    }

    @Test
    func continueButtonDisabledWhenPassphraseWeak() throws {
        let viewModel = AuthenticationViewModel()
        viewModel.passphrase = "short"
        let view = PassphraseCreationView(viewModel: viewModel, username: testUsername)

        let sut = try view.inspect()
        let button = try sut.find(viewWithAccessibilityIdentifier: "continueButton").button()

        #expect(try button.isDisabled() == true)
    }

    @Test
    func continueButtonEnabledWhenPassphraseStrong() throws {
        let viewModel = AuthenticationViewModel()
        viewModel.passphrase = "valid-test-passphrase-123"
        let view = PassphraseCreationView(viewModel: viewModel, username: testUsername)

        let sut = try view.inspect()
        let button = try sut.find(viewWithAccessibilityIdentifier: "continueButton").button()

        #expect(try button.isDisabled() == false)
    }

    // MARK: - Validation Hints Tests

    @Test
    func validationHintsShownWhenPassphraseWeak() throws {
        let viewModel = AuthenticationViewModel()
        viewModel.passphrase = "weak"
        let view = PassphraseCreationView(viewModel: viewModel, username: testUsername)

        let sut = try view.inspect()
        let hints = try sut.find(viewWithAccessibilityIdentifier: "validationHints")

        #expect(hints != nil)
        // Verify validation errors exist for weak passphrase
        #expect(!viewModel.passphraseValidationErrors.isEmpty)
    }

    @Test
    func validationHintsHiddenWhenPassphraseEmpty() throws {
        let viewModel = AuthenticationViewModel()
        viewModel.passphrase = ""
        let view = PassphraseCreationView(viewModel: viewModel, username: testUsername)

        let sut = try view.inspect()

        #expect(throws: InspectionError.self) {
            try sut.find(viewWithAccessibilityIdentifier: "validationHints")
        }
    }
}
