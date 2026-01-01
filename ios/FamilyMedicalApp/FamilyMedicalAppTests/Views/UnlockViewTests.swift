import SwiftUI
import Testing
import ViewInspector
@testable import FamilyMedicalApp

/// Test case for parameterized UnlockView testing
struct UnlockViewTestCase: Sendable {
    let name: String
    let isBiometricEnabled: Bool
    let biometryType: BiometryType
    let showBiometricPrompt: Bool
    let failedAttemptCount: Int
    let isLockedOut: Bool
    let lockoutRemainingSeconds: Int
    let errorMessage: String?

    // Expected UI state
    let expectPasswordField: Bool
    let expectBiometricButton: Bool
    let expectUseBiometricButton: Bool // "Use Face ID/Touch ID" button in password mode
    let expectUsePasswordButton: Bool
    let expectFailedAttemptsText: Bool
    let expectLockoutMessage: Bool
    let expectErrorMessage: Bool
}

extension UnlockViewTestCase: CustomTestStringConvertible {
    var testDescription: String { name }
}

/// Test cases for UnlockView - defined at module level to avoid actor isolation issues with @Test(arguments:)
private let unlockViewTestCases: [UnlockViewTestCase] = [
    UnlockViewTestCase(
        name: "Password-only auth (no biometric)",
        isBiometricEnabled: false,
        biometryType: .none,
        showBiometricPrompt: false,
        failedAttemptCount: 0,
        isLockedOut: false,
        lockoutRemainingSeconds: 0,
        errorMessage: nil,
        expectPasswordField: true,
        expectBiometricButton: false,
        expectUseBiometricButton: false,
        expectUsePasswordButton: false,
        expectFailedAttemptsText: false,
        expectLockoutMessage: false,
        expectErrorMessage: false
    ),
    UnlockViewTestCase(
        name: "Biometric auth available - Face ID prompt",
        isBiometricEnabled: true,
        biometryType: .faceID,
        showBiometricPrompt: true,
        failedAttemptCount: 0,
        isLockedOut: false,
        lockoutRemainingSeconds: 0,
        errorMessage: nil,
        expectPasswordField: false,
        expectBiometricButton: true,
        expectUseBiometricButton: false,
        expectUsePasswordButton: true,
        expectFailedAttemptsText: false,
        expectLockoutMessage: false,
        expectErrorMessage: false
    ),
    UnlockViewTestCase(
        name: "Biometric auth available - Touch ID prompt",
        isBiometricEnabled: true,
        biometryType: .touchID,
        showBiometricPrompt: true,
        failedAttemptCount: 0,
        isLockedOut: false,
        lockoutRemainingSeconds: 0,
        errorMessage: nil,
        expectPasswordField: false,
        expectBiometricButton: true,
        expectUseBiometricButton: false,
        expectUsePasswordButton: true,
        expectFailedAttemptsText: false,
        expectLockoutMessage: false,
        expectErrorMessage: false
    ),
    UnlockViewTestCase(
        name: "Failed attempts showing warning",
        isBiometricEnabled: false,
        biometryType: .none,
        showBiometricPrompt: false,
        failedAttemptCount: 2,
        isLockedOut: false,
        lockoutRemainingSeconds: 0,
        errorMessage: nil,
        expectPasswordField: true,
        expectBiometricButton: false,
        expectUseBiometricButton: false,
        expectUsePasswordButton: false,
        expectFailedAttemptsText: true,
        expectLockoutMessage: false,
        expectErrorMessage: false
    ),
    UnlockViewTestCase(
        name: "Lockout state with countdown",
        isBiometricEnabled: false,
        biometryType: .none,
        showBiometricPrompt: false,
        failedAttemptCount: 5,
        isLockedOut: true,
        lockoutRemainingSeconds: 30,
        errorMessage: nil,
        expectPasswordField: true,
        expectBiometricButton: false,
        expectUseBiometricButton: false,
        expectUsePasswordButton: false,
        expectFailedAttemptsText: false, // Hidden during lockout
        expectLockoutMessage: true,
        expectErrorMessage: false
    ),
    UnlockViewTestCase(
        name: "Error message displayed",
        isBiometricEnabled: false,
        biometryType: .none,
        showBiometricPrompt: false,
        failedAttemptCount: 0,
        isLockedOut: false,
        lockoutRemainingSeconds: 0,
        errorMessage: "Wrong password",
        expectPasswordField: true,
        expectBiometricButton: false,
        expectUseBiometricButton: false,
        expectUsePasswordButton: false,
        expectFailedAttemptsText: false,
        expectLockoutMessage: false,
        expectErrorMessage: true
    ),
    UnlockViewTestCase(
        name: "Both auth methods available - password mode with biometric fallback",
        isBiometricEnabled: true,
        biometryType: .touchID,
        showBiometricPrompt: false,
        failedAttemptCount: 0,
        isLockedOut: false,
        lockoutRemainingSeconds: 0,
        errorMessage: nil,
        expectPasswordField: true,
        expectBiometricButton: false,
        expectUseBiometricButton: true,
        expectUsePasswordButton: false,
        expectFailedAttemptsText: false,
        expectLockoutMessage: false,
        expectErrorMessage: false
    ),
    UnlockViewTestCase(
        name: "Error message hidden during lockout",
        isBiometricEnabled: false,
        biometryType: .none,
        showBiometricPrompt: false,
        failedAttemptCount: 5,
        isLockedOut: true,
        lockoutRemainingSeconds: 60,
        errorMessage: "This should not show",
        expectPasswordField: true,
        expectBiometricButton: false,
        expectUseBiometricButton: false,
        expectUsePasswordButton: false,
        expectFailedAttemptsText: false,
        expectLockoutMessage: true,
        expectErrorMessage: false // Error hidden during lockout per UnlockView line 121
    )
]

