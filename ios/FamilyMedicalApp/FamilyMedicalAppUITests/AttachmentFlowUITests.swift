//
//  AttachmentFlowUITests.swift
//  FamilyMedicalAppUITests
//
//  Tests for attachment handling flows including picker, viewer, and export warning
//

import XCTest

/// Tests for attachment picker, viewer, and related UI components
/// Uses consolidated test methods to minimize app launches
@MainActor
final class AttachmentFlowUITests: XCTestCase {
    var app: XCUIApplication!

    // Test person name - unique to avoid conflicts with other tests
    let testPersonName = "AttachmentTest User"

    // MARK: - Setup / Teardown

    override func setUpWithError() throws {
        continueAfterFailure = false
        setupPasswordAutofillHandler()
    }

    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
    }

    // MARK: - Consolidated Attachment Flow Test

    /// Tests all attachment-related UI in a single app launch to minimize test time
    func testAttachmentFlowsConsolidated() throws {
        // Setup - single app launch for all tests
        // Enable seedTestAttachments to auto-create test attachments for coverage
        app = XCUIApplication()
        app.launchForUITesting(resetState: true, seedTestAttachments: true)
        app.createAccount()

        // Ensure on home view
        XCTAssertTrue(
            app.navigationBars["Members"].waitForExistence(timeout: 3),
            "Should be on Members view"
        )

        // Create test person
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

        // Tap Add button
        let addButton = app.navigationBars.buttons["Add Vaccine"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 3))
        addButton.tap()

        var formTitle = app.navigationBars["Add Vaccine"]
        XCTAssertTrue(formTitle.waitForExistence(timeout: 3), "Should show add vaccine form")

        // TEST 1: Attachment picker shows add options
        // The Attachments field is at the bottom of the form - always scroll to ensure consistent behavior
        // (Conditional scrolling causes CI/local coverage variance due to timing differences)
        app.swipeUp()
        let attachmentsSection = app.staticTexts["Attachments"]
        XCTAssertTrue(
            attachmentsSection.waitForExistence(timeout: 3),
            "Attachments section should exist in form"
        )

        // Now find the add attachment button (use firstMatch for multiple matches)
        let addAttachmentButton = app.buttons["addAttachmentButton"].firstMatch
        XCTAssertTrue(
            addAttachmentButton.waitForExistence(timeout: 3),
            "Add attachment button should exist after scrolling"
        )
        addAttachmentButton.tap()

        // At least one option should exist
        // Menu labels from AttachmentPickerView: "Take Photo", "Choose from Library", "Choose File"
        let cameraOption = app.buttons["Take Photo"]
        let photoLibraryOption = app.buttons["Choose from Library"]
        let filesOption = app.buttons["Choose File"]

        let hasOptions = cameraOption.waitForExistence(timeout: 3)
            || photoLibraryOption.exists
            || filesOption.exists
        XCTAssertTrue(hasOptions, "Attachment picker should show add options")

        // Dismiss menu using helper (deterministic cleanup)
        app.dismissCurrentView()

        // TEST 2: Count summary exists
        let countSummary = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'attachments'")
        ).firstMatch
        XCTAssertTrue(
            countSummary.waitForExistence(timeout: 3),
            "Count summary should exist"
        )
        let label = countSummary.label
        XCTAssertTrue(
            label.contains("of") && label.contains("attachments"),
            "Count summary should show 'X of Y attachments' format"
        )

        // TEST 3: Fill vaccine name field (tests DynamicFieldView)
        // Scroll back up to find the Vaccine Name field (was scrolled down for Attachments)
        app.swipeDown()
        let nameField = app.textFields["Vaccine Name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3), "Vaccine Name field should exist")
        nameField.tap()
        nameField.typeText("Test Vaccine")

        // Save the record
        let saveButton = app.buttons["Save"]
        saveButton.tap()

        // Wait for form to dismiss
        formTitle = app.navigationBars["Add Vaccine"]
        XCTAssertTrue(formTitle.waitForNonExistence(timeout: 3))

        // TEST 4: Navigate to record detail and verify FieldDisplayView
        let recordCell = app.cells.containing(.staticText, identifier: "Test Vaccine").firstMatch
        XCTAssertTrue(recordCell.waitForExistence(timeout: 3))
        recordCell.tap()

        let detailTitle = app.navigationBars["Test Vaccine"]
        XCTAssertTrue(detailTitle.waitForExistence(timeout: 3))

        // Verify fields are displayed
        let vaccineNameLabel = app.staticTexts["Vaccine Name"]
        XCTAssertTrue(
            vaccineNameLabel.waitForExistence(timeout: 2),
            "Vaccine Name field label should be visible"
        )

        let vaccineNameValue = app.staticTexts["Test Vaccine"]
        XCTAssertTrue(vaccineNameValue.exists, "Vaccine name value should be visible")

        // Note: Attachments field only displays if record has attachments
        // Since we saved without attachments, skip that check

        // TEST 5: Navigate back and create a new record with seeded attachment
        // Go back to vaccines list
        app.navigationBars.buttons.element(boundBy: 0).tap()

        // Wait for list to appear
        XCTAssertTrue(listTitle.waitForExistence(timeout: 3), "Should be back on vaccines list")

        // Create another vaccine to trigger attachment picker with seeded attachment
        let addButton2 = app.navigationBars.buttons["Add Vaccine"]
        XCTAssertTrue(addButton2.waitForExistence(timeout: 3))
        addButton2.tap()

        formTitle = app.navigationBars["Add Vaccine"]
        XCTAssertTrue(formTitle.waitForExistence(timeout: 3), "Should show add vaccine form")

        // The seeded attachment should auto-appear in the picker
        // Always scroll to Attachments section for consistent behavior across CI/local
        app.swipeUp()
        let attachmentsLabel = app.staticTexts["Attachments"]
        XCTAssertTrue(
            attachmentsLabel.waitForExistence(timeout: 3),
            "Attachments section should be visible after scroll"
        )

        // Check for attachment thumbnail (it has accessibility label with filename)
        let thumbnailButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'test_attachment'")
        ).firstMatch

        XCTAssertTrue(
            thumbnailButton.waitForExistence(timeout: 5),
            "Seeded test attachment thumbnail should exist"
        )

        // TEST 6: Tap thumbnail to execute onTap closure (coverage for AttachmentPickerView)
        // The viewer navigation is not yet implemented, but tapping still exercises the code path
        thumbnailButton.tap()

        // TEST 7: Check count summary shows 1 attachment
        let countWithAttachment = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS '1 of'")
        ).firstMatch
        XCTAssertTrue(
            countWithAttachment.waitForExistence(timeout: 3),
            "Count summary with attachment should exist"
        )
        XCTAssertTrue(
            countWithAttachment.label.contains("attachments"),
            "Should show attachment count"
        )

        // Note: Remove button test skipped - nested buttons in SwiftUI require coordinate-based
        // tapping which is fragile across different device sizes. The onRemove closure is
        // covered by unit tests in AttachmentPickerViewModelTests.

        // Dismiss form using helper (deterministic cleanup)
        app.dismissCurrentView()
    }
}
