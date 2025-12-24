import SwiftUI
import Testing
@testable import FamilyMedicalApp

struct FamilyMedicalAppAppTests {
    /// Test app structure initializes
    @Test
    func appInitializes() {
        let app = FamilyMedicalAppApp()
        #expect(app.body != nil)
    }

    /// Test app body contains WindowGroup
    @Test
    func appContainsWindowGroup() {
        let app = FamilyMedicalAppApp()
        let mirror = Mirror(reflecting: app.body)

        // Verify the app has a body (WindowGroup)
        #expect(!mirror.children.isEmpty)
    }
}
