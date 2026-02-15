import SwiftUI

/// Empty state view displayed when there are no records
struct EmptyRecordListView: View {
    // MARK: - Properties

    let schema: RecordSchema
    let onAddTapped: () -> Void

    // MARK: - Body

    var body: some View {
        ContentUnavailableView {
            Label("No \(schema.displayName) Records", systemImage: schema.iconSystemName)
        } description: {
            Text("Add your first \(schema.displayName.lowercased()) record to start tracking.")
        } actions: {
            Button("Add \(schema.displayName)") {
                onAddTapped()
            }
            .buttonStyle(.borderedProminent)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Preview

#Preview {
    EmptyRecordListView(schema: RecordSchema.builtIn(.vaccine)) {}
}

#Preview("Medication") {
    EmptyRecordListView(schema: RecordSchema.builtIn(.medication)) {}
}

#Preview("Condition") {
    EmptyRecordListView(schema: RecordSchema.builtIn(.condition)) {}
}
