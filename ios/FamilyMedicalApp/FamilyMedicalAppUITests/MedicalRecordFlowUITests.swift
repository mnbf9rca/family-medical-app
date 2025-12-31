//
//  MedicalRecordFlowUITests.swift
//  FamilyMedicalAppUITests
//
//  Tests for medical record CRUD flows including add, edit, and delete from detail view
//

import XCTest

/// Tests for medical record creation, viewing, editing, and deletion
@MainActor
final class MedicalRecordFlowUITests: XCTestCase {
    nonisolated(unsafe) static var sharedApp: XCUIApplication!
    var app: XCUIApplication { Self.sharedApp }

    // Test person name - unique to avoid conflicts with other tests
    let testPersonName = "MedRecordTest User"

    nonisolated override class func setUp() {
        super.setUp()

        MainActor.assumeIsolated {
            sharedApp = XCUIApplication()
            sharedApp.launchForUITesting(resetState: true)
            sharedApp.createAccount()
        }
    }

    nonisolated override class func tearDown() {
        MainActor.assumeIsolated {
            sharedApp.terminate()
            sharedApp = nil
        }
        super.tearDown()
    }

    override func setUpWithError() throws {
        continueAfterFailure = false

        // Handle password autofill prompts
        addUIInterruptionMonitor(withDescription: "Password Autofill") { alert in
            return MainActor.assumeIsolated {
                if alert.buttons["Not Now"].exists {
                    alert.buttons["Not Now"].tap()
                    return true
                }
                return false
            }
        }

        // Navigate to home view
        MainActor.assumeIsolated {
            // Dismiss any alerts
            let alert = Self.sharedApp.alerts.firstMatch
            if alert.waitForExistence(timeout: 1) {
                for buttonLabel in ["OK", "Cancel", "Dismiss"] {
                    if alert.buttons[buttonLabel].exists {
                        alert.buttons[buttonLabel].tap()
                        break
                    }
                }
                _ = alert.waitForNonExistence(timeout: 2)
            }

            // Dismiss any sheets
            let cancelButton = Self.sharedApp.buttons["Cancel"]
            if cancelButton.waitForExistence(timeout: 1) {
                cancelButton.tap()
                _ = cancelButton.waitForNonExistence(timeout: 2)
            }

            // Navigate back to home if needed
            let backButton = Self.sharedApp.navigationBars.buttons.element(boundBy: 0)
            while backButton.exists, !Self.sharedApp.navigationBars["Members"].exists {
                backButton.tap()
                _ = Self.sharedApp.navigationBars["Members"].waitForExistence(timeout: 2)
            }

            // Verify we're on home view
            XCTAssertTrue(
                Self.sharedApp.navigationBars["Members"].waitForExistence(timeout: 3),
                "Should be on Members view"
            )
        }
    }

    // MARK: - Helper Methods

    /// Ensure test person exists, navigate to their detail view
    private func navigateToTestPersonDetail() {
        // Create test person if doesn't exist
        if !app.verifyPersonExists(name: testPersonName, timeout: 1) {
            app.addPerson(name: testPersonName)
        }

        // Tap on person to go to detail
        let personCell = app.cells.containing(.staticText, identifier: testPersonName).firstMatch
        XCTAssertTrue(personCell.waitForExistence(timeout: 3))
        personCell.tap()

        // Wait for person detail view
        let navTitle = app.navigationBars[testPersonName]
        XCTAssertTrue(navTitle.waitForExistence(timeout: 3), "Should navigate to person detail")
    }

    /// Navigate to vaccines list for test person
    private func navigateToVaccinesList() {
        navigateToTestPersonDetail()

        // Tap on Vaccine row (singular - matches BuiltInSchemaType.displayName)
        let vaccineRow = app.cells.containing(.staticText, identifier: "Vaccine").firstMatch
        XCTAssertTrue(vaccineRow.waitForExistence(timeout: 3), "Vaccine row should exist")
        vaccineRow.tap()

        // Wait for vaccines list
        let listTitle = app.navigationBars["\(testPersonName)'s Vaccine"]
        XCTAssertTrue(listTitle.waitForExistence(timeout: 3), "Should navigate to vaccines list")
    }

