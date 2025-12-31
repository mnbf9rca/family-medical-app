import SwiftUI

/// Empty state view shown when there are no members
struct EmptyMembersView: View {
    let onAddTapped: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("No Members", systemImage: "person.3")
        } description: {
            Text("Add your first member to start tracking medical records.")
        } actions: {
            Button("Add Member") {
                onAddTapped()
            }
            .buttonStyle(.borderedProminent)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No members. Add your first member to start tracking medical records.")
        .accessibilityHint("Double tap the Add Member button to create a new member")
    }
}

#Preview {
    EmptyMembersView {
        // Preview action
    }
}
