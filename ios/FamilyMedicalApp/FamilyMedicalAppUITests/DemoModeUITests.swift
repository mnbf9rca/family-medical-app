//
//  DemoModeUITests.swift
//  FamilyMedicalAppUITests
//
//  Tests for demo mode functionality.
//
//  Each test resets state to start fresh at the welcome screen.
//  Demo mode is faster than full account creation (~5s vs ~15s).
//

import XCTest

/// Tests for demo mode flow
@MainActor
final class DemoModeUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchForUITesting(resetState: true)
    }

    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
    }

    // MARK: - Demo Mode Entry Tests

    func testTryDemoButtonAppearsOnWelcomeScreen() throws {
        // Verify welcome screen appears
        let welcomeHeader = app.staticTexts["Family Medical"]
        XCTAssertTrue(welcomeHeader.waitForExistence(timeout: 5), "Welcome view should appear")

        // Verify Try Demo button exists
        let tryDemoButton = app.buttons["tryDemoButton"]
        XCTAssertTrue(tryDemoButton.waitForExistence(timeout: 2), "Try Demo button should exist")
    }

    func testTapTryDemoShowsDemoSetup() throws {
        // Wait for welcome screen
        let welcomeHeader = app.staticTexts["Family Medical"]
        XCTAssertTrue(welcomeHeader.waitForExistence(timeout: 5))

        // Tap Try Demo
        let tryDemoButton = app.buttons["tryDemoButton"]
        XCTAssertTrue(tryDemoButton.exists)
        tryDemoButton.tap()

        // Should show demo setup screen (may be brief if fast device)
        // Either setup text or the main app should appear
        let setupText = app.staticTexts["Setting Up Demo"]
        let navTitle = app.navigationBars["Members"]

        let showsSetup = setupText.waitForExistence(timeout: 2)
        let showsMain = navTitle.waitForExistence(timeout: 10)

        XCTAssertTrue(showsSetup || showsMain, "Should show demo setup or navigate to main app")
    }

    func testDemoModeNavigatesToHomeWithSampleData() throws {
        // Enter demo mode using helper
        app.enterDemoMode()

        // Should show Members list
        let navTitle = app.navigationBars["Members"]
        XCTAssertTrue(navTitle.exists, "Should be on Members screen")

        // Should have demo persons (Alex Johnson is the first demo person)
        XCTAssertTrue(
            app.verifyPersonExists(name: "Alex Johnson"),
            "Demo person 'Alex Johnson' should exist"
        )
    }

    func testDemoModeShowsIndicatorInSettings() throws {
        // Enter demo mode
        app.enterDemoMode()

        // Open settings menu
        let settingsMenuButton = app.buttons["settingsMenuButton"]
        XCTAssertTrue(settingsMenuButton.waitForExistence(timeout: 2))
        settingsMenuButton.tap()

        // Tap Settings option
        let settingsButton = app.buttons["Settings"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 2))
        settingsButton.tap()

        // Should show demo mode indicator
        let demoIndicator = app.staticTexts["Demo Mode Active"]
        XCTAssertTrue(
            demoIndicator.waitForExistence(timeout: 3),
            "Demo Mode Active indicator should be visible in Settings"
        )
    }

    func testExitDemoModeReturnsToWelcome() throws {
        // Enter demo mode
        app.enterDemoMode()

        // Open settings menu
        let settingsMenuButton = app.buttons["settingsMenuButton"]
        XCTAssertTrue(settingsMenuButton.waitForExistence(timeout: 2))
        settingsMenuButton.tap()

        // Tap Settings option
        let settingsButton = app.buttons["Settings"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 2))
        settingsButton.tap()

        // Tap Exit Demo Mode button
        let exitDemoButton = app.buttons["exitDemoButton"]
        XCTAssertTrue(exitDemoButton.waitForExistence(timeout: 2))
        exitDemoButton.tap()

        // Confirm in the dialog
        let confirmButton = app.buttons["Exit Demo"]
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 2))
        confirmButton.tap()

        // Should return to welcome screen
        let welcomeHeader = app.staticTexts["Family Medical"]
        XCTAssertTrue(
            welcomeHeader.waitForExistence(timeout: 5),
            "Should return to welcome screen after exiting demo mode"
        )
    }

    func testDemoModeCreatesMultipleDemoPersons() throws {
        // Enter demo mode
        app.enterDemoMode()

        // Verify all demo persons exist
        XCTAssertTrue(app.verifyPersonExists(name: "Alex Johnson"), "Alex Johnson should exist")
        XCTAssertTrue(app.verifyPersonExists(name: "Sam Johnson"), "Sam Johnson should exist")
        XCTAssertTrue(app.verifyPersonExists(name: "Jamie Johnson"), "Jamie Johnson should exist")
    }
}
