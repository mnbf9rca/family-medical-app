//
//  AddPersonFlowUITests.swift
//  FamilyMedicalAppUITests
//
//  Tests for adding person/member flow
//
//  ## Test Organization
//  Uses shared app instance with class-level setUp to avoid repeated account creation.
//  Account creation happens once, then all tests reuse that session.
//
//  Tests are kept independent (not numbered/chained) because:
//  - Creation tests modify persistent state (add people to database)
//  - Validation tests open/close sheets and need clean slate
//  - Each test's cleanup in setUpWithError ensures proper state
//
//  ## Tradeoffs
//  - Pro: Single account creation saves ~15 seconds total
//  - Pro: Tests remain independent and can run in any order
//  - Con: Per-test sheet cleanup adds small overhead (acceptable)
//
//  - Note: Ensure hardware keyboard is disabled in simulator:
//    I/O -> Keyboard -> Connect Hardware Keyboard (unchecked)
//    This prevents password autofill prompts from interfering with UI tests

import XCTest

/// Tests for adding person/member flow
@MainActor
final class AddPersonFlowUITests: XCTestCase {
    nonisolated(unsafe) static var sharedApp: XCUIApplication!
    var app: XCUIApplication { Self.sharedApp }

    nonisolated override class func setUp() {
        super.setUp()

        // One-time setup for entire test suite
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
        setupPasswordAutofillHandler()

        // Ensure we're on home view with clean state
        // Access sharedApp directly to avoid capturing self in MainActor.assumeIsolated
        //
        // Note: Setup cleanup uses conditional logic intentionally - we're cleaning up
        // any residual state from previous tests, not asserting expected behavior.
        // The final navigation bar assertion ensures we're in the correct state.
        MainActor.assumeIsolated {
            // First dismiss any alerts (they block other UI)
            let alert = Self.sharedApp.alerts.firstMatch
            if alert.waitForExistence(timeout: 1) {
                // Tap OK or any dismiss button
                for buttonLabel in ["OK", "Cancel", "Dismiss"] {
                    if alert.buttons[buttonLabel].exists {
                        alert.buttons[buttonLabel].tap()
                        break
                    }
                }
                // Wait for alert dismissal
                _ = alert.waitForNonExistence(timeout: 2)
            }

            // Then dismiss any open sheets using helper
            Self.sharedApp.dismissCurrentView()

            // Verify we're on home view - this IS an assertion (deterministic)
            let navTitle = Self.sharedApp.navigationBars["Members"]
            XCTAssertTrue(navTitle.waitForExistence(timeout: 5), "Should be on Members view after cleanup")
        }
    }

    override func tearDownWithError() throws {
        // No per-test teardown needed - shared app instance
    }

    // MARK: - Basic Add Person Tests

    func testAddPersonWithNameOnly() throws {
        // Add person with just name
        let personName = "TestNameOnly User"
        app.addPerson(name: personName)

        // Verify person appears in list
        XCTAssertTrue(app.verifyPersonExists(name: personName), "Person should appear in list after adding")
    }

    func testAddPersonWithDateOfBirth() throws {
        // Add person
        let personName = "TestDateOfBirth User"
        let addButton = app.buttons["toolbarAddMember"]
        addButton.tap()

        // Wait for sheet
        let navTitle = app.navigationBars["Add Member"]
        XCTAssertTrue(navTitle.waitForExistence(timeout: 5))

        // Fill in name
        let nameField = app.textFields["Name"]
        nameField.tap()
        nameField.typeText(personName)

        // Enable date of birth using helper (SwiftUI Toggle requires special handling)
        let dobToggle = app.switches["includeDateOfBirthToggle"]
        XCTAssertTrue(dobToggle.exists, "Toggle should exist")

        turnSwitchOn(dobToggle)

        // Verify date picker appears using accessibility identifier
        // Compact DatePicker can be various element types, so search descendants
        let datePicker = app.descendants(matching: .any)["dateOfBirthPicker"]
        XCTAssertTrue(datePicker.waitForExistence(timeout: 2), "Date picker should appear when toggle is on")

        // Save
        let saveButton = app.buttons["Save"]
        saveButton.tap()

        // Verify person appears
        XCTAssertTrue(app.verifyPersonExists(name: personName))
    }

    func testAddPersonWithNotes() throws {
        // Add person
        let personName = "TestNotes User"
        let notes = "Test notes for this person"

        let addButton = app.buttons["toolbarAddMember"]
        addButton.tap()

        // Wait for sheet
        let navTitle = app.navigationBars["Add Member"]
        XCTAssertTrue(navTitle.waitForExistence(timeout: 5))

        // Fill in name
        let nameField = app.textFields["Name"]
        nameField.tap()
        nameField.typeText(personName)

        // Fill in notes
        let notesField = app.textFields["Notes (optional)"]
        notesField.tap()
        notesField.typeText(notes)

        // Save
        let saveButton = app.buttons["Save"]
        saveButton.tap()

        // Verify person appears
        XCTAssertTrue(app.verifyPersonExists(name: personName))
    }

    func testAddMultiplePersons() throws {
        let person1 = "TestMultiple User1"
        let person2 = "TestMultiple User2"
        let person3 = "TestMultiple User3"

        // Add first person
        app.addPerson(name: person1)
        XCTAssertTrue(app.verifyPersonExists(name: person1))

        // Add second person
        app.addPerson(name: person2)
        XCTAssertTrue(app.verifyPersonExists(name: person2))

        // Add third person
        app.addPerson(name: person3)
        XCTAssertTrue(app.verifyPersonExists(name: person3))

        // Verify all three exist
        XCTAssertTrue(app.verifyPersonExists(name: person1))
        XCTAssertTrue(app.verifyPersonExists(name: person2))
        XCTAssertTrue(app.verifyPersonExists(name: person3))
    }

