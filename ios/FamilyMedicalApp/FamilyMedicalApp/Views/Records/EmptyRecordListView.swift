import SwiftUI

/// Empty state view displayed when there are no records
struct EmptyRecordListView: View {
    // MARK: - Properties

    let schemaType: BuiltInSchemaType
    let onAddTapped: () -> Void

    // MARK: - Body

    var body: some View {
        ContentUnavailableView {
            Label("No \(schemaType.displayName) Records", systemImage: schemaType.iconSystemName)
        } description: {
            Text("Add your first \(schemaType.displayName.lowercased()) record to start tracking.")
        } actions: {
            Button("Add \(schemaType.displayName)") {
                onAddTapped()
            }
            .buttonStyle(.borderedProminent)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Preview

#Preview {
    EmptyRecordListView(schemaType: .vaccine) {}
}

#Preview("Medication") {
    EmptyRecordListView(schemaType: .medication) {}
}

#Preview("Condition") {
    EmptyRecordListView(schemaType: .condition) {}
}
