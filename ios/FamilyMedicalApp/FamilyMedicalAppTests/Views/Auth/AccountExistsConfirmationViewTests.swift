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

        // Should have the "Account Found" title
        let title = try sut.find(text: "Account Found")
        #expect(title != nil)
    }

    @Test
    func viewRendersWithUsername() throws {
        let viewModel = AuthenticationViewModel(authService: MockAuthenticationService())
        let view = AccountExistsConfirmationView(viewModel: viewModel, username: "myusername")

        let sut = try view.inspect()

        // Should show the username in the message
        let messageText = try sut.find(ViewType.Text.self) { text in
            let string = try? text.string()
            return string?.contains("myusername") == true
        }
        #expect(messageText != nil)
    }

    @Test
    func viewRendersLogInButton() throws {
        let viewModel = AuthenticationViewModel(authService: MockAuthenticationService())
        let view = AccountExistsConfirmationView(viewModel: viewModel, username: "testuser")

        let sut = try view.inspect()

        // Should have a "Log In" button
        let button = try sut.find(viewWithAccessibilityIdentifier: "confirmLoginButton")
        #expect(button != nil)
    }

    @Test
    func viewRendersCancelButton() throws {
        let viewModel = AuthenticationViewModel(authService: MockAuthenticationService())
        let view = AccountExistsConfirmationView(viewModel: viewModel, username: "testuser")

        let sut = try view.inspect()

        // Should have a "Cancel" button
        let button = try sut.find(viewWithAccessibilityIdentifier: "cancelButton")
        #expect(button != nil)
    }
}