    /// Add a vaccine record with given name
    private func addVaccineRecord(name: String) {
        // Tap add button in toolbar (not the one in empty state view)
        let addButton = app.navigationBars.buttons["Add Vaccine"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 3))
        addButton.tap()

        // Wait for form
        let formTitle = app.navigationBars["Add Vaccine"]
        XCTAssertTrue(formTitle.waitForExistence(timeout: 3))

        // Fill in vaccine name
        let nameField = app.textFields["Vaccine Name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 2))
        nameField.tap()
        nameField.typeText(name)

        // Date is pre-populated with today, so just save
        let saveButton = app.buttons["Save"]
        XCTAssertTrue(saveButton.exists)
        saveButton.tap()

        // Wait for form to dismiss
        XCTAssertTrue(formTitle.waitForNonExistence(timeout: 3), "Form should dismiss after save")
    }

    // MARK: - Add Record Tests

    func testAddVaccineRecord() throws {
        navigateToVaccinesList()

        let vaccineName = "TestAdd Vaccine"
        addVaccineRecord(name: vaccineName)

        // Verify record appears in list
        let recordCell = app.cells.containing(.staticText, identifier: vaccineName).firstMatch
        XCTAssertTrue(recordCell.waitForExistence(timeout: 3), "New vaccine should appear in list")
    }

    func testAddVaccineRecordWithDefaultDate() throws {
        navigateToVaccinesList()

        let vaccineName = "TestDefaultDate Vaccine"

        // Tap add button in toolbar
        let addButton = app.navigationBars.buttons["Add Vaccine"]
        addButton.tap()

        // Wait for form
        let formTitle = app.navigationBars["Add Vaccine"]
        XCTAssertTrue(formTitle.waitForExistence(timeout: 3))

        // Fill in vaccine name only - date should default to today
        let nameField = app.textFields["Vaccine Name"]
        nameField.tap()
        nameField.typeText(vaccineName)

        // Save without touching date picker
        let saveButton = app.buttons["Save"]
        saveButton.tap()

        // Should succeed (no validation error)
        XCTAssertTrue(formTitle.waitForNonExistence(timeout: 3), "Form should dismiss - date pre-initialized")

        // Verify record appears
        let recordCell = app.cells.containing(.staticText, identifier: vaccineName).firstMatch
        XCTAssertTrue(recordCell.waitForExistence(timeout: 3))
    }

    // MARK: - View Detail Tests

    func testViewRecordDetail() throws {
        navigateToVaccinesList()

        let vaccineName = "TestViewDetail Vaccine"
        addVaccineRecord(name: vaccineName)

        // Tap on record to view detail
        let recordCell = app.cells.containing(.staticText, identifier: vaccineName).firstMatch
        XCTAssertTrue(recordCell.waitForExistence(timeout: 3))
        recordCell.tap()

        // Verify detail view shows
        let detailTitle = app.navigationBars[vaccineName]
        XCTAssertTrue(detailTitle.waitForExistence(timeout: 3), "Should navigate to record detail")

        // Verify Edit and Delete buttons exist (in toolbar)
        XCTAssertTrue(app.navigationBars.buttons["Edit Vaccine"].exists, "Edit button should exist")
        XCTAssertTrue(app.navigationBars.buttons["Delete Vaccine"].exists, "Delete button should exist")
    }

    // MARK: - Edit from Detail Tests

