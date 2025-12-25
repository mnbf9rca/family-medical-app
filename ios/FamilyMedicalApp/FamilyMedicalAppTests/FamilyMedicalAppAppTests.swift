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

    /// Test app body is not empty
    @Test
    func appBodyIsNotEmpty() {
        let app = FamilyMedicalAppApp()
        let mirror = Mirror(reflecting: app.body)

        // Verify the app has a non-empty body
        #expect(!mirror.children.isEmpty)
    }
}
