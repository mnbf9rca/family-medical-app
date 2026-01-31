import Foundation
import Testing
import ViewInspector
@testable import FamilyMedicalApp

/// Tests for AccountExistsConfirmationView
@MainActor
struct AccountExistsConfirmationViewTests {
    // MARK: - View Rendering Tests

    @Test
    func viewRendersWithCorrectTitle() throws {
        let viewModel = AuthenticationViewModel(authService: MockAuthenticationService())
        let view = AccountExistsConfirmationView(viewModel: viewModel, username: "testuser")

        let sut = try view.inspect()

        // find() throws if not found
        _ = try sut.find(text: "Account Found")
    }

    @Test
    func viewRendersWithUsername() throws {
        let viewModel = AuthenticationViewModel(authService: MockAuthenticationService())
        let view = AccountExistsConfirmationView(viewModel: viewModel, username: "myusername")

        let sut = try view.inspect()

        // find() throws if not found
        _ = try sut.find(ViewType.Text.self) { text in
            let string = try? text.string()
            return string?.contains("myusername") == true
        }
    }

    @Test
    func viewRendersLogInButton() throws {
        let viewModel = AuthenticationViewModel(authService: MockAuthenticationService())
        let view = AccountExistsConfirmationView(viewModel: viewModel, username: "testuser")

        let sut = try view.inspect()

        // find() throws if not found
        _ = try sut.find(viewWithAccessibilityIdentifier: "confirmLoginButton")
    }

    @Test
    func viewRendersCancelButton() throws {
        let viewModel = AuthenticationViewModel(authService: MockAuthenticationService())
        let view = AccountExistsConfirmationView(viewModel: viewModel, username: "testuser")

        let sut = try view.inspect()

        // find() throws if not found
        _ = try sut.find(viewWithAccessibilityIdentifier: "cancelButton")
    }
}
