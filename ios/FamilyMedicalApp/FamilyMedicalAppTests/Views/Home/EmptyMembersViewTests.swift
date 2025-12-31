import SwiftUI
import Testing
import ViewInspector
@testable import FamilyMedicalApp

@MainActor
struct EmptyMembersViewTests {
    // MARK: - Content Tests

    @Test
    func viewDisplaysCorrectly() throws {
        var tapped = false
        let view = EmptyMembersView {
            tapped = true
        }

        // View should render without crashing
        _ = try view.inspect()
        #expect(tapped == false) // Not tapped yet
    }

    // MARK: - Button Action Tests

    @Test
    func buttonTapCallsCallback() throws {
        var tapped = false
        let view = EmptyMembersView {
            tapped = true
        }

        let contentView = try view.inspect().contentUnavailableView()
        let button = try contentView.find(button: "Add Member")
        try button.tap()

        #expect(tapped == true)
    }

    @Test
    func buttonIsRendered() throws {
        let view = EmptyMembersView {}
        let contentView = try view.inspect().contentUnavailableView()
        let button = try contentView.find(button: "Add Member")
        let buttonText = try button.labelView().text().string()
        #expect(buttonText == "Add Member")
    }
}
