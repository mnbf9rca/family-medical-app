//
//  UITestHelpers.swift
//  FamilyMedicalAppUITests
//
//  Created by rob on 29/12/2025.
//

import XCTest

/// Helper functions for UI testing with SwiftUI Toggles
extension XCTestCase {
    /// Sets up an interruption monitor to dismiss password autofill prompts.
    /// Call this in `setUpWithError()` to handle iOS password autofill system alerts.
    ///
    /// Example:
    /// ```swift
    /// override func setUpWithError() throws {
    ///     continueAfterFailure = false
    ///     setupPasswordAutofillHandler()
    /// }
    /// ```
    func setupPasswordAutofillHandler() {
        addUIInterruptionMonitor(withDescription: "Password Autofill") { alert in
            MainActor.assumeIsolated {
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

    /// Turn a SwiftUI Toggle on
    /// - Parameter toggle: The toggle element to turn on
    /// - Note: SwiftUI Toggle tap() doesn't work - must tap inner switch coordinate
    @MainActor
    func turnSwitchOn(_ toggle: XCUIElement) {
        // Find the inner UISwitch descendant
        let innerSwitch = toggle.descendants(matching: .switch).firstMatch
        let center = innerSwitch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))

        // Required: tap toggle first, otherwise inner switch tap is ignored
        toggle.tap()
        center.tap()

        // Wait for state to update
        let expectation = expectation(for: NSPredicate(format: "value == '1'"), evaluatedWith: toggle)
        wait(for: [expectation], timeout: 2)
    }

    /// Turn a SwiftUI Toggle off
    /// - Parameter toggle: The toggle element to turn off
    @MainActor
    func turnSwitchOff(_ toggle: XCUIElement) {
        let innerSwitch = toggle.descendants(matching: .switch).firstMatch
        let center = innerSwitch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))

        toggle.tap()
        center.tap()

        let expectation = expectation(for: NSPredicate(format: "value == '0'"), evaluatedWith: toggle)
        wait(for: [expectation], timeout: 2)
    }
}

/// Helper functions for UI testing
extension XCUIApplication {
    /// Get password field (TextField in UI testing mode, SecureField in production)
    /// - Parameter label: The accessibility label of the field
    /// - Returns: The password field element
    func passwordField(_ label: String) -> XCUIElement {
        // In UI testing mode, password fields are TextFields to avoid autofill issues
        // In production, they're SecureFields for proper security
        return textFields[label].exists ? textFields[label] : secureTextFields[label]
    }

    /// Launch app with UI testing flags
    /// - Parameters:
    ///   - resetState: If true, clears all app data (keychain + Core Data)
    ///   - seedTestAttachments: If true, automatically creates test attachments for coverage
    /// - Note: For best results, ensure hardware keyboard is disabled in the simulator:
    ///   I/O → Keyboard → Connect Hardware Keyboard (should be unchecked)
    func launchForUITesting(resetState: Bool = false, seedTestAttachments: Bool = false) {
        launchArguments = ["--uitesting"]

        if resetState {
            launchArguments.append("--reset-state")
        }

        if seedTestAttachments {
            launchArguments.append("--seed-test-attachments")
        }

        launch()
    }

    /// Create a new user account through the multi-step setup flow
    /// - Parameters:
    ///   - username: Username for the account (default: "testuser")
    ///   - passphrase: Passphrase to use (default: "Unique-Horse-Battery-Staple-2024")
    ///   - enableBiometric: Whether to enable biometric auth (default: false for testing)
    ///   - timeout: Max wait time for UI elements and account creation (default: 15s for encryption operations)
    func createAccount(
        username: String = "testuser",
        password passphrase: String = "Unique-Horse-Battery-Staple-2024",
        enableBiometric: Bool = false,
        timeout: TimeInterval = 15
    ) {
        // Step 0: Welcome Screen - tap "Create Account"
        let welcomeHeader = staticTexts["Family Medical"]
        XCTAssertTrue(welcomeHeader.waitForExistence(timeout: timeout), "Welcome view should appear")

        let createAccountButton = buttons["Create Account"]
        XCTAssertTrue(createAccountButton.waitForExistence(timeout: timeout), "Create Account button should exist")
        createAccountButton.tap()

        // Step 1: Username Entry
        let usernameHeader = staticTexts["Create Your Account"]
        XCTAssertTrue(usernameHeader.waitForExistence(timeout: timeout), "Username entry view should appear")

        let usernameField = textFields["Username"]
        XCTAssertTrue(usernameField.waitForExistence(timeout: timeout), "Username field should exist")
        usernameField.tap()
        usernameField.typeText(username)

        let continueButton = buttons["Continue"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 2) && continueButton.isEnabled)
        continueButton.tap()

