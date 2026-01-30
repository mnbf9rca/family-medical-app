import Testing
import ViewInspector
@testable import FamilyMedicalApp

@MainActor
struct UsernameEntryViewTests {
    // MARK: - View Structure Tests

    @Test
    func viewContainsUsernameField() throws {
        let viewModel = AuthenticationViewModel()
        let view = UsernameEntryView(viewModel: viewModel, isNewUser: true)

        let sut = try view.inspect()

        let usernameField = try sut.find(viewWithAccessibilityIdentifier: "usernameField")
        #expect(usernameField != nil)
    }

    @Test
    func viewContainsContinueButton() throws {
        let viewModel = AuthenticationViewModel()
        let view = UsernameEntryView(viewModel: viewModel, isNewUser: true)

        let sut = try view.inspect()

        let button = try sut.find(viewWithAccessibilityIdentifier: "continueButton")
        #expect(button != nil)
    }

    @Test
    func viewContainsBackButton() throws {
        let viewModel = AuthenticationViewModel()
        let view = UsernameEntryView(viewModel: viewModel, isNewUser: true)

        let sut = try view.inspect()

        let button = try sut.find(viewWithAccessibilityIdentifier: "backButton")
        #expect(button != nil)
    }

    // MARK: - Button State Tests

    @Test
    func continueButtonDisabledWhenUsernameInvalid() throws {
        let viewModel = AuthenticationViewModel()
        viewModel.username = "ab" // Too short
        let view = UsernameEntryView(viewModel: viewModel, isNewUser: true)

        let sut = try view.inspect()
        let button = try sut.find(viewWithAccessibilityIdentifier: "continueButton").button()

        #expect(try button.isDisabled() == true)
    }

    @Test
    func continueButtonEnabledWhenUsernameValid() throws {
        let viewModel = AuthenticationViewModel()
        viewModel.username = "testuser"
        let view = UsernameEntryView(viewModel: viewModel, isNewUser: true)

        let sut = try view.inspect()
        let button = try sut.find(viewWithAccessibilityIdentifier: "continueButton").button()

        #expect(try button.isDisabled() == false)
    }

    // MARK: - Error Display Tests

    @Test
    func errorLabelShowsWhenErrorPresent() throws {
        let viewModel = AuthenticationViewModel()
        viewModel.errorMessage = "Test error"
        let view = UsernameEntryView(viewModel: viewModel, isNewUser: true)

        let sut = try view.inspect()
        let errorLabel = try sut.find(viewWithAccessibilityIdentifier: "errorLabel")

        #expect(errorLabel != nil)
    }

    @Test
    func errorLabelHiddenWhenNoError() throws {
        let viewModel = AuthenticationViewModel()
        viewModel.errorMessage = nil
        let view = UsernameEntryView(viewModel: viewModel, isNewUser: true)

        let sut = try view.inspect()

        #expect(throws: InspectionError.self) {
            try sut.find(viewWithAccessibilityIdentifier: "errorLabel")
        }
    }
}
