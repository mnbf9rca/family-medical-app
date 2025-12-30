//
//  NewUserFlowUITests.swift
//  FamilyMedicalAppUITests
//
//  Created by rob on 29/12/2025.
//

import XCTest

/// Tests for new user account creation flow
/// - Note: Ensure hardware keyboard is disabled in simulator: I/O → Keyboard → Connect Hardware Keyboard (unchecked)
///   This prevents password autofill prompts from interfering with UI tests
final class NewUserFlowUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()

        // Add UI interruption monitor to handle password autofill prompts
        // Note: Not 100% reliable, but provides additional layer of defense
        addUIInterruptionMonitor(withDescription: "Password Autofill") { alert in
            // Try to dismiss common autofill prompt buttons
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

    // MARK: - Complete Journey Tests

    @MainActor
    func testCompleteNewUserJourney() throws {
        // Launch app with fresh state
        app.launchForUITesting(resetState: true)

        // Verify PasswordSetupView appears
        let header = app.staticTexts["Secure Your Medical Records"]
        XCTAssertTrue(header.exists, "Setup screen should appear for new user")

        // Create account
        app.createAccount()

        // Verify we're on HomeView with empty state
        let emptyStateText = app.staticTexts["No Members Yet"]
        XCTAssertTrue(emptyStateText.exists, "Empty state should appear after account creation")
    }

    @MainActor
    func testNewUserWithCustomCredentials() throws {
        app.launchForUITesting(resetState: true)

        let customUsername = "myusername"
        let customPassword = "unique-good-pass-1234"

        app.createAccount(username: customUsername, password: customPassword)

        // Verify successful creation
        let navTitle = app.navigationBars["Members"]
        XCTAssertTrue(navTitle.exists, "Should be on main app after setup")
    }

    // MARK: - Password Validation Tests

    @MainActor
    func testWeakPasswordShowsStrengthIndicator() throws {
        app.launchForUITesting(resetState: true)

        // Wait for setup view
        let headerText = app.staticTexts["Secure Your Medical Records"]
        XCTAssertTrue(headerText.waitForExistence(timeout: 5))

        // Enter username
        let usernameField = app.textFields["Choose a username"]
        usernameField.tap()
        usernameField.typeText("testuser")

        // Enter weak password (too short, less than 12 chars)
        let passwordField = app.passwordField("Enter password")
        passwordField.tap()
        passwordField.typeText("weak")

        // Verify strength indicator appears (check for "Weak" text)
        let weakText = app.staticTexts["Weak"]
        XCTAssertTrue(weakText.waitForExistence(timeout: 2), "Strength indicator showing 'Weak' should appear for weak password")
    }

    @MainActor
    func testMismatchedPasswordsShowError() throws {
        app.launchForUITesting(resetState: true)

        let headerText = app.staticTexts["Secure Your Medical Records"]
        XCTAssertTrue(headerText.waitForExistence(timeout: 5))

        // Fill in fields with mismatched passwords
        let usernameField = app.textFields["Choose a username"]
        usernameField.tap()
        usernameField.typeText("testuser")

        let passwordField = app.passwordField("Enter password")
        passwordField.tap()
        passwordField.typeText("unique-horse-battery-staple-2024")

        let confirmPasswordField = app.passwordField("Confirm password")
        confirmPasswordField.tap()
        confirmPasswordField.typeText("unique-good-pass-1234")

        // Continue button should be disabled
        let continueButton = app.buttons["Continue"]
        XCTAssertFalse(continueButton.isEnabled, "Continue should be disabled with mismatched passwords")
    }

    @MainActor
    func testEmptyFieldsDisableContinueButton() throws {
        app.launchForUITesting(resetState: true)

        let headerText = app.staticTexts["Secure Your Medical Records"]
        XCTAssertTrue(headerText.waitForExistence(timeout: 5))

        // Continue button should be disabled initially
        let continueButton = app.buttons["Continue"]
        XCTAssertFalse(continueButton.isEnabled, "Continue should be disabled with empty fields")
    }

    @MainActor
    func testPartiallyFilledFieldsDisableContinueButton() throws {
        app.launchForUITesting(resetState: true)

        let headerText = app.staticTexts["Secure Your Medical Records"]
        XCTAssertTrue(headerText.waitForExistence(timeout: 5))

        // Only fill username
        let usernameField = app.textFields["Choose a username"]
        usernameField.tap()
        usernameField.typeText("testuser")

        // Continue button should still be disabled
        let continueButton = app.buttons["Continue"]
        XCTAssertFalse(continueButton.isEnabled, "Continue should be disabled with only username")
    }

    // MARK: - UI Element Tests

    @MainActor
    func testAllRequiredFieldsAppear() throws {
        app.launchForUITesting(resetState: true)

        let headerText = app.staticTexts["Secure Your Medical Records"]
        XCTAssertTrue(headerText.waitForExistence(timeout: 5))

        // Verify all fields exist
        XCTAssertTrue(app.textFields["Choose a username"].exists, "Username field should exist")
        XCTAssertTrue(app.passwordField("Enter password").exists, "Password field should exist")
        XCTAssertTrue(app.passwordField("Confirm password").exists, "Confirm password field should exist")
        XCTAssertTrue(app.buttons["Continue"].exists, "Continue button should exist")
    }
}
