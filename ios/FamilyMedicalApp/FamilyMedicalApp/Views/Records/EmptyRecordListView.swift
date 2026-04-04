import SwiftUI

/// Empty state view displayed when there are no records.
/// The "Add" button is intentionally omitted until GenericRecordFormView
/// lands in #127 — we don't ship buttons that do nothing.
struct EmptyRecordListView: View {
    let recordType: RecordType

    var body: some View {
        ContentUnavailableView(
            "No \(recordType.displayName) Records",
            systemImage: recordType.iconSystemName,
            description: Text("Adding \(recordType.displayName.lowercased()) records is coming soon.")
        )
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    EmptyRecordListView(recordType: .immunization)
}