    func testEditRecordFromDetail() throws {
        navigateToVaccinesList()

        let originalName = "TestEdit Original"
        let updatedName = "TestEdit Updated"
        addVaccineRecord(name: originalName)

        // Navigate to detail
        let recordCell = app.cells.containing(.staticText, identifier: originalName).firstMatch
        recordCell.tap()

        let detailTitle = app.navigationBars[originalName]
        XCTAssertTrue(detailTitle.waitForExistence(timeout: 3))

        // Tap Edit (uses accessibility label)
        let editButton = app.navigationBars.buttons["Edit Vaccine"]
        editButton.tap()

        // Wait for edit form
        let formTitle = app.navigationBars["Edit Vaccine"]
        XCTAssertTrue(formTitle.waitForExistence(timeout: 3))

        // Update vaccine name
        let nameField = app.textFields["Vaccine Name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 2))

        // Clear existing text by deleting all characters
        nameField.tap()
        let existingText = (nameField.value as? String) ?? ""
        let deleteKeys = String(repeating: XCUIKeyboardKey.delete.rawValue, count: existingText.count)
        nameField.typeText(deleteKeys)
        nameField.typeText(updatedName)

        // Save
        let saveButton = app.buttons["Save"]
        saveButton.tap()

        // Form should dismiss and detail view should dismiss (data is stale)
        XCTAssertTrue(formTitle.waitForNonExistence(timeout: 3))

        // Should be back at list view
        let listTitle = app.navigationBars["\(testPersonName)'s Vaccine"]
        XCTAssertTrue(listTitle.waitForExistence(timeout: 3), "Should return to list after edit")

        // Updated record should appear in list
        let updatedCell = app.cells.containing(.staticText, identifier: updatedName).firstMatch
        XCTAssertTrue(updatedCell.waitForExistence(timeout: 3), "Updated vaccine should appear in list")
    }

    // MARK: - Delete from Detail Tests

    func testDeleteRecordFromDetail() throws {
        navigateToVaccinesList()

        let vaccineName = "TestDelete Vaccine"
        addVaccineRecord(name: vaccineName)

        // Navigate to detail
        let recordCell = app.cells.containing(.staticText, identifier: vaccineName).firstMatch
        recordCell.tap()

        let detailTitle = app.navigationBars[vaccineName]
        XCTAssertTrue(detailTitle.waitForExistence(timeout: 3))

        // Tap Delete (uses accessibility label)
        let deleteButton = app.navigationBars.buttons["Delete Vaccine"]
        deleteButton.tap()

        // Confirm deletion in dialog
        let confirmButton = app.buttons["Delete"]
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 2))
        confirmButton.tap()

        // Should return to list view
        let listTitle = app.navigationBars["\(testPersonName)'s Vaccine"]
        XCTAssertTrue(listTitle.waitForExistence(timeout: 3), "Should return to list after delete")

        // Record should no longer exist
        let deletedCell = app.cells.containing(.staticText, identifier: vaccineName).firstMatch
        XCTAssertFalse(deletedCell.exists, "Deleted vaccine should not appear in list")
    }

    func testDeleteRecordFromDetailCancel() throws {
        navigateToVaccinesList()

        let vaccineName = "TestDeleteCancel Vaccine"
        addVaccineRecord(name: vaccineName)

        // Navigate to detail
        let recordCell = app.cells.containing(.staticText, identifier: vaccineName).firstMatch
        recordCell.tap()

        let detailTitle = app.navigationBars[vaccineName]
        XCTAssertTrue(detailTitle.waitForExistence(timeout: 3))

        // Tap Delete (uses accessibility label)
        let deleteButton = app.navigationBars.buttons["Delete Vaccine"]
        deleteButton.tap()

        // Cancel deletion - button may be in sheet or main app
        let cancelButton = app.buttons["Cancel"].firstMatch
        if cancelButton.waitForExistence(timeout: 2) {
            cancelButton.tap()
        } else {
            // Dismiss by tapping outside the action sheet
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3)).tap()
        }

        // Wait for dialog to dismiss
        Thread.sleep(forTimeInterval: 0.5)

        // Should still be on detail view
        XCTAssertTrue(detailTitle.waitForExistence(timeout: 2), "Should remain on detail view after cancel")
    }
}
