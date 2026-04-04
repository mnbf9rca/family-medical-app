import SwiftUI

/// Row view for displaying a record type with icon and count
struct RecordTypeRowView: View {
    let recordType: RecordType
    let recordCount: Int

    var body: some View {
        HStack {
            Image(systemName: recordType.iconSystemName)
                .foregroundStyle(.tint)
                .frame(width: 30)
                .accessibilityHidden(true)

            Text(recordType.displayName)
                .font(.body)

            Spacer()

            if recordCount > 0 {
                Text("\(recordCount)")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var accessibilityDescription: String {
        if recordCount == 0 {
            "\(recordType.displayName), no records"
        } else if recordCount == 1 {
            "\(recordType.displayName), 1 record"
        } else {
            "\(recordType.displayName), \(recordCount) records"
        }
    }
}

#Preview {
    List {
        RecordTypeRowView(recordType: .immunization, recordCount: 3)
        RecordTypeRowView(recordType: .condition, recordCount: 1)
        RecordTypeRowView(recordType: .medicationStatement, recordCount: 0)
    }
}
