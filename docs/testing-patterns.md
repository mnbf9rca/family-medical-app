# iOS Testing Patterns

This document captures iOS testing patterns and solutions for common issues.

## Table of Contents

- [Deterministic Element Checking](#deterministic-element-checking)
- [UI Test Structure](#ui-test-structure)
- [SwiftUI View Testing Strategy](#swiftui-view-testing-strategy)
- [SwiftUI Toggle Not Responding to tap()](#swiftui-toggle-not-responding-to-tap)
- [Password AutoFill Blocking Tests](#password-autofill-blocking-tests)
- [Testing SwiftUI Bindings with ViewInspector](#testing-swiftui-bindings-with-viewinspector)
- [Swift Testing Parameterization](#swift-testing-parameterization)
- [Deterministic Testing with swift-dependencies](#deterministic-testing-with-swift-dependencies)

## Deterministic Element Checking

**⚠️ Critical:** Tests must be deterministic - they should either fully execute or fail, never silently skip sections.

### Anti-Pattern: Conditional Assertions

```swift
// BAD: Silently skips assertions if element doesn't appear
if button.waitForExistence(timeout: 2) {
    button.tap()
    XCTAssertTrue(result.exists)  // Never executes if button wasn't found!
}

// BAD: Silent skip, no assertion
if cancelButton.exists {
    cancelButton.tap()
}
```

**Problem:** These patterns cause:

- Different code coverage between CI and local runs (timing differences)
- False confidence - tests pass even when critical functionality is broken
- Flaky tests that sometimes pass, sometimes fail

### Solution: Assert-First Pattern

```swift
// GOOD: Test fails immediately if button doesn't exist
XCTAssertTrue(button.waitForExistence(timeout: 5), "Button should exist")
button.tap()
XCTAssertTrue(result.exists, "Result should appear")
```

### Solution: Dismiss Helper for Cleanup

For dismissing modals/sheets/menus, use the `dismissCurrentView()` helper instead of conditional logic:

```swift
// BAD: Silent skip if Cancel doesn't exist
if cancelButton.exists {
    cancelButton.tap()
}

// GOOD: Helper tries multiple strategies
app.dismissCurrentView()
```

The helper (`UITestHelpers.swift`) tries multiple dismiss strategies in order:

1. Cancel button
2. Close button
3. Done button
4. Swipe down (for sheets)
5. Tap outside (for popovers)

**Caveat:** `dismissCurrentView()` uses `swipeDown` as a fallback (strategy 4), which scrolls the underlying `Form`. Since `Form` is backed by a lazy container, this can remove off-screen elements from the accessibility tree. For dismissing menus over a Form, use a direct coordinate tap instead: `app.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.05)).tap()`.

### When Conditional Logic IS Appropriate

Conditional logic is acceptable in `setUp`/`tearDown` for cleanup, not assertions:

```swift
override func setUpWithError() throws {
    // OK: Cleanup code - we're clearing residual state, not testing
    if app.alerts.firstMatch.waitForExistence(timeout: 1) {
        app.alerts.buttons["OK"].tap()
    }

    // REQUIRED: Final state assertion ensures deterministic starting point
    XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 5))
}
```

### Timeout Guidelines

CI environments are slower than local development machines. Use appropriate timeouts:

| Scenario | Timeout |
|----------|---------|
| Critical elements (buttons, forms) | 5 seconds |
| Secondary elements | 3 seconds |
| Quick checks in fallback logic | 0.5-1 second |
| Setup cleanup | 1-2 seconds |

### Hittability vs Existence

`waitForExistence` only checks the accessibility tree — an element can "exist" before its layout position has stabilized. For elements you need to tap, use `waitUntilHittable` (in `UITestHelpers.swift`) which polls for both `exists` and `isHittable`:

```swift
// BAD: Element may exist but not be at stable coordinates yet
XCTAssertTrue(button.waitForExistence(timeout: 5))
button.tap()  // May tap stale coordinates on slow CI

// GOOD: Ensures element is visible and at correct position
XCTAssertTrue(button.waitUntilHittable(timeout: 5), "Button should be hittable")
button.tap()
```

Animations are disabled during UI testing (`UIView.setAnimationsEnabled(false)` in `FamilyMedicalAppApp.init()`) to reduce timing variance, but `waitUntilHittable` remains the safest pattern for tap targets.

**References:**

- Helper implementation: `FamilyMedicalAppUITests/Helpers/UITestHelpers.swift`
- Example: `AttachmentFlowUITests.swift` - deterministic attachment flow testing

## UI Test Structure

### XCTest Does NOT Guarantee Test Order

**⚠️ Critical:** XCTest does NOT guarantee test execution order. Numeric prefixes like `test1_`, `test2_`, `test3_` do NOT ensure tests run in that sequence.

XCTest may run tests in any order depending on parallel execution settings, environment configuration, and Xcode version.

```swift
// BAD: These tests depend on execution order that isn't guaranteed
func test1_CreateRecord() throws {
    Self.createdRecordId = createRecord()
}

func test2_ViewRecord() throws {
    viewRecord(id: Self.createdRecordId)  // WILL FAIL if test1 hasn't run!
}
```

### Pattern 1: Consolidated Workflow (Dependent Tests)

For tests that must run in sequence, consolidate into one method:

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

### Pattern 2: Shared Class Setup (Independent Tests)

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

### Trade-offs

| Pattern | Pros | Cons |
|---------|------|------|
| Consolidated workflow | Guaranteed order, no shared state | Single failure stops workflow, less granular reporting |
| Shared class setup | ~60% faster, reuses expensive setup | If setUp fails, all tests fail |

**When to use:**

- Consolidated: CRUD workflows, tests that share mutable state
- Shared setup: Independent tests with expensive common setup

**References:**

- Consolidated: `MedicalRecordFlowUITests.swift`, `NewUserFlowUITests.swift`, `BackupFlowUITests.swift`
- Shared setup: `ExistingUserFlowUITests.swift`, `AddPersonFlowUITests.swift`

## SwiftUI View Testing Strategy

### The Problem

SwiftUI view coverage varies between local and CI environments (often 5-10% lower in CI) because:

1. **Body closures execute during rendering** - timing differs between environments
2. **Sheet/button closures are untestable** - they only execute when SwiftUI presents UI at runtime
3. **UI tests run in separate process** - coverage depends on what actually renders

### Architecture: Keep Closures Thin

Closures inside `.sheet()`, `.fullScreenCover()`, and `Button { }` cannot be tested with ViewInspector. Keep them to 1-3 lines that only call ViewModel methods:

```swift
// BAD: Complex logic in closure - untestable
.sheet(isPresented: $viewModel.showingPicker) {
    DocumentPicker(onPicked: { urls in
        for url in urls {
            let data = try? Data(contentsOf: url)  // ← Can't test this
            let processed = processData(data)       // ← Or this
            viewModel.items.append(processed)       // ← Or this
        }
    })
}

// GOOD: Thin closure, logic in ViewModel
.sheet(isPresented: $viewModel.showingPicker) {
    DocumentPicker(onPicked: { urls in
        Task { await viewModel.addFromDocumentPicker(urls) }  // ← Tested in VM
    })
}
```

### Technique: Use ViewInspector find()

For conditional view elements, use `find()` not just `inspect()` to verify branches executed:

```swift
// BAD: Just calls inspect() without exercising branches
@Test
func viewRendersWhileLoading() throws {
    let viewModel = makeViewModel()
    viewModel.isLoading = true
    let view = MyView(viewModel: viewModel)
    _ = try view.inspect()  // Only verifies no crash
}

// GOOD: Finds the element to verify the branch executed
@Test
func viewRendersWhileLoading() throws {
    let viewModel = makeViewModel()
    viewModel.isLoading = true
    let view = MyView(viewModel: viewModel)
    let inspected = try view.inspect()
    _ = try inspected.find(ViewType.ProgressView.self)  // Branch verified!
}

// GOOD: Also test the negative case
@Test
func viewHidesLoadingWhenNotLoading() throws {
    let viewModel = makeViewModel()
    viewModel.isLoading = false
    let view = MyView(viewModel: viewModel)
    let inspected = try view.inspect()
    #expect(throws: (any Error).self) {
        _ = try inspected.find(ViewType.ProgressView.self)  // Should NOT exist
    }
}
```

**Key insight:** ViewInspector's `find()` forces the view to evaluate its body immediately and synchronously - no timing dependency.

### When Coverage Exceptions Are Acceptable

If a view's coverage is below 85% but:

1. The uncovered code is only thin closures (1-3 lines)
2. Those closures only call ViewModel methods
3. The ViewModel methods are tested (75-100% coverage)

Then add a coverage exception in `scripts/check-coverage.sh` with a comment explaining why.

**References:**

- [Swift by Sundell: Writing testable code with SwiftUI](https://www.swiftbysundell.com/articles/writing-testable-code-when-using-swiftui/)
- [SwiftUI Testing: A Pragmatic Approach](https://betterprogramming.pub/swiftui-testing-a-pragmatic-approach-aeb832107fe7)
- Example: `AttachmentPickerViewTests.swift`, `AttachmentPickerView.swift`

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

## Deterministic Testing with swift-dependencies

**Problem:** Tests that depend on `Date()`, `UUID()`, or `Task.sleep` timing are non-deterministic - they may pass locally but fail in CI due to timing differences.

```swift
// BAD: Non-deterministic date comparison
let viewModel = MedicalRecordFormViewModel(person: person, schema: schema)
let dateValue = viewModel.fieldValues[dateFieldId]?.dateValue
let timeDifference = abs(dateValue!.timeIntervalSinceNow)
#expect(timeDifference < 1.0)  // Flaky! Could fail if system is slow

// BAD: Timing dependency with Task.sleep
view.deletePerson(at: offsets)
try await Task.sleep(for: .milliseconds(100))  // Flaky! May not be enough
#expect(viewModel.persons.count == 1)
```

**Solution:** Use `swift-dependencies` library to inject controllable system dependencies.

### ViewModels: Using @Dependency

Add controllable dependencies to ViewModels:

```swift
import Dependencies

@MainActor
@Observable
final class MedicalRecordFormViewModel {
    // Use @ObservationIgnored to prevent observation tracking of dependency
    @ObservationIgnored @Dependency(\.date) private var date

    init(/* ... */) {
        // Initialize all stored properties FIRST
        self.medicalRecordRepository = medicalRecordRepository ?? MedicalRecordRepository()
        // ... other properties

        // THEN access dependencies (after self is fully initialized)
        for field in schema.fields where field.fieldType == .date {
            initialValues[field.id.uuidString] = .date(date.now)
        }
    }
}
```

**⚠️ Swift Initialization Rule:** You must initialize all stored properties before accessing `@Dependency` because property wrappers require `self` to be available.

### Available Dependencies

| Dependency | Usage | Test Value |
|------------|-------|------------|
| `@Dependency(\.date)` | `date.now` for current date | `.constant(fixedDate)` |
| `@Dependency(\.uuid)` | `uuid()` for new UUID | `.incrementing` |
| `@Dependency(\.continuousClock)` | `clock.sleep(for:)` instead of `Task.sleep` | `.immediate` |

### Tests: Using withDependencies

Override dependencies for deterministic testing:

```swift
import Dependencies

@Test
func initializesDateFieldsWithTodayForNewRecord() throws {
    let fixedDate = Date(timeIntervalSinceReferenceDate: 1_234_567_890)

    let viewModel = withDependencies {
        $0.date = .constant(fixedDate)
    } operation: {
        MedicalRecordFormViewModel(person: person, schema: schema)
    }

    // Now we can assert exact equality!
    let dateValue = viewModel.fieldValues[requiredDateFieldId]?.dateValue
    #expect(dateValue == fixedDate)
}
```

### Testing with continuousClock

For ViewModels that use `Task.sleep` for debouncing, delays, or animations, use `@Dependency(\.continuousClock)` to make tests instant:

**ViewModel Implementation:**

```swift
import Dependencies

@MainActor
@Observable
final class SearchViewModel {
    @ObservationIgnored @Dependency(\.continuousClock) private var clock

    func search(query: String) async {
        // Debounce: wait before executing search
        try? await clock.sleep(for: .milliseconds(300))
        await performSearch(query)
    }
}
```

**Test with ImmediateClock:**

```swift
@Test
func searchExecutesAfterDebounce() async throws {
    let viewModel = withDependencies {
        $0.continuousClock = ImmediateClock()  // Makes sleep instant!
    } operation: {
        SearchViewModel()
    }

    await viewModel.search(query: "test")

    // No actual waiting - ImmediateClock makes sleep return immediately
    #expect(viewModel.searchResults.isEmpty == false)
}
```

**Benefits:**

- Tests run instantly instead of waiting for real delays
- Eliminates timing-based flakiness
- Tests are deterministic across local/CI environments

### Alternative: Await Async Operations Directly

For tests that use `Task.sleep` to wait for async operations, prefer calling the ViewModel method directly:

```swift
// BAD: Sleep hoping async operation completes
view.deletePerson(at: offsets)
try await Task.sleep(for: .milliseconds(100))
#expect(viewModel.persons.count == 1)

// GOOD: Call ViewModel directly and await
let personToDelete = viewModel.persons[0]
await viewModel.deletePerson(id: personToDelete.id)
#expect(viewModel.persons.count == 1)
```

### Security Constraint

**⚠️ Do NOT wrap crypto services with swift-dependencies.**

Per ADR-0002 through ADR-0005, only wrap system dependencies:

- ✅ Date, UUID, Clock
- ❌ EncryptionService, FamilyMemberKeyService, PrimaryKeyProvider

Crypto services must use the existing optional-parameter DI pattern per ADR-0008.

**References:**

- [swift-dependencies GitHub](https://github.com/pointfreeco/swift-dependencies)
- ADR-0010: Deterministic Testing Architecture
- Example: `MedicalRecordFormViewModelTests.swift`, `HomeViewTests.swift`
