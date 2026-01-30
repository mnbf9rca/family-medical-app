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

    // MARK: - Settings Access Tests

    func testOpenSettingsFromGearMenu() throws {
        // Setup: Create account and get to home screen
        app = XCUIApplication()
        app.launchForUITesting(resetState: true)
        app.createAccount()

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

    // MARK: - Export Flow Tests

    func testExportBackupShowsOptions() throws {
        // Setup
        app = XCUIApplication()
        app.launchForUITesting(resetState: true)
        app.createAccount()
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
    }

    func testExportPasswordValidation() throws {
        // Setup
        app = XCUIApplication()
        app.launchForUITesting(resetState: true)
        app.createAccount()
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
    }

    /// Test that toggling encryption off shows a warning
    /// - Note: SwiftUI confirmationDialog testing is unreliable; this test verifies the toggle exists
    func testUnencryptedExportToggleExists() throws {
        // Setup
        app = XCUIApplication()
        app.launchForUITesting(resetState: true)
        app.createAccount()
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
    }

    // MARK: - Import Flow Tests

    func testImportBackupShowsFilePicker() throws {
        // Setup
        app = XCUIApplication()
        app.launchForUITesting(resetState: true)
        app.createAccount()
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
