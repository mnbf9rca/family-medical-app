//
//  NewUserFlowUITests.swift
//  FamilyMedicalAppUITests
//
//  Tests for new user account creation flow with multi-step authentication
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
        app?.terminate()
        app = nil
    }

    // MARK: - Independent Tests (Fresh App Launch Required)

    func testCompleteNewUserJourney() throws {
        // Launch app with fresh state
        app = XCUIApplication()
        app.launchForUITesting(resetState: true)

        // Verify EmailEntryView appears
        let header = app.staticTexts["Family Medical"]
        XCTAssertTrue(header.waitForExistence(timeout: 5), "Email entry screen should appear for new user")

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

        let customEmail = "custom@test.example.com"
        let customPassphrase = "unique-good-pass-1234"

        app.createAccount(email: customEmail, password: customPassphrase)

        // Verify successful creation
        let navTitle = app.navigationBars["Members"]
        XCTAssertTrue(navTitle.exists, "Should be on main app after setup")

        // Terminate this independent test's app
        app.terminate()
    }

    // MARK: - Email Entry Validation Test

    func testEmailEntryValidation() throws {
        app = XCUIApplication()
        app.launchForUITesting(resetState: true)

        // Wait for email entry view
        let headerText = app.staticTexts["Family Medical"]
        XCTAssertTrue(headerText.waitForExistence(timeout: 5), "Email entry screen should appear")

        // Verify email field exists
        let emailField = app.textFields["Email address"]
        XCTAssertTrue(emailField.exists, "Email field should exist")

        // Continue button should be disabled with empty email
        let continueButton = app.buttons["Continue"]
        XCTAssertTrue(continueButton.exists, "Continue button should exist")
        XCTAssertFalse(continueButton.isEnabled, "Continue should be disabled with empty email")

        // Enter invalid email
        emailField.tap()
        emailField.typeText("invalid-email")
        XCTAssertFalse(continueButton.isEnabled, "Continue should be disabled with invalid email")

        // Clear and enter valid email
        emailField.tap()
        let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: "invalid-email".count)
        emailField.typeText(deleteString)
        emailField.typeText("test@example.com")

        // Continue should now be enabled
        XCTAssertTrue(
            continueButton.waitForExistence(timeout: 2) && continueButton.isEnabled,
            "Continue should be enabled with valid email"
        )

        app.terminate()
    }

    // MARK: - Passphrase Setup Validation Test

    func testPassphraseSetupValidation() throws {
        app = XCUIApplication()
        app.launchForUITesting(resetState: true)

        // Navigate to passphrase creation (through email entry)
        let emailField = app.textFields["Email address"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 5))
        emailField.tap()
        emailField.typeText("test@example.com")

        let emailContinueButton = app.buttons["Continue"]
        XCTAssertTrue(emailContinueButton.waitForExistence(timeout: 2) && emailContinueButton.isEnabled)
        emailContinueButton.tap()

        // Skip code verification (auto-bypassed for test email)
        let codeHeader = app.staticTexts["Check your email"]
        if codeHeader.waitForExistence(timeout: 3) {
            let codeField = app.textFields["codeField"]
            if codeField.exists {
                codeField.tap()
                codeField.typeText("123456")
            }
            let verifyButton = app.buttons["verifyButton"]
            if verifyButton.exists && verifyButton.isEnabled {
                verifyButton.tap()
            }
        }

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

        // Navigate through email entry
        let emailField = app.textFields["Email address"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 5))
        emailField.tap()
        emailField.typeText("test@example.com")
        app.buttons["Continue"].tap()

        // Skip code verification
        let codeHeader = app.staticTexts["Check your email"]
        if codeHeader.waitForExistence(timeout: 3) {
            let codeField = app.textFields["codeField"]
            if codeField.exists {
                codeField.tap()
                codeField.typeText("123456")
            }
            let verifyButton = app.buttons["verifyButton"]
            if verifyButton.exists && verifyButton.isEnabled {
                verifyButton.tap()
            }
        }

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
