import SwiftUI

/// Row view for displaying a record type with icon and count
struct RecordTypeRowView: View {
    let schemaType: BuiltInSchemaType
    let recordCount: Int

    var body: some View {
        HStack {
            Image(systemName: schemaType.iconSystemName)
                .foregroundStyle(.tint)
                .frame(width: 30)
                .accessibilityHidden(true)

            Text(schemaType.displayName)
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
            "\(schemaType.displayName), no records"
        } else if recordCount == 1 {
            "\(schemaType.displayName), 1 record"
        } else {
            "\(schemaType.displayName), \(recordCount) records"
        }
    }
}

#Preview("With Records") {
    List {
        RecordTypeRowView(schemaType: .vaccine, recordCount: 3)
        RecordTypeRowView(schemaType: .condition, recordCount: 1)
        RecordTypeRowView(schemaType: .medication, recordCount: 5)
        RecordTypeRowView(schemaType: .allergy, recordCount: 2)
        RecordTypeRowView(schemaType: .note, recordCount: 10)
    }
}

#Preview("Without Records") {
    List {
        RecordTypeRowView(schemaType: .vaccine, recordCount: 0)
        RecordTypeRowView(schemaType: .condition, recordCount: 0)
        RecordTypeRowView(schemaType: .medication, recordCount: 0)
    }
}
