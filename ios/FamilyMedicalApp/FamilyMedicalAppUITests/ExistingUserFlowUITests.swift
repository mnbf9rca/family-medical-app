//
//  ExistingUserFlowUITests.swift
//  FamilyMedicalAppUITests
//
//  Created by rob on 29/12/2025.
//

import XCTest

/// Tests for existing user login/unlock flow
/// - Note: Ensure hardware keyboard is disabled in simulator: I/O → Keyboard → Connect Hardware Keyboard (unchecked)
///   This prevents password autofill prompts from interfering with UI tests
final class ExistingUserFlowUITests: XCTestCase {
    var app: XCUIApplication!
    let testPassword = "unique-horse-battery-staple-2024"

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()

        // Add UI interruption monitor to handle password autofill prompts
        addUIInterruptionMonitor(withDescription: "Password Autofill") { alert in
            if alert.buttons["Not Now"].exists {
                alert.buttons["Not Now"].tap()
                return true
            }
            if alert.buttons["Cancel"].exists {
                alert.buttons["Cancel"].tap()
                return true
            }
            return false
        }
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Unlock Tests

    @MainActor
    func testUnlockWithCorrectPassword() throws {
        // Setup: Create account first
        app.launchForUITesting(resetState: true)
        app.createAccount(password: testPassword)

        // Terminate and relaunch (simulates returning user)
        app.terminate()
        app.launchForUITesting(resetState: false)

        // Verify UnlockView appears
        let appTitle = app.staticTexts["Family Medical App"]
        XCTAssertTrue(appTitle.waitForExistence(timeout: 5), "Unlock view should appear")

        // Unlock
        app.unlockApp(password: testPassword)

        // Verify we're on HomeView
        let navTitle = app.navigationBars["Members"]
        XCTAssertTrue(navTitle.exists, "Should be on main app after unlock")
    }

    @MainActor
    func testUnlockWithIncorrectPassword() throws {
        // Setup: Create account first
        app.launchForUITesting(resetState: true)
        app.createAccount(password: testPassword)

        // Terminate and relaunch
        app.terminate()
        app.launchForUITesting(resetState: false)

        let appTitle = app.staticTexts["Family Medical App"]
        XCTAssertTrue(appTitle.waitForExistence(timeout: 5))

        // Skip biometric if shown
        let usePasswordButton = app.buttons["Use Password"]
        if usePasswordButton.exists {
            usePasswordButton.tap()
        }

        // Enter WRONG password
        let passwordField = app.passwordField("Enter password")
        XCTAssertTrue(passwordField.waitForExistence(timeout: 2))
        passwordField.tap()
        passwordField.typeText("WrongPassword123")

        // Tap Unlock
        let unlockButton = app.buttons["Unlock"]
        unlockButton.tap()

        // Should see failed attempts counter
        let failedAttemptText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'failed attempt'")).firstMatch
        XCTAssertTrue(
            failedAttemptText.waitForExistence(timeout: 2),
            "Failed attempts counter should appear after wrong password"
        )
    }

    @MainActor
    func testFailedAttemptsCounterIncreases() throws {
        // Setup: Create account first
        app.launchForUITesting(resetState: true)
        app.createAccount(password: testPassword)

        // Terminate and relaunch
        app.terminate()
        app.launchForUITesting(resetState: false)

        let appTitle = app.staticTexts["Family Medical App"]
        XCTAssertTrue(appTitle.waitForExistence(timeout: 5))

        // Skip biometric if shown
        let usePasswordButton = app.buttons["Use Password"]
        if usePasswordButton.exists {
            usePasswordButton.tap()
        }

        // First failed attempt
        let passwordField = app.passwordField("Enter password")
        XCTAssertTrue(passwordField.waitForExistence(timeout: 2))
        passwordField.tap()
        passwordField.typeText("Wrong1")
        app.buttons["Unlock"].tap()

        // Wait briefly for error
        sleep(1)

        // Check counter shows "1 failed attempt"
        let failedAttempt1 = app.staticTexts["1 failed attempt"]
        XCTAssertTrue(failedAttempt1.waitForExistence(timeout: 2), "Should show 1 failed attempt")

        // Clear password field and try again
        passwordField.tap()
        passwordField.clearText()
        passwordField.typeText("Wrong2")
        app.buttons["Unlock"].tap()

        // Wait briefly
        sleep(1)

        // Check counter shows "2 failed attempts"
        let failedAttempt2 = app.staticTexts["2 failed attempts"]
        XCTAssertTrue(failedAttempt2.waitForExistence(timeout: 2), "Should show 2 failed attempts")
    }

    @MainActor
    func testUnlockViewElements() throws {
        // Setup: Create account first
        app.launchForUITesting(resetState: true)
        app.createAccount(password: testPassword)

        // Terminate and relaunch
        app.terminate()
        app.launchForUITesting(resetState: false)

        // Verify all expected elements exist
        XCTAssertTrue(app.staticTexts["Family Medical App"].waitForExistence(timeout: 5))

        // Either biometric button or password field should exist
        let hasBiometricButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Unlock with'")).firstMatch.exists
        let hasPasswordField = app.passwordField("Enter password").exists

        XCTAssertTrue(
            hasBiometricButton || hasPasswordField,
            "Should show either biometric button or password field"
        )
    }

    @MainActor
    func testSwitchFromBiometricToPassword() throws {
        // Setup: Create account first
        app.launchForUITesting(resetState: true)
        app.createAccount(password: testPassword)

        // Terminate and relaunch
        app.terminate()
        app.launchForUITesting(resetState: false)

        let appTitle = app.staticTexts["Family Medical App"]
        XCTAssertTrue(appTitle.waitForExistence(timeout: 5))

        // If biometric button is shown
        let usePasswordButton = app.buttons["Use Password"]
        if usePasswordButton.exists {
            usePasswordButton.tap()

            // Password field should now appear
            let passwordField = app.passwordField("Enter password")
            XCTAssertTrue(passwordField.waitForExistence(timeout: 2), "Password field should appear after tapping 'Use Password'")
        }
    }
}

// MARK: - XCUIElement Extension for text clearing

extension XCUIElement {
    /// Clear text from a text field
    func clearText() {
        guard let stringValue = self.value as? String else {
            return
        }

        // Tap the field to focus
        self.tap()

        // Delete each character
        let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: stringValue.count)
        self.typeText(deleteString)
    }
}
