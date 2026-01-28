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

    /// Passphrase used to create the test account
    static let testPassphrase = "Unique-Horse-Battery-Staple-2024"

    // MARK: - Class Setup / Teardown

    nonisolated override class func setUp() {
        super.setUp()

        // Create account once for entire test class
        MainActor.assumeIsolated {
            sharedApp = XCUIApplication()
            sharedApp.launchForUITesting(resetState: true)
            sharedApp.createAccount(password: testPassphrase)
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

    func testUnlockWithCorrectPassphrase() throws {
        // Verify UnlockView appears (account was created in class setUp)
        let appTitle = app.staticTexts["Family Medical App"]
        XCTAssertTrue(appTitle.waitForExistence(timeout: 5), "Unlock view should appear")

        // Unlock
        app.unlockApp(passphrase: Self.testPassphrase)

        // Verify we're on HomeView
        let navTitle = app.navigationBars["Members"]
        XCTAssertTrue(navTitle.exists, "Should be on main app after unlock")
    }

    func testUnlockWithIncorrectPassphrase() throws {
        let appTitle = app.staticTexts["Family Medical App"]
        XCTAssertTrue(appTitle.waitForExistence(timeout: 5))

        // Skip biometric if shown
        let usePassphraseButton = app.buttons["Use Passphrase"]
        if usePassphraseButton.exists {
            usePassphraseButton.tap()
        }

        // Enter WRONG passphrase
        let passphraseField = app.passwordField("Passphrase")
        XCTAssertTrue(passphraseField.waitForExistence(timeout: 2))
        passphraseField.tap()
        passphraseField.typeText("WrongPassphrase123")

        // Tap Sign In
        let signInButton = app.buttons["Sign In"]
        signInButton.tap()

        // Should see failed attempts counter
        let failedAttemptText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'failed attempt'")).firstMatch
        XCTAssertTrue(
            failedAttemptText.waitForExistence(timeout: 2),
            "Failed attempts counter should appear after wrong passphrase"
        )
    }

    func testFailedAttemptsCounterIncreases() throws {
        let appTitle = app.staticTexts["Family Medical App"]
        XCTAssertTrue(appTitle.waitForExistence(timeout: 5))

        // Skip biometric if shown
        let usePassphraseButton = app.buttons["Use Passphrase"]
        if usePassphraseButton.exists {
            usePassphraseButton.tap()
        }

        // First failed attempt
        let passphraseField = app.passwordField("Passphrase")
        XCTAssertTrue(passphraseField.waitForExistence(timeout: 2))
        passphraseField.tap()
        passphraseField.typeText("Wrong1")
        app.buttons["Sign In"].tap()

        // Check counter shows "1 failed attempt"
        let failedAttempt1 = app.staticTexts["1 failed attempt"]
        XCTAssertTrue(failedAttempt1.waitForExistence(timeout: 2), "Should show 1 failed attempt")

        // Clear passphrase field and try again
        passphraseField.tap()
        passphraseField.clearText()
        passphraseField.typeText("Wrong2")
        app.buttons["Sign In"].tap()

        // Check counter shows "2 failed attempts"
        let failedAttempt2 = app.staticTexts["2 failed attempts"]
        XCTAssertTrue(failedAttempt2.waitForExistence(timeout: 2), "Should show 2 failed attempts")
    }

    func testUnlockViewElements() throws {
        // Verify all expected elements exist
        XCTAssertTrue(app.staticTexts["Family Medical App"].waitForExistence(timeout: 5))

        // Either biometric button or passphrase field should exist
        // Use waitForExistence with timeout for CI reliability (elements may load slowly)
        let biometricButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Unlock with'")).firstMatch
        let passphraseField = app.passwordField("Passphrase")

        let hasBiometricButton = biometricButton.waitForExistence(timeout: 2)
        let hasPassphraseField = passphraseField.waitForExistence(timeout: 2)

        XCTAssertTrue(
            hasBiometricButton || hasPassphraseField,
            "Should show either biometric button or passphrase field"
        )
    }

    func testSwitchFromBiometricToPassphrase() throws {
        let appTitle = app.staticTexts["Family Medical App"]
        XCTAssertTrue(appTitle.waitForExistence(timeout: 5))

        // This test only applies when biometric authentication is available
        let usePassphraseButton = app.buttons["Use Passphrase"]
        try XCTSkipUnless(
            usePassphraseButton.waitForExistence(timeout: 2),
            "Test requires biometric to be available (Use Passphrase button must be shown)"
        )

        usePassphraseButton.tap()

        // Passphrase field should now appear
        let passphraseField = app.passwordField("Passphrase")
        XCTAssertTrue(
            passphraseField.waitForExistence(timeout: 2),
            "Passphrase field should appear after tapping 'Use Passphrase'"
        )
    }
}
