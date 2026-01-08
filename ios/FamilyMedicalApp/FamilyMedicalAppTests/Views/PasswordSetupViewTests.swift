import SwiftUI
import Testing
import ViewInspector
@testable import FamilyMedicalApp

/// Tests for PasswordSetupView rendering logic
@MainActor
struct PasswordSetupViewTests {
    // MARK: - Test Constants

    private let validTestCredential = "valid-test-credential-123"
    private let weakTestCredential = "weak"
    private let differentTestCredential = "different"

    // MARK: - View Body Tests

    @Test
    func passwordSetupViewRendersInitialState() throws {
        let authService = MockAuthenticationService(isSetUp: false)
        let viewModel = AuthenticationViewModel(authService: authService)

        let view = PasswordSetupView(viewModel: viewModel)

        // Verify core structure renders
        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.ScrollView.self)
        _ = try inspected.find(text: "Secure Your Medical Records")
        _ = try inspected.find(text: "Username")
        _ = try inspected.find(text: "Password")
    }

    @Test
    func passwordSetupViewRendersWithBiometricAvailable() throws {
        let biometricService = MockViewModelBiometricService(isAvailable: true, biometryType: .faceID)
        let authService = MockAuthenticationService(isSetUp: false)
        let viewModel = AuthenticationViewModel(
            authService: authService,
            biometricService: biometricService
        )

        let view = PasswordSetupView(viewModel: viewModel)

        // Verify biometric toggle is present when available
        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.Toggle.self)
        _ = try inspected.find(text: "Enable Face ID")
    }

    @Test
    func passwordSetupViewRendersWithTouchID() throws {
        let biometricService = MockViewModelBiometricService(isAvailable: true, biometryType: .touchID)
        let authService = MockAuthenticationService(isSetUp: false)
        let viewModel = AuthenticationViewModel(
            authService: authService,
            biometricService: biometricService
        )

        let view = PasswordSetupView(viewModel: viewModel)

        // Verify Touch ID text appears
        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.Toggle.self)
        _ = try inspected.find(text: "Enable Touch ID")
    }

    @Test
    func passwordSetupViewRendersWithPasswordEntered() throws {
        let authService = MockAuthenticationService(isSetUp: false)
        let viewModel = AuthenticationViewModel(authService: authService)
        viewModel.username = "testuser"
        viewModel.password = validTestCredential
        viewModel.confirmPassword = validTestCredential

        let view = PasswordSetupView(viewModel: viewModel)

        // Verify form renders with password strength indicator
        let inspected = try view.inspect()
        _ = try inspected.find(PasswordStrengthIndicator.self)
    }

    @Test
    func passwordSetupViewRendersWithValidationErrors() throws {
        let authService = MockAuthenticationService(isSetUp: false)
        let viewModel = AuthenticationViewModel(authService: authService)
        viewModel.username = "testuser"
        viewModel.password = weakTestCredential
        viewModel.confirmPassword = differentTestCredential
        viewModel.hasAttemptedSetup = true // Show validation errors

        let view = PasswordSetupView(viewModel: viewModel)

        // Verify validation error UI is present (ForEach with Label)
        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.Label.self)
    }

    @Test
    func passwordSetupViewRendersWithError() throws {
        let authService = MockAuthenticationService(isSetUp: false)
        let viewModel = AuthenticationViewModel(authService: authService)
        viewModel.errorMessage = "Test error"

        let view = PasswordSetupView(viewModel: viewModel)

        // Verify error message text is displayed
        let inspected = try view.inspect()
        let errorText = try inspected.find(text: "Test error")
        #expect(try errorText.string() == "Test error")
    }

    @Test
    func passwordSetupViewRendersLoading() throws {
        let authService = MockAuthenticationService(isSetUp: false)
        let viewModel = AuthenticationViewModel(authService: authService)
        viewModel.isLoading = true

        let view = PasswordSetupView(viewModel: viewModel)

        // Verify ProgressView is shown when loading
        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.ProgressView.self)
    }

    @Test
    func passwordSetupViewHidesProgressViewWhenNotLoading() throws {
        let authService = MockAuthenticationService(isSetUp: false)
        let viewModel = AuthenticationViewModel(authService: authService)
        viewModel.isLoading = false

        let view = PasswordSetupView(viewModel: viewModel)

        // Verify ProgressView is NOT shown when not loading
        let inspected = try view.inspect()
        #expect(throws: (any Error).self) {
            _ = try inspected.find(ViewType.ProgressView.self)
        }
    }

    @Test
    func passwordSetupViewShowsContinueButton() throws {
        let authService = MockAuthenticationService(isSetUp: false)
        let viewModel = AuthenticationViewModel(authService: authService)
        viewModel.isLoading = false

        let view = PasswordSetupView(viewModel: viewModel)

        // Verify Continue button text is shown when not loading
        let inspected = try view.inspect()
        _ = try inspected.find(text: "Continue")
    }
}
