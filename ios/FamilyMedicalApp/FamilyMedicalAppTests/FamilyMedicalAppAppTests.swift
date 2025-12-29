import SwiftUI
import Testing
@testable import FamilyMedicalApp

@MainActor
struct FamilyMedicalAppAppTests {
    /// Test app structure initializes
    @Test
    func appInitializes() {
        let app = FamilyMedicalAppApp()
        // App body is always non-nil for SwiftUI apps
        _ = app.body
    }

    /// Test app body is not empty
    @Test
    func appBodyIsNotEmpty() {
        let app = FamilyMedicalAppApp()
        let mirror = Mirror(reflecting: app.body)

        // Verify the app has a non-empty body
        #expect(!mirror.children.isEmpty)
    }
}
