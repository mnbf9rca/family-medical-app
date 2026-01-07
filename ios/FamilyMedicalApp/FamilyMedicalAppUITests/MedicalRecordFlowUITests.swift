//
//  MedicalRecordFlowUITests.swift
//  FamilyMedicalAppUITests
//
//  Tests for medical record CRUD flows including add, edit, and delete from detail view
//
//  ## Note on XCTest Ordering
//  XCTest does NOT guarantee test execution order. Previously, tests were named
//  `test1_`, `test2_`, etc. to imply ordering, but this is not reliable.
//  CRUD operations are now consolidated into a single test method.
//

import XCTest

/// Tests for medical record creation, viewing, editing, and deletion
@MainActor
final class MedicalRecordFlowUITests: XCTestCase {
    var app: XCUIApplication!

    // Test person name - unique to avoid conflicts with other tests
    let testPersonName = "MedRecordTest User"

    // MARK: - Setup / Teardown

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
    }

    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
    }

    // MARK: - Helper Methods

    /// Navigate to the vaccines list for the test person
    private func navigateToVaccinesList() {
        // Ensure on home view
        XCTAssertTrue(
            app.navigationBars["Members"].waitForExistence(timeout: 3),
            "Should be on Members view"
        )

        // Create test person if doesn't exist
        if !app.verifyPersonExists(name: testPersonName, timeout: 1) {
            app.addPerson(name: testPersonName)
        }

        // Navigate to person detail
        let personCell = app.cells.containing(.staticText, identifier: testPersonName).firstMatch
        XCTAssertTrue(personCell.waitForExistence(timeout: 3))
        personCell.tap()

        let navTitle = app.navigationBars[testPersonName]
        XCTAssertTrue(navTitle.waitForExistence(timeout: 3), "Should navigate to person detail")

        // Navigate to vaccines list
        let vaccineRow = app.cells.containing(.staticText, identifier: "Vaccine").firstMatch
        XCTAssertTrue(vaccineRow.waitForExistence(timeout: 3), "Vaccine row should exist")
        vaccineRow.tap()

        let listTitle = app.navigationBars["\(testPersonName)'s Vaccine"]
        XCTAssertTrue(listTitle.waitForExistence(timeout: 3), "Should navigate to vaccines list")
    }

    /// Add a vaccine record with given name (assumes already on vaccines list)
    private func addVaccineRecord(name: String) {
        let addButton = app.navigationBars.buttons["Add Vaccine"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 3))
        addButton.tap()

        let formTitle = app.navigationBars["Add Vaccine"]
        XCTAssertTrue(formTitle.waitForExistence(timeout: 3))

        let nameField = app.textFields["Vaccine Name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 2))
        nameField.tap()
        nameField.typeText(name)

        let saveButton = app.buttons["Save"]
        XCTAssertTrue(saveButton.exists)
        saveButton.tap()

        XCTAssertTrue(formTitle.waitForNonExistence(timeout: 3), "Form should dismiss after save")
    }

    /// Verify a record exists in the list
    private func verifyRecordExists(name: String) {
        let recordCell = app.cells.containing(.staticText, identifier: name).firstMatch
        XCTAssertTrue(recordCell.waitForExistence(timeout: 3), "\(name) should appear in list")
    }

    /// Navigate to record detail view
    private func navigateToRecordDetail(name: String) {
        let recordCell = app.cells.containing(.staticText, identifier: name).firstMatch
        XCTAssertTrue(recordCell.waitForExistence(timeout: 3))
        recordCell.tap()

        let detailTitle = app.navigationBars[name]
        XCTAssertTrue(detailTitle.waitForExistence(timeout: 3), "Should navigate to record detail")
    }

    /// Navigate back to the vaccines list from a detail view
    private func navigateBackToList() {
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(backButton.waitForExistence(timeout: 3), "Back button should exist")
        backButton.tap()

        let listTitle = app.navigationBars["\(testPersonName)'s Vaccine"]
        XCTAssertTrue(listTitle.waitForExistence(timeout: 3), "Should return to vaccines list")
    }

    // MARK: - CRUD Workflow Test
    //
    // This test consolidates all CRUD operations into a single method.
    // XCTest does NOT guarantee test ordering, so chained tests with `test1_`, `test2_`
    // prefixes are unreliable. This single method tests all operations sequentially.

    func testMedicalRecordCRUDWorkflow() throws {
        // Setup: Launch app and create account
        app = XCUIApplication()
        app.launchForUITesting(resetState: true)
        app.createAccount()

        // Navigate to vaccines list
        navigateToVaccinesList()

        // Record names for this test
        let viewTestRecord = "ViewTest Vaccine"
        let editTestRecord = "EditTest Vaccine"
        let deleteTestRecord = "DeleteTest Vaccine"
        let cancelTestRecord = "CancelTest Vaccine"

        // --- Step 1: Create Records ---
        addVaccineRecord(name: viewTestRecord)
        verifyRecordExists(name: viewTestRecord)

        addVaccineRecord(name: editTestRecord)
        verifyRecordExists(name: editTestRecord)

        addVaccineRecord(name: deleteTestRecord)
        verifyRecordExists(name: deleteTestRecord)

        addVaccineRecord(name: cancelTestRecord)
        verifyRecordExists(name: cancelTestRecord)

        // --- Step 2: View Record Detail ---
        navigateToRecordDetail(name: viewTestRecord)

        // Verify Edit and Delete buttons exist
        XCTAssertTrue(app.navigationBars.buttons["Edit Vaccine"].exists, "Edit button should exist")
        XCTAssertTrue(app.navigationBars.buttons["Delete Vaccine"].exists, "Delete button should exist")

        navigateBackToList()

        // --- Step 3: Edit Record from Detail ---
        let updatedName = "EditTest Updated"

        navigateToRecordDetail(name: editTestRecord)

        // Tap Edit
        let editButton = app.navigationBars.buttons["Edit Vaccine"]
        editButton.tap()

        let formTitle = app.navigationBars["Edit Vaccine"]
        XCTAssertTrue(formTitle.waitForExistence(timeout: 3))

        // Update vaccine name
        let nameField = app.textFields["Vaccine Name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 2))

        // Clear existing text and enter new name
        nameField.tap()
        let existingText = (nameField.value as? String) ?? ""
        let deleteKeys = String(repeating: XCUIKeyboardKey.delete.rawValue, count: existingText.count)
        nameField.typeText(deleteKeys)
        nameField.typeText(updatedName)

        // Save
        let saveButton = app.buttons["Save"]
        saveButton.tap()

        // Form and detail should dismiss (edit returns to list)
        XCTAssertTrue(formTitle.waitForNonExistence(timeout: 3))

        // Verify back at list
        let listTitle = app.navigationBars["\(testPersonName)'s Vaccine"]
        XCTAssertTrue(listTitle.waitForExistence(timeout: 3), "Should return to list after edit")

        // Verify updated record appears
        let updatedCell = app.cells.containing(.staticText, identifier: updatedName).firstMatch
        XCTAssertTrue(updatedCell.waitForExistence(timeout: 3), "Updated vaccine should appear in list")

        // --- Step 4: Delete Record from Detail ---
        navigateToRecordDetail(name: deleteTestRecord)

        // Tap Delete
        let deleteButton = app.navigationBars.buttons["Delete Vaccine"]
        deleteButton.tap()

        // Confirm deletion
        let confirmButton = app.buttons["Delete"]
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 2))
        confirmButton.tap()

        // Should return to list
        XCTAssertTrue(listTitle.waitForExistence(timeout: 3), "Should return to list after delete")

        // Verify record no longer exists
        let deletedCell = app.cells.containing(.staticText, identifier: deleteTestRecord).firstMatch
        XCTAssertFalse(deletedCell.exists, "Deleted vaccine should not appear in list")

        // --- Step 5: Cancel Delete Preserves Record ---
        navigateToRecordDetail(name: cancelTestRecord)

        let detailTitle = app.navigationBars[cancelTestRecord]
        XCTAssertTrue(detailTitle.exists)

        // Tap Delete
        let deleteButtonForCancel = app.navigationBars.buttons["Delete Vaccine"]
        deleteButtonForCancel.tap()

        // Cancel deletion - SwiftUI confirmationDialog may not expose Cancel button
        // in accessibility tree. Verify dialog appeared, then dismiss by tapping outside.
        let deleteConfirmButton = app.buttons["Delete"].firstMatch
        XCTAssertTrue(
            deleteConfirmButton.waitForExistence(timeout: 5),
            "Delete confirmation dialog should appear"
        )

        // Try Cancel button first, fall back to tapping outside (both are valid cancel gestures)
        let cancelButton = app.buttons["Cancel"].firstMatch
        if cancelButton.waitForExistence(timeout: 1) {
            cancelButton.tap()
        } else {
            // Dismiss by tapping outside the action sheet (standard cancel gesture)
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3)).tap()
        }

        // Verify dialog dismissed
        XCTAssertTrue(
            deleteConfirmButton.waitForNonExistence(timeout: 3),
            "Confirmation dialog should dismiss after cancel"
        )

        // Should still be on detail view
        XCTAssertTrue(detailTitle.waitForExistence(timeout: 2), "Should remain on detail view after cancel")

        // Navigate back and verify record still exists
        navigateBackToList()
        verifyRecordExists(name: cancelTestRecord)
    }
}
