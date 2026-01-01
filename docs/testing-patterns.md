# iOS Testing Patterns

This document captures iOS testing patterns and solutions for common issues.

## Table of Contents

- [SwiftUI Toggle Not Responding to tap()](#swiftui-toggle-not-responding-to-tap)
- [Password AutoFill Blocking Tests](#password-autofill-blocking-tests)
- [Testing SwiftUI Bindings with ViewInspector](#testing-swiftui-bindings-with-viewinspector)
- [UI Test Performance: Test Chaining Pattern](#ui-test-performance-test-chaining-pattern)
- [Swift Testing Parameterization](#swift-testing-parameterization)

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

## Testing SwiftUI Bindings with ViewInspector

**Problem:** Using `.constant()` bindings in unit tests only verifies view rendering, not two-way data flow.

**Root Cause:** `.constant()` creates an immutable binding - user interactions in tests won't update the value.

```swift
// BAD: This only tests that the view renders without crashing
let view = MyTextField(text: .constant("initial"))
_ = view.body
#expect(someValue == "initial")  // Always true - binding never changes!
```

**Solution:** Use a `BindingTestHarness` pattern:

```swift
// GOOD: This tests actual binding behavior
let harness = BindingTestHarness<String>(value: "initial")
let view = MyTextField(text: harness.binding)

let textField = try view.inspect().find(ViewType.TextField.self)
try textField.setInput("updated")

#expect(harness.value == "updated")  // Binding was updated!
```

**Implementation:** See `FamilyMedicalAppTests/TestHelpers/BindingTestHarness.swift`

```swift
@Observable
final class BindingTestHarness<Value> {
    var value: Value

    init(value: Value) { self.value = value }

    var binding: Binding<Value> {
        Binding(get: { self.value }, set: { self.value = $0 })
    }
}
```

## UI Test Performance: Test Chaining Pattern

**Problem:** UI tests are slow when each test independently navigates and creates test data.

**Solution:** Use test chaining where earlier tests create data that later tests reuse.

**Implementation:**

1. Name tests with numeric prefixes to control execution order: `test1_`, `test2_`, etc.
2. Store shared state in static variables
3. Track navigation state to avoid redundant navigation

```swift
// Static state shared across tests
nonisolated(unsafe) static var isOnTargetScreen = false
nonisolated(unsafe) static var testRecordName = "Test Record"

func test1_CreateTestData() throws {
    navigateToScreen()
    Self.isOnTargetScreen = true
    createRecord(name: Self.testRecordName)
}

func test2_UseTestData() throws {
    // Skip navigation if already there
    if !Self.isOnTargetScreen { navigateToScreen() }

    // Use record created in test1
    tapOnRecord(name: Self.testRecordName)
}
```

**Trade-offs:**

- ✅ ~60% faster execution
- ❌ Tests are interdependent (if test1 fails, test2+ also fail)
- ❌ Less isolation between tests

**When to use:**

- UI test suites taking >5 minutes
- CRUD operation tests that naturally chain together
- When test isolation is less important than speed

**References:**

- Example: `MedicalRecordFlowUITests.swift`

## Swift Testing Parameterization

**Problem:** Manual loops in tests obscure which iteration failed.

```swift
// BAD: If this fails, you don't know which schema type caused it
@Test func testAllSchemaTypes() {
    for schemaType in SchemaType.allCases {
        let view = MyView(type: schemaType)
        _ = view.body
    }
}
```

**Solution:** Use `@Test(arguments:)` for parameterized tests:

```swift
// GOOD: Clear test names like "testSchemaType(vaccine)" in test output
@Test(arguments: SchemaType.allCases)
func testSchemaType(_ schemaType: SchemaType) {
    let view = MyView(type: schemaType)
    _ = view.body
}
```

**Benefits:**

- Clear identification of which case failed
- Parallel execution of independent cases
- Better test reporting in Xcode and CI

**Note:** This requires Swift Testing framework (`import Testing`), not XCTest.