    // MARK: - Validation Tests

    func testAddPersonWithEmptyNameShowsError() throws {
        // Tap Add Member
        let addButton = app.buttons["toolbarAddMember"]
        addButton.tap()

        // Wait for sheet
        let navTitle = app.navigationBars["Add Member"]
        XCTAssertTrue(navTitle.waitForExistence(timeout: 5))

        // Leave name empty, just tap Save
        let saveButton = app.buttons["Save"]
        saveButton.tap()

        // Should show validation error alert
        let alert = app.alerts["Validation Error"]
        XCTAssertTrue(alert.waitForExistence(timeout: 2), "Validation error alert should appear")

        let errorMessage = alert.staticTexts["Name is required"]
        XCTAssertTrue(errorMessage.exists, "Error message should say 'Name is required'")

        // Dismiss alert
        alert.buttons["OK"].tap()

        // Sheet should still be visible (not dismissed)
        XCTAssertTrue(navTitle.exists, "Sheet should remain after validation error")
    }

    func testAddPersonWithWhitespaceOnlyNameShowsError() throws {
        // Tap Add Member
        let addButton = app.buttons["toolbarAddMember"]
        addButton.tap()

        // Wait for sheet
        let navTitle = app.navigationBars["Add Member"]
        XCTAssertTrue(navTitle.waitForExistence(timeout: 5))

        // Enter only spaces
        let nameField = app.textFields["Name"]
        nameField.tap()
        nameField.typeText("     ")

        // Tap Save
        let saveButton = app.buttons["Save"]
        saveButton.tap()

        // Should show validation error
        let alert = app.alerts["Validation Error"]
        XCTAssertTrue(alert.waitForExistence(timeout: 2), "Validation error alert should appear for whitespace-only name")
    }

    func testAddPersonWithTooLongNameShowsError() throws {
        // Tap Add Member
        let addButton = app.buttons["toolbarAddMember"]
        addButton.tap()

        // Wait for sheet
        let navTitle = app.navigationBars["Add Member"]
        XCTAssertTrue(navTitle.waitForExistence(timeout: 5))

        // Enter name longer than 100 characters
        let longName = String(repeating: "A", count: 101)
        let nameField = app.textFields["Name"]
        nameField.tap()
        nameField.typeText(longName)

        // Tap Save
        let saveButton = app.buttons["Save"]
        saveButton.tap()

        // Should show validation error
        let alert = app.alerts["Validation Error"]
        XCTAssertTrue(alert.waitForExistence(timeout: 2), "Validation error alert should appear for name > 100 chars")

        let errorMessage = alert.staticTexts["Name must be 100 characters or less"]
        XCTAssertTrue(errorMessage.exists, "Error message should mention character limit")
    }

    // MARK: - UI Interaction Tests

    func testCancelAddPersonDismissesSheet() throws {
        // Tap Add Member
        let addButton = app.buttons["toolbarAddMember"]
        addButton.tap()

        // Wait for sheet
        let navTitle = app.navigationBars["Add Member"]
        XCTAssertTrue(navTitle.waitForExistence(timeout: 5))

        // Tap Cancel
        let cancelButton = app.buttons["Cancel"]
        XCTAssertTrue(cancelButton.exists)
        cancelButton.tap()

        // Sheet should dismiss
        XCTAssertFalse(navTitle.waitForExistence(timeout: 1), "Sheet should dismiss after Cancel")

        // Should still be on home view
        let homeNavTitle = app.navigationBars["Members"]
        XCTAssertTrue(homeNavTitle.exists)
    }

    func testDateOfBirthToggleShowsHidesPicker() throws {
        // Tap Add Member
        let addButton = app.buttons["toolbarAddMember"]
        addButton.tap()

        // Wait for sheet
        let navTitle = app.navigationBars["Add Member"]
        XCTAssertTrue(navTitle.waitForExistence(timeout: 5))

        let dobToggle = app.switches["includeDateOfBirthToggle"]
        XCTAssertTrue(dobToggle.exists)

        // Date picker identified by accessibility identifier
        let datePicker = app.descendants(matching: .any)["dateOfBirthPicker"]

        // Toggle should start OFF (no date picker)
        XCTAssertFalse(datePicker.exists, "Date picker should not exist when toggle is off")

        // Turn toggle ON using helper (SwiftUI Toggle requires special handling)
        turnSwitchOn(dobToggle)

        // Date picker should appear
        XCTAssertTrue(datePicker.exists, "Date picker should appear when toggle is on")

        // Turn toggle OFF again
        turnSwitchOff(dobToggle)

        // Date picker should disappear
        XCTAssertFalse(datePicker.exists, "Date picker should disappear when toggle is off")
    }

    func testAddPersonFormHasAllElements() throws {
        // Tap Add Member
        let addButton = app.buttons["toolbarAddMember"]
        addButton.tap()

        // Wait for sheet
        let navTitle = app.navigationBars["Add Member"]
        XCTAssertTrue(navTitle.waitForExistence(timeout: 5))

        // Verify all expected elements exist
        XCTAssertTrue(app.textFields["Name"].exists, "Name field should exist")
        XCTAssertTrue(app.switches["Include Date of Birth"].exists, "DOB toggle should exist")
        XCTAssertTrue(app.textFields["Notes (optional)"].exists, "Notes field should exist")
        XCTAssertTrue(app.buttons["Cancel"].exists, "Cancel button should exist")
        XCTAssertTrue(app.buttons["Save"].exists, "Save button should exist")
    }
}
