import Testing
import ViewInspector
@testable import FamilyMedicalApp

@MainActor
struct BiometricSetupViewTests {
    private let testUsername = "testuser"
    private let testPassphrase = "valid-test-passphrase-123"

    // MARK: - View Structure Tests

    @Test
    func viewContainsEnableBiometricButton() throws {
        let viewModel = AuthenticationViewModel()
        let view = BiometricSetupView(viewModel: viewModel, username: testUsername, passphrase: testPassphrase)

        let sut = try view.inspect()
        // find() throws if not found
        _ = try sut.find(viewWithAccessibilityIdentifier: "enableBiometricButton")
    }

    @Test
    func viewContainsSkipButton() throws {
        let viewModel = AuthenticationViewModel()
        let view = BiometricSetupView(viewModel: viewModel, username: testUsername, passphrase: testPassphrase)

        let sut = try view.inspect()
        // find() throws if not found
        _ = try sut.find(viewWithAccessibilityIdentifier: "skipButton")
    }

    @Test
    func viewContainsBackButton() throws {
        let viewModel = AuthenticationViewModel()
        let view = BiometricSetupView(viewModel: viewModel, username: testUsername, passphrase: testPassphrase)

        let sut = try view.inspect()
        // find() throws if not found
        _ = try sut.find(viewWithAccessibilityIdentifier: "backButton")
    }

    // MARK: - Button State Tests

    @Test
    func skipButtonAlwaysEnabled() throws {
        let viewModel = AuthenticationViewModel()
        viewModel.isLoading = false
        let view = BiometricSetupView(viewModel: viewModel, username: testUsername, passphrase: testPassphrase)

        let sut = try view.inspect()
        let button = try sut.find(viewWithAccessibilityIdentifier: "skipButton").button()

        #expect(try button.isDisabled() == false)
    }

    @Test
    func skipButtonDisabledWhenLoading() throws {
        let viewModel = AuthenticationViewModel()
        viewModel.isLoading = true
        let view = BiometricSetupView(viewModel: viewModel, username: testUsername, passphrase: testPassphrase)

        let sut = try view.inspect()
        let button = try sut.find(viewWithAccessibilityIdentifier: "skipButton").button()

        #expect(try button.isDisabled() == true)
    }

    // MARK: - Error Display Tests

    @Test
    func errorLabelShownWhenErrorPresent() throws {
        let viewModel = AuthenticationViewModel()
        viewModel.errorMessage = "Biometric setup failed"
        let view = BiometricSetupView(viewModel: viewModel, username: testUsername, passphrase: testPassphrase)

        let sut = try view.inspect()
        // find() throws if not found
        _ = try sut.find(viewWithAccessibilityIdentifier: "errorLabel")
    }

    @Test
    func errorLabelHiddenWhenNoError() throws {
        let viewModel = AuthenticationViewModel()
        viewModel.errorMessage = nil
        let view = BiometricSetupView(viewModel: viewModel, username: testUsername, passphrase: testPassphrase)

        let sut = try view.inspect()

        #expect(throws: InspectionError.self) {
            try sut.find(viewWithAccessibilityIdentifier: "errorLabel")
        }
    }
}
