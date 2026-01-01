//
//  MedicalRecordFlowUITests.swift
//  FamilyMedicalAppUITests
//
//  Tests for medical record CRUD flows including add, edit, and delete from detail view
//
//  ## Test Chaining Pattern
//  Tests are numbered (test1_, test2_, etc.) to ensure execution order.
//  Earlier tests create data that later tests reuse, reducing redundant
//  setup and navigation. This trades test isolation for ~60% faster execution.
//
//  If test1 fails, subsequent tests will also fail (expected behavior).
//

import XCTest

/// Tests for medical record creation, viewing, editing, and deletion
///
/// Uses test chaining pattern: tests build on each other to reduce setup overhead.
/// - `test1_AddRecords`: Creates records used by subsequent tests
/// - `test2_ViewRecordDetail`: Verifies detail view (uses record from test1)
/// - `test3_EditRecordFromDetail`: Tests edit flow (uses record from test1)
/// - `test4_DeleteRecordFromDetail`: Tests delete flow (uses record from test1)
/// - `test5_DeleteRecordCancelPreserves`: Tests cancel delete (uses record from test1)
@MainActor
final class MedicalRecordFlowUITests: XCTestCase {
    nonisolated(unsafe) static var sharedApp: XCUIApplication!
    var app: XCUIApplication { Self.sharedApp }

    // Test person name - unique to avoid conflicts with other tests
    let testPersonName = "MedRecordTest User"

    // MARK: - Shared State for Test Chaining
    //
    // These track state between tests to avoid redundant navigation.
    // Reset in class setUp, used across test1...test5.

    /// Whether we're already on the vaccines list (avoids re-navigation)
    nonisolated(unsafe) static var isOnVaccinesList = false

    /// Record names created in test1, available for test2-5 to use
    nonisolated(unsafe) static var viewTestRecord = "ViewTest Vaccine"
    nonisolated(unsafe) static var editTestRecord = "EditTest Vaccine"
    nonisolated(unsafe) static var deleteTestRecord = "DeleteTest Vaccine"
    nonisolated(unsafe) static var cancelTestRecord = "CancelTest Vaccine"

    // MARK: - Setup / Teardown

    nonisolated override class func setUp() {
        super.setUp()

        MainActor.assumeIsolated {
            sharedApp = XCUIApplication()
            sharedApp.launchForUITesting(resetState: true)
            sharedApp.createAccount()
            isOnVaccinesList = false
        }
    }

