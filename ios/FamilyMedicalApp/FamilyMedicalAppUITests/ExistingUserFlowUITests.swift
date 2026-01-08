//
//  ExistingUserFlowUITests.swift
//  FamilyMedicalAppUITests
//
//  Tests for existing user login/unlock flow
//
//  ## Test Chaining Pattern
//  Account creation happens once in class setUp, then all tests reuse that account.
//  This saves ~15 seconds per test (Argon2id key derivation is intentionally slow).
//
//  Each test:
//  1. Relaunches the app (without resetState, so account persists)
//  2. Tests unlock behavior
//  3. Terminates the app for the next test
//
//  ## Tradeoffs
//  - Pro: ~60% faster test execution
//  - Con: If class setUp fails, all tests fail
//  - Con: Tests share the same account (acceptable for unlock flow tests)
//
//  - Note: Ensure hardware keyboard is disabled in simulator:
//    I/O -> Keyboard -> Connect Hardware Keyboard (unchecked)
//    This prevents password autofill prompts from interfering with UI tests

import XCTest

/// Tests for existing user login/unlock flow
@MainActor
final class ExistingUserFlowUITests: XCTestCase {
    // MARK: - Shared State

    /// Shared app instance - created once, reused across tests
    nonisolated(unsafe) static var sharedApp: XCUIApplication!

    /// Instance accessor
    var app: XCUIApplication { Self.sharedApp }

    /// Password used to create the test account
    static let testPassword = "unique-horse-battery-staple-2024"

    // MARK: - Class Setup / Teardown

    nonisolated override class func setUp() {
        super.setUp()

        // Create account once for entire test class
        MainActor.assumeIsolated {
            sharedApp = XCUIApplication()
            sharedApp.launchForUITesting(resetState: true)
            sharedApp.createAccount(password: testPassword)
            sharedApp.terminate()
        }
    }

    nonisolated override class func tearDown() {
        MainActor.assumeIsolated {
            sharedApp?.terminate()
            sharedApp = nil
        }
        super.tearDown()
    }

    // MARK: - Per-Test Setup

    override func setUpWithError() throws {
        continueAfterFailure = false
        setupPasswordAutofillHandler()

        // Relaunch app for each test (keeps account from class setUp)
        MainActor.assumeIsolated {
            Self.sharedApp.launchForUITesting(resetState: false)
        }
    }

    override func tearDownWithError() throws {
        // Terminate after each test so next test starts fresh at unlock screen
        MainActor.assumeIsolated {
            Self.sharedApp.terminate()
        }
    }

    // MARK: - Unlock Tests

    func testUnlockWithCorrectPassword() throws {
        // Verify UnlockView appears (account was created in class setUp)
        let appTitle = app.staticTexts["Family Medical App"]
        XCTAssertTrue(appTitle.waitForExistence(timeout: 5), "Unlock view should appear")

        // Unlock
        app.unlockApp(password: Self.testPassword)

        // Verify we're on HomeView
        let navTitle = app.navigationBars["Members"]
        XCTAssertTrue(navTitle.exists, "Should be on main app after unlock")
    }

    func testUnlockWithIncorrectPassword() throws {
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

    func testFailedAttemptsCounterIncreases() throws {
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

        // Check counter shows "1 failed attempt"
        let failedAttempt1 = app.staticTexts["1 failed attempt"]
        XCTAssertTrue(failedAttempt1.waitForExistence(timeout: 2), "Should show 1 failed attempt")

        // Clear password field and try again
        passwordField.tap()
        passwordField.clearText()
        passwordField.typeText("Wrong2")
        app.buttons["Unlock"].tap()

        // Check counter shows "2 failed attempts"
        let failedAttempt2 = app.staticTexts["2 failed attempts"]
        XCTAssertTrue(failedAttempt2.waitForExistence(timeout: 2), "Should show 2 failed attempts")
    }

    func testUnlockViewElements() throws {
        // Verify all expected elements exist
        XCTAssertTrue(app.staticTexts["Family Medical App"].waitForExistence(timeout: 5))

        // Either biometric button or password field should exist
        // Use waitForExistence with timeout for CI reliability (elements may load slowly)
        let biometricButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Unlock with'")).firstMatch
        let passwordField = app.passwordField("Enter password")

        let hasBiometricButton = biometricButton.waitForExistence(timeout: 2)
        let hasPasswordField = passwordField.waitForExistence(timeout: 2)

        XCTAssertTrue(
            hasBiometricButton || hasPasswordField,
            "Should show either biometric button or password field"
        )
    }

    func testSwitchFromBiometricToPassword() throws {
        let appTitle = app.staticTexts["Family Medical App"]
        XCTAssertTrue(appTitle.waitForExistence(timeout: 5))

        // This test only applies when biometric authentication is available
        let usePasswordButton = app.buttons["Use Password"]
        try XCTSkipUnless(
            usePasswordButton.waitForExistence(timeout: 2),
            "Test requires biometric to be available (Use Password button must be shown)"
        )

        usePasswordButton.tap()

        // Password field should now appear
        let passwordField = app.passwordField("Enter password")
        XCTAssertTrue(
            passwordField.waitForExistence(timeout: 2),
            "Password field should appear after tapping 'Use Password'"
        )
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