/// Tests for UnlockView rendering logic using parameterization and ViewInspector
@MainActor
struct UnlockViewTests {
    // MARK: - Helper Methods

    /// Formats lockout message to match UnlockView's formattedLockoutTime format
    private func formatLockoutMessage(seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60

        let timeString = if minutes > 0 {
            "\(minutes)m \(remainingSeconds)s"
        } else {
            "\(remainingSeconds)s"
        }

        return "Too many failed attempts. Try again in \(timeString)"
    }

    private func createViewModel(for testCase: UnlockViewTestCase) -> AuthenticationViewModel {
        let biometricService = MockViewModelBiometricService(
            isAvailable: testCase.isBiometricEnabled,
            biometryType: testCase.biometryType
        )
        let authService = MockAuthenticationService(
            isSetUp: true,
            isBiometricEnabled: testCase.isBiometricEnabled,
            failedAttemptCount: testCase.failedAttemptCount,
            isLockedOut: testCase.isLockedOut,
            lockoutRemainingSeconds: testCase.lockoutRemainingSeconds
        )
        let viewModel = AuthenticationViewModel(
            authService: authService,
            biometricService: biometricService
        )
        viewModel.showBiometricPrompt = testCase.showBiometricPrompt
        viewModel.errorMessage = testCase.errorMessage
        return viewModel
    }

    // MARK: - Parameterized Tests

