import Testing
import ViewInspector
@testable import FamilyMedicalApp

@MainActor
struct EmailEntryViewTests {
    // MARK: - View Structure Tests

    @Test
    func viewContainsAppBranding() throws {
        let viewModel = AuthenticationViewModel()
        let view = EmailEntryView(viewModel: viewModel)

        let sut = try view.inspect()

        // Verify app icon exists
        let icon = try sut.find(viewWithAccessibilityLabel: "Family Medical App icon")
        #expect(icon != nil)
    }

    @Test
    func viewContainsEmailField() throws {
        let viewModel = AuthenticationViewModel()
        let view = EmailEntryView(viewModel: viewModel)

        let sut = try view.inspect()

        let emailField = try sut.find(viewWithAccessibilityIdentifier: "emailField")
        #expect(emailField != nil)
    }

    @Test
    func viewContainsContinueButton() throws {
        let viewModel = AuthenticationViewModel()
        let view = EmailEntryView(viewModel: viewModel)

        let sut = try view.inspect()

        let button = try sut.find(viewWithAccessibilityIdentifier: "continueButton")
        #expect(button != nil)
    }

    // MARK: - Button State Tests

    @Test
    func continueButtonDisabledWhenEmailInvalid() throws {
        let viewModel = AuthenticationViewModel()
        viewModel.email = "invalid"
        let view = EmailEntryView(viewModel: viewModel)

        let sut = try view.inspect()
        let button = try sut.find(viewWithAccessibilityIdentifier: "continueButton").button()

        #expect(try button.isDisabled() == true)
    }

    @Test
    func continueButtonEnabledWhenEmailValid() throws {
        let viewModel = AuthenticationViewModel()
        viewModel.email = "test@example.com"
        let view = EmailEntryView(viewModel: viewModel)

        let sut = try view.inspect()
        let button = try sut.find(viewWithAccessibilityIdentifier: "continueButton").button()

        #expect(try button.isDisabled() == false)
    }

    // MARK: - Error Display Tests

    @Test
    func errorLabelShowsWhenErrorPresent() throws {
        let viewModel = AuthenticationViewModel()
        viewModel.errorMessage = "Test error"
        let view = EmailEntryView(viewModel: viewModel)

        let sut = try view.inspect()
        let errorLabel = try sut.find(viewWithAccessibilityIdentifier: "errorLabel")

        #expect(errorLabel != nil)
    }

    @Test
    func errorLabelHiddenWhenNoError() throws {
        let viewModel = AuthenticationViewModel()
        viewModel.errorMessage = nil
        let view = EmailEntryView(viewModel: viewModel)

        let sut = try view.inspect()

        #expect(throws: InspectionError.self) {
            try sut.find(viewWithAccessibilityIdentifier: "errorLabel")
        }
    }
}
