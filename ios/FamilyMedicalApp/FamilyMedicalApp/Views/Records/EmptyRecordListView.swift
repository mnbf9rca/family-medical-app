import SwiftUI

/// Empty state view displayed when there are no records
struct EmptyRecordListView: View {
    let recordType: RecordType
    let onAddTapped: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("No \(recordType.displayName) Records", systemImage: recordType.iconSystemName)
        } description: {
            Text("Add your first \(recordType.displayName.lowercased()) record to start tracking.")
        } actions: {
            Button("Add \(recordType.displayName)") {
                onAddTapped()
            }
            .buttonStyle(.borderedProminent)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    EmptyRecordListView(recordType: .immunization) {}
}