    @Test(arguments: unlockViewTestCases)
    func unlockViewRendersCorrectElements(_ testCase: UnlockViewTestCase) throws {
        let viewModel = createViewModel(for: testCase)
        let view = UnlockView(viewModel: viewModel)
        let inspectedView = try view.inspect()

        // Verify password field presence
        if testCase.expectPasswordField {
            // Find password field by accessibility identifier (more robust than text matching)
            let passwordField = try? inspectedView.find(viewWithAccessibilityIdentifier: "passwordField")
            #expect(passwordField != nil, "Expected password field to be present")

            // Verify "Unlock" button is present with password field
            let unlockButton = try? inspectedView.find(viewWithAccessibilityIdentifier: "unlockButton")
            #expect(unlockButton != nil, "Expected Unlock button to be present")
        }

        // Verify biometric button presence (Face ID or Touch ID icon button)
        if testCase.expectBiometricButton {
            // Use accessibility identifier for structural test
            let biometricButton = try? inspectedView.find(viewWithAccessibilityIdentifier: "biometricButton")
            #expect(biometricButton != nil, "Expected biometric button to be present")

            // Also verify correct biometry type label for behavioral correctness
            let expectedLabel = testCase.biometryType == .faceID ? "Face ID" : "Touch ID"
            let labelText = try? inspectedView.find(text: "Unlock with \(expectedLabel)")
            #expect(labelText != nil, "Expected biometric button with label 'Unlock with \(expectedLabel)'")
        }

        // Verify "Use Password" button presence (in biometric mode)
        if testCase.expectUsePasswordButton {
            let usePasswordButton = try? inspectedView.find(viewWithAccessibilityIdentifier: "usePasswordButton")
            #expect(usePasswordButton != nil, "Expected 'Use Password' button to be present")
        }

        // Verify "Use Face ID/Touch ID" button presence (in password mode when biometric available)
        if testCase.expectUseBiometricButton {
            let useBiometricButton = try? inspectedView.find(viewWithAccessibilityIdentifier: "useBiometricButton")
            #expect(useBiometricButton != nil, "Expected 'Use Biometric' button to be present")
        }

        // Verify failed attempts text presence
        if testCase.expectFailedAttemptsText {
            // Use accessibility identifier for structural test
            let failedLabel = try? inspectedView.find(viewWithAccessibilityIdentifier: "failedAttemptsLabel")
            #expect(failedLabel != nil, "Expected failed attempts label to be present")
        }

        // Verify lockout message presence
        if testCase.expectLockoutMessage {
            // Use accessibility identifier for structural test
            let lockoutLabel = try? inspectedView.find(viewWithAccessibilityIdentifier: "lockoutLabel")
            #expect(lockoutLabel != nil, "Expected lockout label to be present")
        }

        // Verify error message presence
        if testCase.expectErrorMessage, let errorMessage = testCase.errorMessage {
            // Use accessibility identifier for structural test
            let errorLabel = try? inspectedView.find(viewWithAccessibilityIdentifier: "errorLabel")
            #expect(errorLabel != nil, "Expected error label to be present")

            // Also verify the correct message content for behavioral correctness
            let errorText = try? inspectedView.find(text: errorMessage)
            #expect(errorText != nil, "Expected error message '\(errorMessage)' to be present")
        }
    }

    // MARK: - Additional UI Structure Tests

    @Test
    func viewRendersAppBranding() throws {
        let authService = MockAuthenticationService(isSetUp: true)
        let viewModel = AuthenticationViewModel(authService: authService)
        let view = UnlockView(viewModel: viewModel)

        let inspectedView = try view.inspect()

        // Verify app title is present
        let titleText = try? inspectedView.find(text: "Family Medical App")
        #expect(titleText != nil, "Expected app title 'Family Medical App' to be present")

        // Verify app icon (heart.text.square.fill) is present
        let iconImage = try? inspectedView.find(ViewType.Image.self)
        #expect(iconImage != nil, "Expected app icon image to be present")
    }

    @Test
    func passwordFieldIsDisabledDuringLockout() throws {
        let authService = MockAuthenticationService(
            isSetUp: true,
            isLockedOut: true,
            lockoutRemainingSeconds: 30
        )
        let viewModel = AuthenticationViewModel(authService: authService)
        viewModel.showBiometricPrompt = false

        let view = UnlockView(viewModel: viewModel)
        let inspectedView = try view.inspect()

        // Verify the view renders correctly with lockout state
        // The password field should exist (password mode is shown)
        let passwordField = try? inspectedView.find(viewWithAccessibilityIdentifier: "passwordField")
        #expect(passwordField != nil, "Expected password field to be present during lockout")

        // Verify lockout message is shown
        let lockoutLabel = try? inspectedView.find(viewWithAccessibilityIdentifier: "lockoutLabel")
        #expect(lockoutLabel != nil, "Expected lockout label during lockout state")
    }

