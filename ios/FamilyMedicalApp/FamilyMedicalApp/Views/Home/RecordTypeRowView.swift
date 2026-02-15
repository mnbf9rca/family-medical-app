import SwiftUI

/// Row view for displaying a record type with icon and count
struct RecordTypeRowView: View {
    let schema: RecordSchema
    let recordCount: Int

    var body: some View {
        HStack {
            Image(systemName: schema.iconSystemName)
                .foregroundStyle(.tint)
                .frame(width: 30)
                .accessibilityHidden(true)

            Text(schema.displayName)
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
            "\(schema.displayName), no records"
        } else if recordCount == 1 {
            "\(schema.displayName), 1 record"
        } else {
            "\(schema.displayName), \(recordCount) records"
        }
    }
}

#Preview("With Records") {
    List {
        RecordTypeRowView(schema: RecordSchema.builtIn(.vaccine), recordCount: 3)
        RecordTypeRowView(schema: RecordSchema.builtIn(.condition), recordCount: 1)
        RecordTypeRowView(schema: RecordSchema.builtIn(.medication), recordCount: 5)
        RecordTypeRowView(schema: RecordSchema.builtIn(.allergy), recordCount: 2)
        RecordTypeRowView(schema: RecordSchema.builtIn(.note), recordCount: 10)
    }
}

#Preview("Without Records") {
    List {
        RecordTypeRowView(schema: RecordSchema.builtIn(.vaccine), recordCount: 0)
        RecordTypeRowView(schema: RecordSchema.builtIn(.condition), recordCount: 0)
        RecordTypeRowView(schema: RecordSchema.builtIn(.medication), recordCount: 0)
    }
}
