//
//  AddPersonFlowUITests.swift
//  FamilyMedicalAppUITests
//
//  Created by rob on 29/12/2025.
//

import XCTest

/// Tests for adding person/member flow
/// - Note: Ensure hardware keyboard is disabled in simulator: I/O → Keyboard → Connect Hardware Keyboard (unchecked)
///   This prevents password autofill prompts from interfering with UI tests
final class AddPersonFlowUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()

        // Add UI interruption monitor to handle password autofill prompts
        addUIInterruptionMonitor(withDescription: "Password Autofill") { alert in
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

        // Start each test with authenticated user
        app.launchForUITesting(resetState: true)
        app.createAccount()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Basic Add Person Tests

    @MainActor
    func testAddPersonWithNameOnly() throws {
        // Verify we're on empty home view
        let emptyStateText = app.staticTexts["No Members Yet"]
        XCTAssertTrue(emptyStateText.exists, "Should start with empty state")

        // Add person with just name
        let personName = "Alice Smith"
        app.addPerson(name: personName)

        // Verify person appears in list
        XCTAssertTrue(app.verifyPersonExists(name: personName), "Person should appear in list after adding")

        // Empty state should be gone
        XCTAssertFalse(emptyStateText.exists, "Empty state should disappear after adding person")
    }

    @MainActor
    func testAddPersonWithDateOfBirth() throws {
        // Add person
        let personName = "Bob Johnson"
        let addButton = app.buttons["Add Member"]
        addButton.tap()

        // Wait for sheet
        let navTitle = app.navigationBars["Add Member"]
        XCTAssertTrue(navTitle.waitForExistence(timeout: 5))

        // Fill in name
        let nameField = app.textFields["Name"]
        nameField.tap()
        nameField.typeText(personName)

        // Enable date of birth
        let dobToggle = app.switches["Include Date of Birth"]
        XCTAssertTrue(dobToggle.exists)
        dobToggle.tap()

        // Verify date picker appears
        let datePicker = app.datePickers.firstMatch
        XCTAssertTrue(datePicker.exists, "Date picker should appear when toggle is on")

        // Save
        let saveButton = app.buttons["Save"]
        saveButton.tap()

        // Verify person appears
        XCTAssertTrue(app.verifyPersonExists(name: personName))
    }

    @MainActor
    func testAddPersonWithNotes() throws {
        // Add person
        let personName = "Carol Williams"
        let notes = "Test notes for this person"

        let addButton = app.buttons["Add Member"]
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

    @MainActor
    func testAddMultiplePersons() throws {
        let person1 = "Alice Smith"
        let person2 = "Bob Johnson"
        let person3 = "Carol Williams"

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

    @MainActor
    func testAddPersonWithEmptyNameShowsError() throws {
        // Tap Add Member
        let addButton = app.buttons["Add Member"]
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

    @MainActor
    func testAddPersonWithWhitespaceOnlyNameShowsError() throws {
        // Tap Add Member
        let addButton = app.buttons["Add Member"]
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

    @MainActor
    func testAddPersonWithTooLongNameShowsError() throws {
        // Tap Add Member
        let addButton = app.buttons["Add Member"]
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

    @MainActor
    func testCancelAddPersonDismissesSheet() throws {
        // Tap Add Member
        let addButton = app.buttons["Add Member"]
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

    @MainActor
    func testDateOfBirthToggleShowsHidesPicker() throws {
        // Tap Add Member
        let addButton = app.buttons["Add Member"]
        addButton.tap()

        // Wait for sheet
        let navTitle = app.navigationBars["Add Member"]
        XCTAssertTrue(navTitle.waitForExistence(timeout: 5))

        let dobToggle = app.switches["Include Date of Birth"]
        XCTAssertTrue(dobToggle.exists)

        let datePicker = app.datePickers.firstMatch

        // Toggle should start OFF (no date picker)
        XCTAssertFalse(datePicker.exists, "Date picker should not exist when toggle is off")

        // Turn toggle ON
        dobToggle.tap()

        // Date picker should appear
        XCTAssertTrue(datePicker.waitForExistence(timeout: 1), "Date picker should appear when toggle is on")

        // Turn toggle OFF again
        dobToggle.tap()

        // Date picker should disappear
        XCTAssertFalse(datePicker.exists, "Date picker should disappear when toggle is off")
    }

    @MainActor
    func testAddPersonFormHasAllElements() throws {
        // Tap Add Member
        let addButton = app.buttons["Add Member"]
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
