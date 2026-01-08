//
//  NewUserFlowUITests.swift
//  FamilyMedicalAppUITests
//
//  Tests for new user account creation flow including password validation
//
//  ## Test Organization
//  - Independent tests: `testCompleteNewUserJourney`, `testNewUserWithCustomCredentials`
//    These require fresh app state and test complete account creation flows.
//
//  - Validation test: `testPasswordSetupValidation`
//    Tests all password validation rules in a single method (field presence,
//    button states, strength indicator, password matching).
//
//  ## Note on XCTest Ordering
//  XCTest does NOT guarantee test execution order. Previously, tests were named
//  `test1_`, `test2_`, etc. to imply ordering, but this is not reliable.
//  Validation checks are now consolidated into a single test method.
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

    // MARK: - Helper Methods

    /// Clear all form fields to reset state
    private func clearFormFields() {
        // Clear username field
        let usernameField = app.textFields["Choose a username"]
        if usernameField.exists {
            usernameField.tap()
            if let text = usernameField.value as? String, !text.isEmpty, text != "Choose a username" {
                let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: text.count)
                usernameField.typeText(deleteString)
            }
        }

        // Clear password field
        let passwordField = app.passwordField("Enter password")
        if passwordField.exists {
            passwordField.tap()
            if let text = passwordField.value as? String, !text.isEmpty, text != "Enter password" {
                let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: text.count)
                passwordField.typeText(deleteString)
            }
        }

        // Clear confirm password field
        let confirmPasswordField = app.passwordField("Confirm password")
        if confirmPasswordField.exists {
            confirmPasswordField.tap()
            if let text = confirmPasswordField.value as? String, !text.isEmpty, text != "Confirm password" {
                let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: text.count)
                confirmPasswordField.typeText(deleteString)
            }
        }

        // Tap header to dismiss keyboard
        let header = app.staticTexts["Secure Your Medical Records"]
        if header.exists {
            header.tap()
        }
    }

    // MARK: - Independent Tests (Fresh App Launch Required)

    func testCompleteNewUserJourney() throws {
        // Launch app with fresh state
        app = XCUIApplication()
        app.launchForUITesting(resetState: true)

        // Verify PasswordSetupView appears
        let header = app.staticTexts["Secure Your Medical Records"]
        XCTAssertTrue(header.exists, "Setup screen should appear for new user")

        // Create account
        app.createAccount()

        // Verify we're on HomeView with empty state
        let emptyStateText = app.staticTexts["No Members"]
        XCTAssertTrue(emptyStateText.exists, "Empty state should appear after account creation")

        // Terminate this independent test's app
        app.terminate()
    }

    func testNewUserWithCustomCredentials() throws {
        app = XCUIApplication()
        app.launchForUITesting(resetState: true)

        let customUsername = "myusername"
        let customPassword = "unique-good-pass-1234"

        app.createAccount(username: customUsername, password: customPassword)

        // Verify successful creation
        let navTitle = app.navigationBars["Members"]
        XCTAssertTrue(navTitle.exists, "Should be on main app after setup")

        // Terminate this independent test's app
        app.terminate()
    }

    // MARK: - Password Setup Validation Test
    //
    // This test consolidates all password validation checks into a single method.
    // XCTest does NOT guarantee test ordering, so chained tests with `test1_`, `test2_`
    // prefixes are unreliable. This single method tests all validation rules sequentially.

    func testPasswordSetupValidation() throws {
        // Launch app with fresh state
        app = XCUIApplication()
        app.launchForUITesting(resetState: true)

        // Wait for setup view
        let headerText = app.staticTexts["Secure Your Medical Records"]
        XCTAssertTrue(headerText.waitForExistence(timeout: 5), "Setup screen should appear")

        // --- Step 1: Verify all required fields appear ---
        XCTAssertTrue(app.textFields["Choose a username"].exists, "Username field should exist")
        XCTAssertTrue(app.passwordField("Enter password").exists, "Password field should exist")
        XCTAssertTrue(app.passwordField("Confirm password").exists, "Confirm password field should exist")
        XCTAssertTrue(app.buttons["Continue"].exists, "Continue button should exist")

        // --- Step 2: Empty fields should disable continue button ---
        let continueButton = app.buttons["Continue"]
        XCTAssertFalse(continueButton.isEnabled, "Continue should be disabled with empty fields")

        // --- Step 3: Partially filled fields should disable continue button ---
        let usernameField = app.textFields["Choose a username"]
        usernameField.tap()
        usernameField.typeText("testuser")
        XCTAssertFalse(continueButton.isEnabled, "Continue should be disabled with only username")

        // --- Step 4: Weak password should show strength indicator ---
        let passwordField = app.passwordField("Enter password")
        passwordField.tap()
        passwordField.typeText("weak")

        let weakText = app.staticTexts["Weak"]
        XCTAssertTrue(weakText.waitForExistence(timeout: 2), "Strength indicator showing 'Weak' should appear for weak password")

        // Clear fields for next test
        clearFormFields()

        // --- Step 5: Mismatched passwords should disable continue button ---
        usernameField.tap()
        usernameField.typeText("testuser")

        passwordField.tap()
        passwordField.typeText("unique-horse-battery-staple-2024")

        let confirmPasswordField = app.passwordField("Confirm password")
        confirmPasswordField.tap()
        confirmPasswordField.typeText("unique-good-pass-1234")

        XCTAssertFalse(continueButton.isEnabled, "Continue should be disabled with mismatched passwords")
    }
}
