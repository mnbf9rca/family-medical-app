import SwiftUI

/// A test harness for views with bindings that allows testing two-way data flow
///
/// ## Problem
/// Using `.constant()` bindings in unit tests only verifies that a view renders without crashing.
/// It does NOT test that user input updates the bound value, because `.constant()` creates
/// an immutable binding.
///
/// ## Solution
/// Use `BindingTestHarness` to create mutable bindings that capture value changes:
///
/// ```swift
/// // Create harness with initial value
/// let harness = BindingTestHarness<String>(value: "initial")
///
/// // Pass binding to view
/// let view = MyTextField(text: harness.binding)
///
/// // Simulate user input via ViewInspector
/// let textField = try view.inspect().find(ViewType.TextField.self)
/// try textField.setInput("updated")
///
/// // Verify binding was updated
/// #expect(harness.value == "updated")
/// ```
///
/// ## Thread Safety
/// Marked `@unchecked Sendable` because:
/// - Test-only helper, never used in production code
/// - All usage is single-threaded within XCTest (tests run serially on main thread)
/// - The mutable state (`value`) is only accessed synchronously via the binding
@Observable
final class BindingTestHarness<Value>: @unchecked Sendable {
    /// The current value, updated when the binding's setter is called
    var value: Value

    /// Creates a harness with an initial value
    /// - Parameter value: The initial value for the binding
    init(value: Value) {
        self.value = value
    }

    /// A mutable binding that reads and writes to `value`
    var binding: Binding<Value> {
        Binding(
            get: { self.value },
            set: { self.value = $0 }
        )
    }
}
