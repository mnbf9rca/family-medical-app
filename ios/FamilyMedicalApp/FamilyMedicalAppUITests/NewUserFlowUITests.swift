//
//  NewUserFlowUITests.swift
//  FamilyMedicalAppUITests
//
//  Tests for new user account creation flow with OPAQUE multi-step authentication
//
//  ## Test Organization
//  - Independent tests: `testCompleteNewUserJourney`, `testNewUserWithCustomCredentials`
//    These require fresh app state and test complete account creation flows.
//
//  - Validation test: `testPassphraseSetupValidation`
//    Tests passphrase validation rules (field presence, button states, strength indicator).
//
//  ## Note on XCTest Ordering
//  XCTest does NOT guarantee test execution order. Validation checks are consolidated
//  into single test methods where ordering matters.
//
//  - Note: Ensure hardware keyboard is disabled in simulator:
//    I/O -> Keyboard -> Connect Hardware Keyboard (unchecked)
//    This prevents password autofill prompts from interfering with UI tests

import XCTest

/// Tests for new user account creation flow
@MainActor
final class NewUserFlowUITests: XCTestCase {
    // MARK: - Instance app

    nonisolated(unsafe) var app: XCUIApplication!

    // MARK: - Setup / Teardown

    override func setUpWithError() throws {
        continueAfterFailure = false
        setupPasswordAutofillHandler()
    }

    override func tearDownWithError() throws {
        let appRef = app
        app = nil
        MainActor.assumeIsolated {
            appRef?.terminate()
        }
    }

    // MARK: - Independent Tests (Fresh App Launch Required)

    func testCompleteNewUserJourney() throws {
        // Launch app with fresh state
        app = XCUIApplication()
        app.launchForUITesting(resetState: true)

        // Verify UsernameEntryView appears
        let header = app.staticTexts["Family Medical"]
        XCTAssertTrue(header.waitForExistence(timeout: 5), "Username entry screen should appear for new user")

        // Create account using the helper (goes through all steps)
        app.createAccount()

        // Verify we're on HomeView with empty state
        let emptyStateText = app.staticTexts["No Members"]
        XCTAssertTrue(emptyStateText.waitForExistence(timeout: 5), "Empty state should appear after account creation")

        // Terminate this independent test's app
        app.terminate()
    }

    func testNewUserWithCustomCredentials() throws {
        app = XCUIApplication()
        app.launchForUITesting(resetState: true)

        // Use test_* pattern to trigger OPAQUE bypass in DEBUG builds
        let customUsername = "test_customuser"
        let customPassphrase = "unique-good-pass-1234"

        app.createAccount(username: customUsername, password: customPassphrase)

        // Verify successful creation
        let navTitle = app.navigationBars["Members"]
        XCTAssertTrue(navTitle.exists, "Should be on main app after setup")

        // Terminate this independent test's app
        app.terminate()
    }

    // MARK: - Username Entry Validation Test

    func testUsernameEntryValidation() throws {
        app = XCUIApplication()
        app.launchForUITesting(resetState: true)

        // Wait for welcome screen
        let welcomeHeader = app.staticTexts["Family Medical"]
        XCTAssertTrue(welcomeHeader.waitForExistence(timeout: 5), "Welcome screen should appear")

        // Tap Create Account to go to username entry
        let createAccountButton = app.buttons["Create Account"]
        XCTAssertTrue(createAccountButton.exists, "Create Account button should exist on welcome screen")
        createAccountButton.tap()

        // Wait for username entry view
        let usernameHeader = app.staticTexts["Create Your Account"]
        XCTAssertTrue(usernameHeader.waitForExistence(timeout: 5), "Username entry screen should appear")

        // Verify username field exists
        let usernameField = app.textFields["Username"]
        XCTAssertTrue(usernameField.exists, "Username field should exist")

        // Continue button should be disabled with empty username
        let continueButton = app.buttons["Continue"]
        XCTAssertTrue(continueButton.exists, "Continue button should exist")
        XCTAssertFalse(continueButton.isEnabled, "Continue should be disabled with empty username")

        // Enter short username (less than 3 chars)
        usernameField.tap()
        usernameField.typeText("ab")
        XCTAssertFalse(continueButton.isEnabled, "Continue should be disabled with short username")

        // Add one more character to make it valid
        usernameField.typeText("c")

        // Continue should now be enabled
        XCTAssertTrue(
            continueButton.waitForExistence(timeout: 2) && continueButton.isEnabled,
            "Continue should be enabled with valid username"
        )

        app.terminate()
    }

    // MARK: - Passphrase Setup Validation Test