    nonisolated override class func tearDown() {
        MainActor.assumeIsolated {
            sharedApp.terminate()
            sharedApp = nil
            isOnVaccinesList = false
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

        // Lightweight per-test setup: only clean up unexpected state
        // Skip heavy navigation since tests chain together
        MainActor.assumeIsolated {
            // Dismiss any alerts that appeared unexpectedly
            let alert = Self.sharedApp.alerts.firstMatch
            if alert.waitForExistence(timeout: 0.5) {
                for buttonLabel in ["OK", "Cancel", "Dismiss"] {
                    if alert.buttons[buttonLabel].exists {
                        alert.buttons[buttonLabel].tap()
                        break
                    }
                }
                _ = alert.waitForNonExistence(timeout: 1)
            }

            // Dismiss any sheets that appeared unexpectedly
            let cancelButton = Self.sharedApp.buttons["Cancel"]
            if cancelButton.waitForExistence(timeout: 0.5) {
                cancelButton.tap()
                _ = cancelButton.waitForNonExistence(timeout: 1)
            }
        }
    }

    // MARK: - Helper Methods

    /// Navigate to the vaccines list, reusing state if already there
    private func ensureOnVaccinesList() {
        // If already on vaccines list, just verify
        let listTitle = app.navigationBars["\(testPersonName)'s Vaccine"]
        if Self.isOnVaccinesList && listTitle.exists {
            return
        }

        // Need to navigate from wherever we are
        navigateToVaccinesListFresh()
        Self.isOnVaccinesList = true
    }

    /// Full navigation to vaccines list (used when state is unknown)
    private func navigateToVaccinesListFresh() {
        // Navigate back to home if needed
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        while backButton.exists && !app.navigationBars["Members"].exists {
            backButton.tap()
            _ = app.navigationBars["Members"].waitForExistence(timeout: 2)
        }

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
        if backButton.exists {
            backButton.tap()
        }
        let listTitle = app.navigationBars["\(testPersonName)'s Vaccine"]
        XCTAssertTrue(listTitle.waitForExistence(timeout: 3), "Should return to vaccines list")
    }

    // MARK: - Test 1: Create Records (Setup for subsequent tests)

    func test1_AddRecords() throws {
        ensureOnVaccinesList()

        // Create records that will be used by test2-5
        // Also tests the add flow itself (combines testAddVaccineRecord + testAddVaccineRecordWithDefaultDate)

        // Record for view detail test
        addVaccineRecord(name: Self.viewTestRecord)
        verifyRecordExists(name: Self.viewTestRecord)

        // Record for edit test
        addVaccineRecord(name: Self.editTestRecord)
        verifyRecordExists(name: Self.editTestRecord)

        // Record for delete test
        addVaccineRecord(name: Self.deleteTestRecord)
        verifyRecordExists(name: Self.deleteTestRecord)

        // Record for cancel delete test
        addVaccineRecord(name: Self.cancelTestRecord)
        verifyRecordExists(name: Self.cancelTestRecord)
    }

    // MARK: - Test 2: View Record Detail

    func test2_ViewRecordDetail() throws {
        ensureOnVaccinesList()

        // Use record created in test1
        navigateToRecordDetail(name: Self.viewTestRecord)

        // Verify Edit and Delete buttons exist
        XCTAssertTrue(app.navigationBars.buttons["Edit Vaccine"].exists, "Edit button should exist")
        XCTAssertTrue(app.navigationBars.buttons["Delete Vaccine"].exists, "Delete button should exist")

        // Navigate back for next test
        navigateBackToList()
    }

    // MARK: - Test 3: Edit Record from Detail

    func test3_EditRecordFromDetail() throws {
        ensureOnVaccinesList()

        let originalName = Self.editTestRecord
        let updatedName = "EditTest Updated"

        // Use record created in test1
        navigateToRecordDetail(name: originalName)

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
    }

    // MARK: - Test 4: Delete Record from Detail

    func test4_DeleteRecordFromDetail() throws {
        ensureOnVaccinesList()

        // Use record created in test1
        navigateToRecordDetail(name: Self.deleteTestRecord)

        // Tap Delete
        let deleteButton = app.navigationBars.buttons["Delete Vaccine"]
        deleteButton.tap()

        // Confirm deletion
        let confirmButton = app.buttons["Delete"]
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 2))
        confirmButton.tap()

        // Should return to list
        let listTitle = app.navigationBars["\(testPersonName)'s Vaccine"]
        XCTAssertTrue(listTitle.waitForExistence(timeout: 3), "Should return to list after delete")

        // Verify record no longer exists
        let deletedCell = app.cells.containing(.staticText, identifier: Self.deleteTestRecord).firstMatch
        XCTAssertFalse(deletedCell.exists, "Deleted vaccine should not appear in list")
    }

    // MARK: - Test 5: Cancel Delete Preserves Record

    func test5_DeleteRecordCancelPreserves() throws {
        ensureOnVaccinesList()

        // Use record created in test1
        navigateToRecordDetail(name: Self.cancelTestRecord)

        let detailTitle = app.navigationBars[Self.cancelTestRecord]
        XCTAssertTrue(detailTitle.exists)

        // Tap Delete
        let deleteButton = app.navigationBars.buttons["Delete Vaccine"]
        deleteButton.tap()

        // Cancel deletion
        let cancelButton = app.buttons["Cancel"].firstMatch
        if cancelButton.waitForExistence(timeout: 2) {
            cancelButton.tap()
            _ = cancelButton.waitForNonExistence(timeout: 2)
        } else {
            // Dismiss by tapping outside the action sheet
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3)).tap()
            let deleteConfirmButton = app.buttons["Delete"]
            _ = deleteConfirmButton.waitForNonExistence(timeout: 2)
        }

        // Should still be on detail view
        XCTAssertTrue(detailTitle.waitForExistence(timeout: 2), "Should remain on detail view after cancel")

        // Navigate back and verify record still exists
        navigateBackToList()
        verifyRecordExists(name: Self.cancelTestRecord)
    }
}
