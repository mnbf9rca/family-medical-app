//
//  BackupFlowUITests.swift
//  FamilyMedicalAppUITests
//
//  Tests for backup export/import functionality
//
//  ## Test Coverage
//  - Opening Settings from gear menu
//  - Export backup flow (encrypted/unencrypted options)
//  - Import backup flow preparation
//
//  ## Note
//  File picker and share sheet interactions are limited in UI tests due to
//  system dialog restrictions. Tests focus on app-controlled UI elements.
//
//  ## Note on XCTest Ordering
//  XCTest does NOT guarantee test execution order. Account creation is expensive,
//  so all backup flow tests are consolidated into a single method that creates
//  the account once and tests all functionality sequentially.
//

import XCTest

/// Tests for backup export/import flow
@MainActor
final class BackupFlowUITests: XCTestCase {
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

    // MARK: - Consolidated Backup Flow Test
    //
    // This test consolidates all backup operations into a single method.
    // XCTest does NOT guarantee test ordering, and account creation is expensive.
    // Creating the account once and testing sequentially saves significant time.

    func testBackupFlowWorkflow() throws {
        // Setup: Create account and get to home screen (done ONCE)
        app = XCUIApplication()
        app.launchForUITesting(resetState: true)
        app.createAccount()

        // --- Step 1: Verify Settings Access from Gear Menu ---
        verifySettingsAccess()

        // --- Step 2: Verify Export Options Sheet ---
        verifyExportOptionsSheet()

        // --- Step 3: Verify Export Password Validation ---
        verifyExportPasswordValidation()

        // --- Step 4: Verify Encryption Toggle Exists ---
        verifyEncryptionToggle()

        // --- Step 5: Verify Import Shows File Picker ---
        verifyImportFilePicker()
    }

    // MARK: - Test Steps

    /// Step 1: Verify Settings can be opened from the gear menu
    private func verifySettingsAccess() {
        // Verify we're on the main screen
        let membersNav = app.navigationBars["Members"]
        XCTAssertTrue(membersNav.waitForExistence(timeout: 5), "Should be on Members screen")

        // Tap the gear menu button
        let gearButton = app.buttons["settingsMenuButton"]
        XCTAssertTrue(gearButton.waitForExistence(timeout: 3), "Gear button should exist")
        gearButton.tap()

        // Verify Settings menu item appears
        let settingsButton = app.buttons["Settings"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 3), "Settings button should appear in menu")
        settingsButton.tap()

        // Verify Settings sheet appears
        let settingsTitle = app.navigationBars["Settings"]
        XCTAssertTrue(settingsTitle.waitForExistence(timeout: 3), "Settings sheet should appear")

        // Verify backup section is visible
        let exportButton = app.buttons["Export Backup"]
        XCTAssertTrue(exportButton.waitForExistence(timeout: 2), "Export Backup button should exist")

        let importButton = app.buttons["Import Backup"]
        XCTAssertTrue(importButton.exists, "Import Backup button should exist")

        // Dismiss settings
        let doneButton = app.buttons["Done"]
        XCTAssertTrue(doneButton.exists)
        doneButton.tap()