    func testPassphraseSetupValidation() throws {
        app = XCUIApplication()
        app.launchForUITesting(resetState: true)

        // Start from welcome screen - tap Create Account
        let welcomeHeader = app.staticTexts["Family Medical"]
        XCTAssertTrue(welcomeHeader.waitForExistence(timeout: 5))
        app.buttons["Create Account"].tap()

        // Navigate to passphrase creation (through username entry)
        let usernameField = app.textFields["Username"]
        XCTAssertTrue(usernameField.waitForExistence(timeout: 5))
        usernameField.tap()
        usernameField.typeText("testuser")

        let usernameContinueButton = app.buttons["Continue"]
        XCTAssertTrue(usernameContinueButton.waitForExistence(timeout: 2) && usernameContinueButton.isEnabled)
        usernameContinueButton.tap()

        // Wait for passphrase creation view
        let passphraseHeader = app.staticTexts["Create a Passphrase"]
        XCTAssertTrue(passphraseHeader.waitForExistence(timeout: 5), "Passphrase creation should appear")

        // Verify passphrase field exists
        let passphraseField = app.passwordField("Passphrase")
        XCTAssertTrue(passphraseField.exists, "Passphrase field should exist")

        // Continue button should be disabled with empty passphrase
        let continueButton = app.buttons["Continue"]
        XCTAssertFalse(continueButton.isEnabled, "Continue should be disabled with empty passphrase")

        // Enter weak passphrase - should show strength indicator
        passphraseField.tap()
        passphraseField.typeText("weak")

        let weakText = app.staticTexts["Weak"]
        XCTAssertTrue(
            weakText.waitForExistence(timeout: 2),
            "Strength indicator showing 'Weak' should appear for weak passphrase"
        )

        // Continue should still be disabled for weak passphrase
        XCTAssertFalse(continueButton.isEnabled, "Continue should be disabled with weak passphrase")

        // Clear and enter strong passphrase
        passphraseField.tap()
        let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: "weak".count)
        passphraseField.typeText(deleteString)
        passphraseField.typeText("Unique-Horse-Battery-Staple-2024")

        let strongText = app.staticTexts["Strong"]
        XCTAssertTrue(
            strongText.waitForExistence(timeout: 2),
            "Strength indicator showing 'Strong' should appear for strong passphrase"
        )

        // Continue should now be enabled
        XCTAssertTrue(
            continueButton.waitForExistence(timeout: 2) && continueButton.isEnabled,
            "Continue should be enabled with strong passphrase"
        )

        app.terminate()
    }

    // MARK: - Passphrase Confirmation Validation Test

    func testPassphraseConfirmationValidation() throws {
        app = XCUIApplication()
        app.launchForUITesting(resetState: true)

        let passphrase = "Unique-Horse-Battery-Staple-2024"

        // Start from welcome screen - tap Create Account
        let welcomeHeader = app.staticTexts["Family Medical"]
        XCTAssertTrue(welcomeHeader.waitForExistence(timeout: 5))
        app.buttons["Create Account"].tap()

        // Navigate through username entry
        let usernameField = app.textFields["Username"]
        XCTAssertTrue(usernameField.waitForExistence(timeout: 5))
        usernameField.tap()
        usernameField.typeText("testuser")
        app.buttons["Continue"].tap()

        // Navigate through passphrase creation
        let passphraseHeader = app.staticTexts["Create a Passphrase"]
        XCTAssertTrue(passphraseHeader.waitForExistence(timeout: 5))
        let passphraseField = app.passwordField("Passphrase")
        passphraseField.tap()
        passphraseField.typeText(passphrase)
        app.buttons["Continue"].tap()

        // Now on passphrase confirmation
        let confirmHeader = app.staticTexts["Confirm Passphrase"]
        XCTAssertTrue(confirmHeader.waitForExistence(timeout: 5), "Passphrase confirmation should appear")

        let confirmField = app.passwordField("Confirm passphrase")
        XCTAssertTrue(confirmField.exists, "Confirm passphrase field should exist")

        // Continue button should be disabled with empty confirmation
        let continueButton = app.buttons["Continue"]
        XCTAssertFalse(continueButton.isEnabled, "Continue should be disabled with empty confirmation")

        // Enter matching passphrase directly
        confirmField.tap()
        confirmField.typeText(passphrase)

        // Match indicator should appear
        let matchText = app.staticTexts["Passphrases match"]
        XCTAssertTrue(matchText.waitForExistence(timeout: 5), "Match indicator should appear")

        // Continue should now be enabled
        XCTAssertTrue(
            continueButton.waitForExistence(timeout: 2) && continueButton.isEnabled,
            "Continue should be enabled with matching passphrase"
        )

        app.terminate()
    }
}
