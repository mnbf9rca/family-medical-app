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
    func passwordStrengthIndicatorShowsRectangles() throws {
        let view = PasswordStrengthIndicator(strength: .good)

        // Verify HStack contains Rectangle indicators
        let inspected = try view.inspect()
        let hstack = try inspected.find(ViewType.HStack.self)
        let rectangles = hstack.findAll(ViewType.Rectangle.self)
        #expect(rectangles.count == 4) // Always 4 strength indicators
    }
}