        // Step 2: Passphrase Creation (no more code verification with OPAQUE)
        let passphraseHeader = staticTexts["Create a Passphrase"]
        XCTAssertTrue(passphraseHeader.waitForExistence(timeout: timeout), "Passphrase creation should appear")

        let passphraseField = passwordField("Passphrase")
        XCTAssertTrue(passphraseField.waitForExistence(timeout: timeout))
        passphraseField.tap()
        passphraseField.typeText(passphrase)

        let passphraseContinueButton = buttons["Continue"]
        XCTAssertTrue(passphraseContinueButton.waitForExistence(timeout: 2) && passphraseContinueButton.isEnabled)
        passphraseContinueButton.tap()

        // Step 3: Passphrase Confirmation
        let confirmHeader = staticTexts["Confirm Passphrase"]
        XCTAssertTrue(confirmHeader.waitForExistence(timeout: timeout), "Passphrase confirmation should appear")

        let confirmField = passwordField("Confirm passphrase")
        XCTAssertTrue(confirmField.waitForExistence(timeout: timeout))
        confirmField.tap()
        confirmField.typeText(passphrase)

        let confirmContinueButton = buttons["Continue"]
        XCTAssertTrue(confirmContinueButton.waitForExistence(timeout: 2) && confirmContinueButton.isEnabled)
        confirmContinueButton.tap()

        // Step 4: Biometric Setup
        let biometricHeader = staticTexts.matching(NSPredicate(format: "label CONTAINS 'Enable'")).firstMatch
        XCTAssertTrue(biometricHeader.waitForExistence(timeout: timeout), "Biometric setup should appear")

        if enableBiometric {
            let enableButton = buttons["enableBiometricButton"]
            if enableButton.exists && enableButton.isEnabled {
                enableButton.tap()
            }
        } else {
            let skipButton = buttons["Skip for now"]
            XCTAssertTrue(skipButton.exists)
            skipButton.tap()
        }

