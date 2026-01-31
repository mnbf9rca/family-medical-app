import Testing
import ViewInspector
@testable import FamilyMedicalApp

@MainActor
struct PassphraseEntryViewTests {
    private let testUsername = "testuser"

    // MARK: - View Structure Tests

    @Test
    func viewContainsPassphraseField() throws {
        let viewModel = AuthenticationViewModel()
        let view = PassphraseEntryView(viewModel: viewModel, username: testUsername)

        let sut = try view.inspect()
        // find() throws if not found
        _ = try sut.find(viewWithAccessibilityIdentifier: "passphraseField")
    }

    @Test
    func viewContainsContinueButton() throws {
        let viewModel = AuthenticationViewModel()
        let view = PassphraseEntryView(viewModel: viewModel, username: testUsername)

        let sut = try view.inspect()
        // find() throws if not found
        _ = try sut.find(viewWithAccessibilityIdentifier: "continueButton")
    }

    @Test
    func viewContainsBackButton() throws {
        let viewModel = AuthenticationViewModel()
        let view = PassphraseEntryView(viewModel: viewModel, username: testUsername)

        let sut = try view.inspect()
        // find() throws if not found
        _ = try sut.find(viewWithAccessibilityIdentifier: "backButton")
    }

    // MARK: - Button State Tests

    @Test
    func continueButtonDisabledWhenEmpty() throws {
        let viewModel = AuthenticationViewModel()
        viewModel.passphrase = ""
        let view = PassphraseEntryView(viewModel: viewModel, username: testUsername)

        let sut = try view.inspect()
        let button = try sut.find(viewWithAccessibilityIdentifier: "continueButton").button()

        #expect(try button.isDisabled() == true)
    }

    @Test
    func continueButtonEnabledWhenPassphraseEntered() throws {
        let viewModel = AuthenticationViewModel()
        viewModel.passphrase = "any-passphrase"
        let view = PassphraseEntryView(viewModel: viewModel, username: testUsername)

        let sut = try view.inspect()
        let button = try sut.find(viewWithAccessibilityIdentifier: "continueButton").button()

        #expect(try button.isDisabled() == false)
    }

    // MARK: - Error Display Tests

    @Test
    func errorLabelShownWhenErrorPresent() throws {
        let viewModel = AuthenticationViewModel()
        viewModel.errorMessage = "Invalid passphrase"
        let view = PassphraseEntryView(viewModel: viewModel, username: testUsername)

        let sut = try view.inspect()
        // find() throws if not found
        _ = try sut.find(viewWithAccessibilityIdentifier: "errorLabel")
    }

    @Test
    func errorLabelHiddenWhenNoError() throws {
        let viewModel = AuthenticationViewModel()
        viewModel.errorMessage = nil
        let view = PassphraseEntryView(viewModel: viewModel, username: testUsername)

        let sut = try view.inspect()

        #expect(throws: InspectionError.self) {
            try sut.find(viewWithAccessibilityIdentifier: "errorLabel")
        }
    }
}