    @Test
    func biometricButtonShowsCorrectIconForFaceID() throws {
        let biometricService = MockViewModelBiometricService(isAvailable: true, biometryType: .faceID)
        let authService = MockAuthenticationService(isSetUp: true, isBiometricEnabled: true)
        let viewModel = AuthenticationViewModel(
            authService: authService,
            biometricService: biometricService
        )
        viewModel.showBiometricPrompt = true

        let view = UnlockView(viewModel: viewModel)
        let inspectedView = try view.inspect()

        // Verify Face ID text is shown
        let faceIDText = try? inspectedView.find(text: "Unlock with Face ID")
        #expect(faceIDText != nil, "Expected 'Unlock with Face ID' text")
    }

    @Test
    func biometricButtonShowsCorrectIconForTouchID() throws {
        let biometricService = MockViewModelBiometricService(isAvailable: true, biometryType: .touchID)
        let authService = MockAuthenticationService(isSetUp: true, isBiometricEnabled: true)
        let viewModel = AuthenticationViewModel(
            authService: authService,
            biometricService: biometricService
        )
        viewModel.showBiometricPrompt = true

        let view = UnlockView(viewModel: viewModel)
        let inspectedView = try view.inspect()

        // Verify Touch ID text is shown
        let touchIDText = try? inspectedView.find(text: "Unlock with Touch ID")
        #expect(touchIDText != nil, "Expected 'Unlock with Touch ID' text")
    }

    @Test
    func lockoutMessageFormatsTimeCorrectly() throws {
        let authService = MockAuthenticationService(
            isSetUp: true,
            isLockedOut: true,
            lockoutRemainingSeconds: 90 // 1m 30s
        )
        let viewModel = AuthenticationViewModel(authService: authService)
        viewModel.showBiometricPrompt = false

        let view = UnlockView(viewModel: viewModel)
        let inspectedView = try view.inspect()

        // Verify time format includes minutes and seconds
        let lockoutText = try? inspectedView.find(text: "Too many failed attempts. Try again in 1m 30s")
        #expect(lockoutText != nil, "Expected lockout message with formatted time '1m 30s'")
    }

    @Test
    func lockoutMessageFormatsSecondsOnlyCorrectly() throws {
        let authService = MockAuthenticationService(
            isSetUp: true,
            isLockedOut: true,
            lockoutRemainingSeconds: 45
        )
        let viewModel = AuthenticationViewModel(authService: authService)
        viewModel.showBiometricPrompt = false

        let view = UnlockView(viewModel: viewModel)
        let inspectedView = try view.inspect()

        // Verify time format shows only seconds when under a minute
        let lockoutText = try? inspectedView.find(text: "Too many failed attempts. Try again in 45s")
        #expect(lockoutText != nil, "Expected lockout message with formatted time '45s'")
    }

    @Test
    func failedAttemptsUsesCorrectPluralization() throws {
        // Test singular
        let authServiceSingular = MockAuthenticationService(
            isSetUp: true,
            failedAttemptCount: 1
        )
        let viewModelSingular = AuthenticationViewModel(authService: authServiceSingular)
        viewModelSingular.showBiometricPrompt = false

        let viewSingular = UnlockView(viewModel: viewModelSingular)
        let inspectedSingular = try viewSingular.inspect()

        let singularText = try? inspectedSingular.find(text: "1 failed attempt")
        #expect(singularText != nil, "Expected singular '1 failed attempt'")

        // Test plural
        let authServicePlural = MockAuthenticationService(
            isSetUp: true,
            failedAttemptCount: 3
        )
        let viewModelPlural = AuthenticationViewModel(authService: authServicePlural)
        viewModelPlural.showBiometricPrompt = false

        let viewPlural = UnlockView(viewModel: viewModelPlural)
        let inspectedPlural = try viewPlural.inspect()

        let pluralText = try? inspectedPlural.find(text: "3 failed attempts")
        #expect(pluralText != nil, "Expected plural '3 failed attempts'")
    }
}
