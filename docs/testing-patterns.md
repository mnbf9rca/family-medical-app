# iOS Testing Patterns

This document captures iOS testing patterns and solutions for common issues.

## Table of Contents

- [XCTest Does NOT Guarantee Test Order](#xctest-does-not-guarantee-test-order)
- [SwiftUI Toggle Not Responding to tap()](#swiftui-toggle-not-responding-to-tap)
- [Password AutoFill Blocking Tests](#password-autofill-blocking-tests)
- [Testing SwiftUI Bindings with ViewInspector](#testing-swiftui-bindings-with-viewinspector)
- [UI Test Performance: Shared Setup Pattern](#ui-test-performance-shared-setup-pattern)
- [Swift Testing Parameterization](#swift-testing-parameterization)

## XCTest Does NOT Guarantee Test Order

**⚠️ Critical:** XCTest does NOT guarantee test execution order. Numeric prefixes like `test1_`, `test2_`, `test3_` do NOT ensure tests run in that sequence.

**Root Cause:** XCTest may run tests in any order depending on:

- Parallel execution settings
- Environment configuration
- Xcode version and simulator state

**What Breaks:**

```swift
// BAD: These tests depend on execution order that isn't guaranteed
func test1_CreateRecord() throws {
    Self.createdRecordId = createRecord()  // Creates state for test2
}

func test2_ViewRecord() throws {
    // WILL FAIL if test1 hasn't run yet!
    viewRecord(id: Self.createdRecordId)
}

func test3_DeleteRecord() throws {
    // WILL FAIL if test1 or test2 haven't run!
    deleteRecord(id: Self.createdRecordId)
}
```

**Solution:** Consolidate interdependent operations into a single test method:

```swift
// GOOD: All CRUD operations in one method - guaranteed execution order
func testRecordCRUDWorkflow() throws {
    // --- Step 1: Create ---
    let recordId = createRecord()
    verifyRecordExists(id: recordId)

    // --- Step 2: View ---
    viewRecord(id: recordId)
    verifyRecordDetails()

    // --- Step 3: Delete ---
    deleteRecord(id: recordId)
    verifyRecordDeleted(id: recordId)
}
```

**Benefits:**

- ✅ Guaranteed execution order within the method
- ✅ No shared mutable state between tests
- ✅ Clear test intent (tests a complete workflow)

**Trade-offs:**

- ❌ Single test failure stops the entire workflow
- ❌ Longer individual test duration
- ❌ Less granular test reporting

**When to use:**

- CRUD operation tests that naturally chain together
- Workflow tests where later steps require earlier steps
- Any scenario where tests share mutable state

**References:**

- `NewUserFlowUITests.swift` - `testPasswordSetupValidation()` consolidates 5 validation checks
- `MedicalRecordFlowUITests.swift` - `testMedicalRecordCRUDWorkflow()` consolidates 5 CRUD operations

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

## UI Test Performance: Shared Setup Pattern

**Problem:** UI tests are slow when each test independently creates accounts and navigates.

**Solution:** Use class-level shared setup for independent tests, and consolidate interdependent tests.

**⚠️ Important:** Do NOT rely on `test1_`, `test2_` prefixes for ordering - see [XCTest Does NOT Guarantee Test Order](#xctest-does-not-guarantee-test-order).

### Pattern 1: Shared Class Setup (Independent Tests)

For tests that don't depend on each other but share expensive setup (e.g., account creation):

```swift
@MainActor
final class MyUITests: XCTestCase {
    nonisolated(unsafe) static var sharedApp: XCUIApplication!
    var app: XCUIApplication { Self.sharedApp }

    nonisolated override class func setUp() {
        super.setUp()
        MainActor.assumeIsolated {
            sharedApp = XCUIApplication()
            sharedApp.launchForUITesting(resetState: true)
            sharedApp.createAccount()  // Expensive operation done once
        }
    }

    func testFeatureA() throws {
        // Uses shared account, tests independently
    }

    func testFeatureB() throws {
        // Uses shared account, tests independently
    }
}
```

### Pattern 2: Consolidated Workflow (Dependent Tests)

For tests that must run in sequence, consolidate into one method:

```swift
func testCompleteWorkflow() throws {
    // All steps execute in guaranteed order
    let record = createRecord()
    verifyRecord(record)
    editRecord(record)
    deleteRecord(record)
}
```

**Trade-offs:**

- ✅ ~60% faster execution with shared setup
- ✅ Guaranteed order with consolidated tests
- ❌ Shared setup: if setUp fails, all tests fail
- ❌ Consolidated tests: less granular reporting

**When to use:**

- Shared setup: Independent tests with expensive common setup
- Consolidated: Tests that must run in sequence

**References:**

- Shared setup: `ExistingUserFlowUITests.swift`, `AddPersonFlowUITests.swift`
- Consolidated: `MedicalRecordFlowUITests.swift`, `NewUserFlowUITests.swift`

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
