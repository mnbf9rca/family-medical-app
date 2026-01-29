import Testing
import ViewInspector
@testable import FamilyMedicalApp

@MainActor
struct WelcomeViewTests {
    // MARK: - View Structure Tests

    @Test
    func viewContainsAppBranding() throws {
        let viewModel = AuthenticationViewModel()
        let view = WelcomeView(viewModel: viewModel)

        let sut = try view.inspect()

        // Verify app icon exists
        let icon = try sut.find(viewWithAccessibilityLabel: "Family Medical App icon")
        #expect(icon != nil)
    }

    @Test
    func viewContainsCreateAccountButton() throws {
        let viewModel = AuthenticationViewModel()
        let view = WelcomeView(viewModel: viewModel)

        let sut = try view.inspect()

        let button = try sut.find(viewWithAccessibilityIdentifier: "createAccountButton")
        #expect(button != nil)
    }

    @Test
    func viewContainsSignInButton() throws {
        let viewModel = AuthenticationViewModel()
        let view = WelcomeView(viewModel: viewModel)

        let sut = try view.inspect()

        let button = try sut.find(viewWithAccessibilityIdentifier: "signInButton")
        #expect(button != nil)
    }
}