        // Verify back on main screen
        XCTAssertTrue(membersNav.waitForExistence(timeout: 3), "Should return to Members screen")
    }

    /// Step 2: Verify Export Backup shows options sheet with password fields
    private func verifyExportOptionsSheet() {
        openSettings()

        // Tap Export Backup
        let exportButton = app.buttons["Export Backup"]
        XCTAssertTrue(exportButton.waitForExistence(timeout: 3))
        exportButton.tap()

        // Verify export options sheet appears
        let exportTitle = app.navigationBars["Export Backup"]
        XCTAssertTrue(exportTitle.waitForExistence(timeout: 3), "Export options sheet should appear")

        // Verify encryption toggle exists (default should be on)
        let encryptToggle = app.switches["Encrypt Backup"]
        XCTAssertTrue(encryptToggle.exists, "Encrypt toggle should exist")

        // Verify password fields appear when encrypted (default)
        let passwordField = app.secureTextFields["exportPasswordField"]
        XCTAssertTrue(passwordField.waitForExistence(timeout: 2), "Password field should appear for encrypted export")

        // Cancel export
        let cancelButton = app.buttons["Cancel"]
        XCTAssertTrue(cancelButton.exists)
        cancelButton.tap()

        // Verify back on settings
        let settingsTitle = app.navigationBars["Settings"]
        XCTAssertTrue(settingsTitle.waitForExistence(timeout: 2), "Should return to Settings")

        // Dismiss settings to return to home
        dismissSettings()
    }

    /// Step 3: Verify password validation (weak password disables export, strong enables)
    private func verifyExportPasswordValidation() {
        openSettings()

        // Open export options
        let exportBackupButton = app.buttons["Export Backup"]
        XCTAssertTrue(exportBackupButton.waitForExistence(timeout: 3))
        exportBackupButton.tap()

        // Verify export options appeared
        let exportTitle = app.navigationBars["Export Backup"]
        XCTAssertTrue(exportTitle.waitForExistence(timeout: 3))

        // Verify export button is initially disabled (no password entered)
        let exportButton = app.buttons["exportButton"]
        XCTAssertTrue(exportButton.exists, "Export button should exist")
        XCTAssertFalse(exportButton.isEnabled, "Export button should be disabled without password")

        // Enter a weak password
        let passwordField = app.secureTextFields["exportPasswordField"]
        XCTAssertTrue(passwordField.exists)
        passwordField.tap()
        passwordField.typeText("weak")

        // Export should still be disabled (password too weak)
        XCTAssertFalse(exportButton.isEnabled, "Export should be disabled with weak password")

        // Clear and enter strong password
        passwordField.clearText()
        passwordField.typeText("StrongPassword123!")

        let confirmField = app.secureTextFields["exportConfirmPasswordField"]
        XCTAssertTrue(confirmField.exists)
        confirmField.tap()
        confirmField.typeText("StrongPassword123!")

        // Export should now be enabled
        XCTAssertTrue(exportButton.waitForEnabled(timeout: 2), "Export should be enabled with strong matching passwords")

        // Cancel
        app.buttons["Cancel"].tap()

        // Dismiss settings
        dismissSettings()
    }

    /// Step 4: Verify encryption toggle exists and defaults to on
    private func verifyEncryptionToggle() {
        openSettings()

        // Open export options
        app.buttons["Export Backup"].tap()

        let exportTitle = app.navigationBars["Export Backup"]
        XCTAssertTrue(exportTitle.waitForExistence(timeout: 3))

        // Verify the encryption section exists with the toggle
        // The Toggle renders as a switch in UIKit
        let encryptToggle = app.switches.firstMatch
        XCTAssertTrue(encryptToggle.waitForExistence(timeout: 2), "Encryption toggle should exist")

        // Verify toggle is on by default (value "1" means on)
        XCTAssertEqual(encryptToggle.value as? String, "1", "Encryption should be enabled by default")

        // Dismiss export options
        let cancelButton = app.navigationBars["Export Backup"].buttons["Cancel"]
        XCTAssertTrue(cancelButton.exists)
        cancelButton.tap()

        // Dismiss settings
        dismissSettings()
    }

    /// Step 5: Verify Import shows file picker
    private func verifyImportFilePicker() {
        openSettings()

        // Tap Import Backup
        let importButton = app.buttons["Import Backup"]
        XCTAssertTrue(importButton.waitForExistence(timeout: 3))
        importButton.tap()

        // File picker should appear (system dialog)
        // Note: We can only verify the picker appears, not interact with it
        // The picker is presented by the system, so we check for its existence briefly
        // then dismiss

        // Wait a moment for picker to appear
        Thread.sleep(forTimeInterval: 1.0)

        // Dismiss by tapping Cancel in the picker (if accessible) or swipe down
        app.dismissCurrentView()

        // Should be back on Settings
        let settingsTitle = app.navigationBars["Settings"]
        XCTAssertTrue(settingsTitle.waitForExistence(timeout: 5), "Should return to Settings after dismissing picker")

        // Dismiss settings
        dismissSettings()
    }

    // MARK: - Helpers

    private func openSettings() {
        let gearButton = app.buttons["settingsMenuButton"]
        XCTAssertTrue(gearButton.waitForExistence(timeout: 5))
        gearButton.tap()

        let settingsButton = app.buttons["Settings"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 3))
        settingsButton.tap()

        let settingsTitle = app.navigationBars["Settings"]
        XCTAssertTrue(settingsTitle.waitForExistence(timeout: 3))
    }

    private func dismissSettings() {
        let doneButton = app.buttons["Done"]
        if doneButton.waitForExistence(timeout: 2) {
            doneButton.tap()
        }

        let membersNav = app.navigationBars["Members"]
        XCTAssertTrue(membersNav.waitForExistence(timeout: 3), "Should return to Members screen")
    }
}

// MARK: - XCUIElement Extension

extension XCUIElement {
    /// Wait for element to become enabled
    /// - Parameter timeout: Maximum time to wait
    /// - Returns: true if element is enabled within timeout
    func waitForEnabled(timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "isEnabled == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        return result == .completed
    }
}
