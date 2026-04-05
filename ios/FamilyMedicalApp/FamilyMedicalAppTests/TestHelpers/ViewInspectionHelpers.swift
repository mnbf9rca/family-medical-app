import SwiftUI
import ViewInspector

/// Host a SwiftUI view in a real window, inspect it, and clean up.
///
/// Used for views that use `@State` or `@FocusState`. Calling `.inspect()` directly on
/// such a view produces the runtime warning:
/// `Accessing State's value outside of being installed on a View. This will result in a
/// constant Binding of the initial value and will not update.`
///
/// `ViewHosting.host(view:)` installs the view into a `UIWindow` and reduces (but does
/// not fully eliminate) these warnings. Some warnings persist because ViewInspector
/// inspects the view value directly via `Mirror`, while SwiftUI's state storage is keyed
/// to the hosted instance. For the purposes of unit tests this is cosmetic — assertions
/// are checked against the rendered view structure, which is correct. When Swift Testing
/// gains a clean async-callback pattern similar to XCTest's `expectation`, tests can
/// migrate to `view.on(\.didAppear) { ... }` to eliminate the remaining warnings.
@MainActor
enum HostedInspection {
    /// Host the view, invoke the inspection closure, and expel. Returns the closure's result.
    /// - Parameters:
    ///   - view: The view to host and inspect.
    ///   - perform: Closure that receives the view and performs ViewInspector assertions.
    static func inspect<V: View, T>(
        _ view: V,
        _ perform: (V) throws -> T
    ) rethrows -> T {
        ViewHosting.host(view: view)
        defer { ViewHosting.expel() }
        return try perform(view)
    }
}
