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
//  - Chained validation tests: `test1_...` through `test5_...`
//    These share a single app launch to reduce overhead (~60% faster).
//    They only READ UI state (checking button enabled/disabled, text visibility).
//    Each test clears form fields before starting to ensure clean state.
//
//  ## Tradeoffs
//  Test chaining trades isolation for speed. If test1 fails to launch properly,
//  subsequent chained tests will also fail. This is acceptable for validation
//  tests that don't modify persistent state.
//
//  - Note: Ensure hardware keyboard is disabled in simulator:
//    I/O -> Keyboard -> Connect Hardware Keyboard (unchecked)
//    This prevents password autofill prompts from interfering with UI tests

import XCTest

/// Tests for new user account creation flow
@MainActor
final class NewUserFlowUITests: XCTestCase {
    // MARK: - Shared State for Test Chaining

    /// Shared app instance for chained validation tests
    nonisolated(unsafe) static var sharedApp: XCUIApplication!

    /// Instance accessor for convenience
    private var chainedApp: XCUIApplication { Self.sharedApp }

    /// Track if chained tests have been initialized
    nonisolated(unsafe) static var chainedTestsInitialized = false

    // MARK: - Instance app for independent tests

    nonisolated(unsafe) var app: XCUIApplication!

    // MARK: - Setup / Teardown

    nonisolated override func setUpWithError() throws {
        continueAfterFailure = false

        // Add UI interruption monitor to handle password autofill prompts
        addUIInterruptionMonitor(withDescription: "Password Autofill") { alert in
            return MainActor.assumeIsolated {
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
    }

    nonisolated override func tearDownWithError() throws {
        app = nil
    }

    nonisolated override class func tearDown() {
        MainActor.assumeIsolated {
            sharedApp?.terminate()
            sharedApp = nil
            chainedTestsInitialized = false
        }
        super.tearDown()
    }

    // MARK: - Helper Methods

    /// Initialize the shared app for chained tests (called once by first chained test)
    private func ensureChainedAppLaunched() {
        if !Self.chainedTestsInitialized {
            Self.sharedApp = XCUIApplication()
            Self.sharedApp.launchForUITesting(resetState: true)

            // Wait for setup view
            let headerText = Self.sharedApp.staticTexts["Secure Your Medical Records"]
            XCTAssertTrue(headerText.waitForExistence(timeout: 5), "Setup screen should appear")

            Self.chainedTestsInitialized = true
        }
    }

    /// Clear all form fields to reset state between chained tests
    private func clearFormFields() {
        // Clear username field
        let usernameField = chainedApp.textFields["Choose a username"]
        if usernameField.exists {
            usernameField.tap()
            if let text = usernameField.value as? String, !text.isEmpty, text != "Choose a username" {
                let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: text.count)
                usernameField.typeText(deleteString)
            }
        }

        // Clear password field
        let passwordField = chainedApp.passwordField("Enter password")
        if passwordField.exists {
            passwordField.tap()
            if let text = passwordField.value as? String, !text.isEmpty, text != "Enter password" {
                let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: text.count)
                passwordField.typeText(deleteString)
            }
        }

        // Clear confirm password field
        let confirmPasswordField = chainedApp.passwordField("Confirm password")
        if confirmPasswordField.exists {
            confirmPasswordField.tap()
            if let text = confirmPasswordField.value as? String, !text.isEmpty, text != "Confirm password" {
                let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: text.count)
                confirmPasswordField.typeText(deleteString)
            }
        }

        // Tap header to dismiss keyboard
        let header = chainedApp.staticTexts["Secure Your Medical Records"]
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

    // MARK: - Chained Validation Tests (Shared App Instance)
    //
    // These tests share a single app launch. They only read UI state and
    // clear form fields between tests. Numbered for execution order.

    func test1_AllRequiredFieldsAppear() throws {
        ensureChainedAppLaunched()

        // Verify all fields exist
        XCTAssertTrue(chainedApp.textFields["Choose a username"].exists, "Username field should exist")
        XCTAssertTrue(chainedApp.passwordField("Enter password").exists, "Password field should exist")
        XCTAssertTrue(chainedApp.passwordField("Confirm password").exists, "Confirm password field should exist")
        XCTAssertTrue(chainedApp.buttons["Continue"].exists, "Continue button should exist")
    }

    func test2_EmptyFieldsDisableContinueButton() throws {
        ensureChainedAppLaunched()
        clearFormFields()

        // Continue button should be disabled with empty fields
        let continueButton = chainedApp.buttons["Continue"]
        XCTAssertFalse(continueButton.isEnabled, "Continue should be disabled with empty fields")
    }

    func test3_PartiallyFilledFieldsDisableContinueButton() throws {
        ensureChainedAppLaunched()
        clearFormFields()

        // Only fill username
        let usernameField = chainedApp.textFields["Choose a username"]
        usernameField.tap()
        usernameField.typeText("testuser")

        // Continue button should still be disabled
        let continueButton = chainedApp.buttons["Continue"]
        XCTAssertFalse(continueButton.isEnabled, "Continue should be disabled with only username")
    }

    func test4_WeakPasswordShowsStrengthIndicator() throws {
        ensureChainedAppLaunched()
        clearFormFields()

        // Enter username
        let usernameField = chainedApp.textFields["Choose a username"]
        usernameField.tap()
        usernameField.typeText("testuser")

        // Enter weak password (too short, less than 12 chars)
        let passwordField = chainedApp.passwordField("Enter password")
        passwordField.tap()
        passwordField.typeText("weak")

        // Verify strength indicator appears (check for "Weak" text)
        let weakText = chainedApp.staticTexts["Weak"]
        XCTAssertTrue(weakText.waitForExistence(timeout: 2), "Strength indicator showing 'Weak' should appear for weak password")
    }

    func test5_MismatchedPasswordsShowError() throws {
        ensureChainedAppLaunched()
        clearFormFields()

        // Fill in fields with mismatched passwords
        let usernameField = chainedApp.textFields["Choose a username"]
        usernameField.tap()
        usernameField.typeText("testuser")

        let passwordField = chainedApp.passwordField("Enter password")
        passwordField.tap()
        passwordField.typeText("unique-horse-battery-staple-2024")

        let confirmPasswordField = chainedApp.passwordField("Confirm password")
        confirmPasswordField.tap()
        confirmPasswordField.typeText("unique-good-pass-1234")

        // Continue button should be disabled
        let continueButton = chainedApp.buttons["Continue"]
        XCTAssertFalse(continueButton.isEnabled, "Continue should be disabled with mismatched passwords")
    }
}