        // Wait for HomeView to appear
        let navTitle = navigationBars["Members"]
        XCTAssertTrue(navTitle.waitForExistence(timeout: timeout), "Should navigate to main app")
    }

    /// Unlock app with passphrase (for returning user)
    /// - Parameters:
    ///   - passphrase: Passphrase to use (default: "Unique-Horse-Battery-Staple-2024")
    ///   - timeout: Max wait time for UI elements
    func unlockApp(passphrase: String = "Unique-Horse-Battery-Staple-2024", timeout: TimeInterval = 5) {
        // Wait for UnlockView to appear
        let appTitle = staticTexts["Family Medical App"]
        XCTAssertTrue(appTitle.waitForExistence(timeout: timeout), "Unlock view should appear")

        // Check if biometric button is shown (might auto-show)
        let usePassphraseButton = buttons["Use Passphrase"]
        if usePassphraseButton.exists {
            usePassphraseButton.tap()
        }

        // Enter passphrase
        let passphraseField = passwordField("Passphrase")
        XCTAssertTrue(passphraseField.waitForExistence(timeout: timeout))
        passphraseField.tap()
        passphraseField.typeText(passphrase)

        // Tap Sign In button
        let signInButton = buttons["Sign In"]
        XCTAssertTrue(signInButton.exists)
        XCTAssertTrue(signInButton.isEnabled, "Sign In button should be enabled")
        signInButton.tap()

        // Wait for HomeView to appear
        let navTitle = navigationBars["Members"]
        XCTAssertTrue(navTitle.waitForExistence(timeout: timeout), "Should navigate to main app")
    }

    /// Add a person through the Add Member flow
    /// - Parameters:
    ///   - name: Person's name
    ///   - dateOfBirth: Optional date of birth
    ///   - notes: Optional notes
    ///   - timeout: Max wait time for UI elements
    func addPerson(
        name: String,
        dateOfBirth: Date? = nil,
        notes: String? = nil,
        timeout: TimeInterval = 5
    ) {
        // Tap Add Member button in toolbar (use unique identifier to avoid empty state button)
        let addButton = buttons["toolbarAddMember"]
        XCTAssertTrue(addButton.waitForExistence(timeout: timeout))
        addButton.tap()

        // Wait for sheet to appear
        let navTitle = navigationBars["Add Member"]
        XCTAssertTrue(navTitle.waitForExistence(timeout: timeout), "Add person sheet should appear")

        // Fill in name
        let nameField = textFields["Name"]
        XCTAssertTrue(nameField.exists)
        nameField.tap()
        nameField.typeText(name)

        // Handle date of birth if provided
        if dateOfBirth != nil {
            let dobToggle = switches["includeDateOfBirthToggle"]
            XCTAssertTrue(dobToggle.exists)

            // Turn on toggle using proper SwiftUI Toggle interaction
            // Note: Cannot use turnSwitchOn() helper here (XCUIApplication vs XCTestCase)
            let innerSwitch = dobToggle.descendants(matching: .switch).firstMatch
            let center = innerSwitch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            dobToggle.tap()
            center.tap()

            // Note: Setting DatePicker value in UI tests is complex
            // Compact picker identified by accessibility identifier - just verify it exists
            let datePicker = descendants(matching: .any)["dateOfBirthPicker"]
            XCTAssertTrue(datePicker.waitForExistence(timeout: 1), "Date picker should appear when toggle is on")
        }

        // Fill in notes if provided
        if let notes {
            let notesField = textFields["Notes (optional)"].firstMatch
            if notesField.exists {
                notesField.tap()
                notesField.typeText(notes)
            }
        }

        // Tap Save button
        let saveButton = buttons["Save"]
        XCTAssertTrue(saveButton.exists)
        XCTAssertTrue(saveButton.isEnabled, "Save button should be enabled with valid name")
        saveButton.tap()

        // Wait for sheet to dismiss (person should appear in list)
        XCTAssertTrue(navTitle.waitForNonExistence(timeout: 3), "Sheet should dismiss after save")
    }

    /// Verify a person appears in the home list
    /// - Parameters:
    ///   - name: Person's name to look for
    ///   - timeout: Max wait time
    /// - Returns: true if person found, false otherwise
    @discardableResult
    func verifyPersonExists(name: String, timeout: TimeInterval = 3) -> Bool {
        let personCell = cells.containing(.staticText, identifier: name).firstMatch
        return personCell.waitForExistence(timeout: timeout)
    }

    /// Dismiss current modal/sheet/popover using multiple fallback strategies
    /// Use this instead of conditional `if button.exists { button.tap() }` patterns
    /// to ensure cleanup code always executes
    func dismissCurrentView() {
        // Strategy 1: Cancel button (most common for sheets/forms)
        let cancelButton = buttons["Cancel"]
        if cancelButton.waitForExistence(timeout: 1) {
            cancelButton.tap()
            return
        }

        // Strategy 2: Close button (for viewers/modals)
        let closeButton = buttons["Close"]
        if closeButton.waitForExistence(timeout: 0.5) {
            closeButton.tap()
            return
        }

        // Strategy 3: Done button (for some modal presentations)
        let doneButton = buttons["Done"]
        if doneButton.waitForExistence(timeout: 0.5) {
            doneButton.tap()
            return
        }

        // Strategy 4: Swipe down (for sheet presentations)
        swipeDown()

        // Strategy 5: Tap outside (for popovers/menus)
        coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1)).tap()
    }
}

// MARK: - XCUIElement Extension for text clearing

extension XCUIElement {
    /// Clear text from a text field
    func clearText() {
        guard let stringValue = self.value as? String, !stringValue.isEmpty else {
            return
        }

        // Tap the field to focus
        self.tap()

        // Delete each character
        let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: stringValue.count)
        self.typeText(deleteString)
    }
}
