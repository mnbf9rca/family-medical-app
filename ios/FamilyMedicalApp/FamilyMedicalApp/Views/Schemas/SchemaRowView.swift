import SwiftUI

/// Row view for displaying a schema with icon, name, and record count
struct SchemaRowView: View {
    let schema: RecordSchema
    let recordCount: Int

    var body: some View {
        HStack {
            Image(systemName: schema.iconSystemName)
                .foregroundStyle(.tint)
                .frame(width: 30)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(schema.displayName)
                    .font(.body)

                if schema.isBuiltIn {
                    Text("Built-in")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Custom")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }

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
        let typeLabel = schema.isBuiltIn ? "Built-in" : "Custom"
        let countLabel = if recordCount == 0 {
            "no records"
        } else if recordCount == 1 {
            "1 record"
        } else {
            "\(recordCount) records"
        }
        return "\(schema.displayName), \(typeLabel), \(countLabel)"
    }
}

#Preview("Built-in Schemas") {
    List {
        SchemaRowView(
            schema: RecordSchema.builtIn(.vaccine),
            recordCount: 5
        )
        SchemaRowView(
            schema: RecordSchema.builtIn(.condition),
            recordCount: 2
        )
        SchemaRowView(
            schema: RecordSchema.builtIn(.medication),
            recordCount: 0
        )
    }
}

#Preview("Custom Schema") {
    List {
        SchemaRowView(
            schema: RecordSchema(
                unsafeId: "custom-12345678",
                displayName: "Lab Results",
                iconSystemName: "flask",
                fields: [],
                isBuiltIn: false,
                description: "Custom lab results"
            ),
            recordCount: 3
        )
    }
}
