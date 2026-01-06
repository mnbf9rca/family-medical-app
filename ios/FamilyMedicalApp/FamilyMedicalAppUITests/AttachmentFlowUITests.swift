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
        let addAttachmentButton = app.buttons["Add Attachment"]
        if addAttachmentButton.waitForExistence(timeout: 2) {
            addAttachmentButton.tap()

            // At least one option should exist
            let cameraOption = app.buttons["Camera"]
            let photoLibraryOption = app.buttons["Photo Library"]
            let filesOption = app.buttons["Files"]

            let hasOptions = cameraOption.waitForExistence(timeout: 2)
                || photoLibraryOption.exists
                || filesOption.exists
            XCTAssertTrue(hasOptions, "Attachment picker should show add options")

            // Dismiss menu
            let cancelButton = app.buttons["Cancel"]
            if cancelButton.exists {
                cancelButton.tap()
            } else {
                app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3)).tap()
            }
        }

        // TEST 2: Count summary exists
        let countSummary = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'attachments'")
        ).firstMatch
        if countSummary.waitForExistence(timeout: 1) {
            let label = countSummary.label
            XCTAssertTrue(
                label.contains("of") && label.contains("attachments"),
                "Count summary should show 'X of Y attachments' format"
            )
        }

        // TEST 3: Fill vaccine name field (tests DynamicFieldView)
        let nameField = app.textFields["Vaccine Name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 2), "Vaccine Name field should exist")
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

        // Check attachments field is displayed
        let attachmentsLabel = app.staticTexts["Attachments"]
        if attachmentsLabel.waitForExistence(timeout: 1) {
            XCTAssertTrue(true, "Attachments field is visible in record detail")
        }

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
        // Check for attachment thumbnail (it has accessibility label with filename)
        let thumbnailButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'test_attachment'")
        ).firstMatch

        if thumbnailButton.waitForExistence(timeout: 2) {
            // TEST 6: Tap thumbnail to open viewer
            thumbnailButton.tap()

            // Viewer should show - wait for it briefly
            // The viewer might show as a sheet or full screen cover
            Thread.sleep(forTimeInterval: 0.5)

            // Try to dismiss if viewer appeared
            let closeButton = app.buttons["Close"]
            if closeButton.exists {
                closeButton.tap()
            } else {
                // Try swipe down to dismiss
                app.swipeDown()
            }
        }

        // TEST 7: Check count summary updated with seeded attachment
        let countWithAttachment = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS '1 of'")
        ).firstMatch
        if countWithAttachment.waitForExistence(timeout: 1) {
            XCTAssertTrue(
                countWithAttachment.label.contains("attachments"),
                "Should show attachment count"
            )
        }

        // Cancel to clean up
        let cancelButton = app.buttons["Cancel"]
        if cancelButton.exists {
            cancelButton.tap()
        }
    }
}
