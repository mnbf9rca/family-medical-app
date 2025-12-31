# SwiftUI XCUITest Common Issues

This document captures known SwiftUI XCUITest issues and their solutions.

## SwiftUI Toggle Not Responding to tap()

**Problem:** Calling `toggle.tap()` on a SwiftUI `Toggle` element doesn't change its state.

**Root Cause:** SwiftUI Toggle elements render with the text label in the center. The default `tap()` method taps the center of the element's frame, which hits the label text, not the actual UISwitch control.

**Solution:** Use the helper methods in `UITestHelpers.swift`:

```swift
// Turn toggle ON
let toggle = app.switches["myToggleIdentifier"]
turnSwitchOn(toggle)

// Turn toggle OFF
turnSwitchOff(toggle)
```

**Implementation Details:**

1. Tap the toggle element first (required to "activate" it)
2. Find the inner `.switch` descendant
3. Tap the center coordinate of that inner switch
4. Wait for the value to update using NSPredicate expectation

**References:**

- [UI Tests and Toggle on iOS/iPadOS](https://www.sylvaingamel.fr/en/blog/2023/23-02-12_ios-toggle-uitest/)
- [GitHub: suiToggle-ui-testing](https://github.com/sylvaingml/suiToggle-ui-testing)
- Helper implementation: `ios/FamilyMedicalApp/FamilyMedicalAppUITests/Helpers/UITestHelpers.swift`

## Password AutoFill Blocking Tests

**Problem:** iOS password autofill prompts appear during tests and block automation.

**Solution:** Multi-layered approach:

1. Disable hardware keyboard in simulator via `run-tests.sh` (uses PlistBuddy)
2. Conditionally use `TextField` instead of `SecureField` in UI testing mode
3. Add UI interruption monitors in test setUp as fallback

See `UITestingHelpers.swift` for the `isUITesting` flag implementation.
