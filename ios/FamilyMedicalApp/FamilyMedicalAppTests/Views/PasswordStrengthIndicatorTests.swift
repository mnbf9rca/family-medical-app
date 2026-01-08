import SwiftUI
import Testing
import ViewInspector
@testable import FamilyMedicalApp

/// Tests for PasswordStrengthIndicator rendering logic
@MainActor
struct PasswordStrengthIndicatorTests {
    // MARK: - View Body Tests

    @Test
    func passwordStrengthIndicatorRendersWeak() throws {
        let view = PasswordStrengthIndicator(strength: .weak)

        // Verify structure and weak label
        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.VStack.self)
        _ = try inspected.find(ViewType.HStack.self)
        let strengthText = try inspected.find(text: "Weak")
        #expect(try strengthText.string() == "Weak")
    }

    @Test
    func passwordStrengthIndicatorRendersFair() throws {
        let view = PasswordStrengthIndicator(strength: .fair)

        // Verify structure and fair label
        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.VStack.self)
        let strengthText = try inspected.find(text: "Fair")
        #expect(try strengthText.string() == "Fair")
    }

    @Test
    func passwordStrengthIndicatorRendersGood() throws {
        let view = PasswordStrengthIndicator(strength: .good)

        // Verify structure and good label
        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.VStack.self)
        let strengthText = try inspected.find(text: "Good")
        #expect(try strengthText.string() == "Good")
    }

    @Test
    func passwordStrengthIndicatorRendersStrong() throws {
        let view = PasswordStrengthIndicator(strength: .strong)

        // Verify structure and strong label
        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.VStack.self)
        let strengthText = try inspected.find(text: "Strong")
        #expect(try strengthText.string() == "Strong")
    }

    @Test
    func passwordStrengthIndicatorShowsIndicatorBar() throws {
        let view = PasswordStrengthIndicator(strength: .good)

        // Verify the strength indicator contains an HStack for the bar segments
        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.HStack.self)
        // Note: ViewInspector doesn't support inspecting Rectangle/Shape primitives
        // The presence of HStack confirms the indicator bar structure exists
    }
}
