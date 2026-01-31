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

        // find() throws if not found
        _ = try sut.find(viewWithAccessibilityLabel: "Family Medical App icon")
    }

    @Test
    func viewContainsCreateAccountButton() throws {
        let viewModel = AuthenticationViewModel()
        let view = WelcomeView(viewModel: viewModel)

        let sut = try view.inspect()
        // find() throws if not found
        _ = try sut.find(viewWithAccessibilityIdentifier: "createAccountButton")
    }

    @Test
    func viewContainsSignInButton() throws {
        let viewModel = AuthenticationViewModel()
        let view = WelcomeView(viewModel: viewModel)

        let sut = try view.inspect()
        // find() throws if not found
        _ = try sut.find(viewWithAccessibilityIdentifier: "signInButton")
    }
}
