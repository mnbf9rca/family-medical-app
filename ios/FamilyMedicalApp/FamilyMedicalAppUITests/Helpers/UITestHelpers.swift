//
//  UITestHelpers.swift
//  FamilyMedicalAppUITests
//
//  Created by rob on 29/12/2025.
//

import XCTest

/// Helper functions for UI testing with SwiftUI Toggles
extension XCTestCase {
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

    /// Create a new user account through the setup flow
    /// - Parameters:
    ///   - username: Username to create (default: "testuser")
    ///   - password: Password to use (default: "unique-horse-battery-staple-2024")
    ///   - timeout: Max wait time for UI elements and account creation (default: 15s for encryption operations)
    /// - Note: Password autofill prompts may appear. Ensure hardware keyboard is disabled in simulator.
    func createAccount(
        username: String = "testuser",
        password: String = "unique-horse-battery-staple-2024",
        timeout: TimeInterval = 15
    ) {
        // Wait for PasswordSetupView to appear
        let headerText = staticTexts["Secure Your Medical Records"]
        XCTAssertTrue(headerText.waitForExistence(timeout: timeout), "Setup view should appear")

        // Fill in username
        let usernameField = textFields["Choose a username"]
        XCTAssertTrue(usernameField.waitForExistence(timeout: timeout))
        usernameField.tap()
        usernameField.typeText(username)

        // Fill in password
        let pwdField = passwordField("Enter password")
        XCTAssertTrue(pwdField.exists)
        pwdField.tap()
        pwdField.typeText(password)

        // Fill in confirm password
        let confirmPwdField = passwordField("Confirm password")
        XCTAssertTrue(confirmPwdField.exists)
        confirmPwdField.tap()
        confirmPwdField.typeText(password)

        // Tap somewhere to dismiss keyboard and trigger binding updates
        // This ensures SwiftUI reactive bindings update properly
        staticTexts["Secure Your Medical Records"].tap()

        // Disable biometric (toggle is ON by default if biometric available)
        let biometricToggle = switches.firstMatch
        if biometricToggle.exists {
            let toggleValue = (biometricToggle.value as? String) == "1"
            if toggleValue {
                biometricToggle.tap() // Turn off biometric
            }
        }

        // Wait for Continue button to become enabled
        let continueButton = buttons["Continue"]
        XCTAssertTrue(continueButton.exists)

        // Wait for button to enable (reactive updates from SwiftUI)
        let buttonEnabled = continueButton.waitForExistence(timeout: 2) && continueButton.isEnabled
        XCTAssertTrue(buttonEnabled, "Continue button should be enabled after filling valid fields")

        continueButton.tap()

        // Check for error alerts - if one appears, the navigation won't succeed
        // and the test will fail with a more specific message
        if alerts.count > 0 {
            let alert = alerts.firstMatch
            if alert.exists {
                print("❌ Error alert appeared: \(alert.label)")
                // Print all static texts in the alert for debugging
                alert.staticTexts.allElementsBoundByIndex.forEach { element in
                    print("  Alert text: \(element.label)")
                }
                // Try to dismiss
                if alert.buttons["OK"].exists {
                    alert.buttons["OK"].tap()
                }
                XCTFail("Account creation failed with error alert")
            }
        }

        // Wait for HomeView to appear
        let navTitle = navigationBars["Members"]
        XCTAssertTrue(navTitle.waitForExistence(timeout: timeout), "Should navigate to main app")
    }

    /// Unlock app with password (for returning user)
    /// - Parameters:
    ///   - password: Password to use (default: "unique-horse-battery-staple-2024")
    ///   - timeout: Max wait time for UI elements
    func unlockApp(password: String = "unique-horse-battery-staple-2024", timeout: TimeInterval = 5) {
        // Wait for UnlockView to appear
        let appTitle = staticTexts["Family Medical App"]
        XCTAssertTrue(appTitle.waitForExistence(timeout: timeout), "Unlock view should appear")

        // Check if biometric button is shown (might auto-show)
        let usePasswordButton = buttons["Use Password"]
        if usePasswordButton.exists {
            usePasswordButton.tap()
        }

        // Enter password
        let pwdField = passwordField("Enter password")
        XCTAssertTrue(pwdField.waitForExistence(timeout: timeout))
        pwdField.tap()
        pwdField.typeText(password)

        // Tap Unlock button
        let unlockButton = buttons["Unlock"]
        XCTAssertTrue(unlockButton.exists)
        XCTAssertTrue(unlockButton.isEnabled, "Unlock button should be enabled")
        unlockButton.tap()

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
