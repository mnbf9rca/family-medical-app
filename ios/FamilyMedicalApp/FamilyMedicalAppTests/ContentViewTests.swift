import SwiftUI
import Testing
@testable import FamilyMedicalApp

struct ContentViewTests {
    /// Test ContentView renders without crashing
    @Test
    func contentViewRenders() {
        let view = ContentView()
        #expect(view.body != nil)
    }

    /// Test ContentView contains expected elements
    @Test
    func contentViewContainsElements() {
        let view = ContentView()
        let mirror = Mirror(reflecting: view.body)

        // Verify the view has a body (VStack)
        #expect(!mirror.children.isEmpty)
    }
}
