import SwiftUI
import Testing
@testable import FamilyMedicalApp

struct ContentViewTests {
    /// Test ContentView renders without crashing
    @Test
    func contentViewRenders() {
        let view = ContentView()
        // View body is always non-nil for SwiftUI views
        _ = view.body
    }

    /// Test ContentView body is not empty
    @Test
    func contentViewBodyIsNotEmpty() {
        let view = ContentView()
        let mirror = Mirror(reflecting: view.body)

        // Verify the view has a non-empty body
        #expect(!mirror.children.isEmpty)
    }
}
