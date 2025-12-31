import SwiftUI

/// Read-only display of a medical record field value
///
/// This component renders field values for viewing in detail screens.
/// It uses `LabeledContent` for consistent formatting across the app.
struct FieldDisplayView: View {
    // MARK: - Properties

    let field: FieldDefinition
    let value: FieldValue?

    // MARK: - Body

    var body: some View {
        LabeledContent {
            valueView
        } label: {
            Text(field.displayName)
                .accessibilityLabel(field.displayName)
        }
    }

    // MARK: - Value Views

    @ViewBuilder private var valueView: some View {
        if let value {
            switch value {
            case let .string(str):
                Text(str)

            case let .int(num):
                Text("\(num)")

            case let .double(num):
                Text(num, format: .number.precision(.fractionLength(0 ... 2)))

            case let .bool(flag):
                Label {
                    Text(flag ? "Yes" : "No")
                } icon: {
                    Image(systemName: flag ? "checkmark.circle.fill" : "xmark.circle")
                        .foregroundStyle(flag ? .green : .secondary)
                }

            case let .date(date):
                Text(date, style: .date)

            case let .attachmentIds(ids):
                if ids.isEmpty {
                    emptyValueView
                } else {
                    Text("\(ids.count) attachment\(ids.count == 1 ? "" : "s")")
                }

            case let .stringArray(array):
                if array.isEmpty {
                    emptyValueView
                } else {
                    Text(array.joined(separator: ", "))
                }
            }
        } else {
            emptyValueView
        }
    }

    private var emptyValueView: some View {
        Text("-")
            .foregroundStyle(.secondary)
            .italic()
    }
}

// MARK: - Preview

#Preview {
    List {
        Section("String Value") {
            FieldDisplayView(
                field: FieldDefinition(
                    id: "vaccineName",
                    displayName: "Vaccine Name",
                    fieldType: .string
                ),
                value: .string("COVID-19 Pfizer")
            )
        }

        Section("Int Value") {
            FieldDisplayView(
                field: FieldDefinition(
                    id: "doseNumber",
                    displayName: "Dose Number",
                    fieldType: .int
                ),
                value: .int(2)
            )
        }

        Section("Double Value") {
            FieldDisplayView(
                field: FieldDefinition(
                    id: "temperature",
                    displayName: "Temperature",
                    fieldType: .double
                ),
                value: .double(98.6)
            )
        }

        Section("Bool Value - True") {
            FieldDisplayView(
                field: FieldDefinition(
                    id: "isActive",
                    displayName: "Is Active",
                    fieldType: .bool
                ),
                value: .bool(true)
            )
        }

        Section("Bool Value - False") {
            FieldDisplayView(
                field: FieldDefinition(
                    id: "isActive",
                    displayName: "Is Active",
                    fieldType: .bool
                ),
                value: .bool(false)
            )
        }

        Section("Date Value") {
            FieldDisplayView(
                field: FieldDefinition(
                    id: "dateAdministered",
                    displayName: "Date Administered",
                    fieldType: .date
                ),
                value: .date(Date())
            )
        }

        Section("Attachment IDs") {
            FieldDisplayView(
                field: FieldDefinition(
                    id: "attachmentIds",
                    displayName: "Attachments",
                    fieldType: .attachmentIds
                ),
                value: .attachmentIds([UUID(), UUID(), UUID()])
            )
        }

        Section("String Array") {
            FieldDisplayView(
                field: FieldDefinition(
                    id: "tags",
                    displayName: "Tags",
                    fieldType: .stringArray
                ),
                value: .stringArray(["Important", "Follow-up", "Chronic"])
            )
        }

        Section("Empty Value") {
            FieldDisplayView(
                field: FieldDefinition(
                    id: "notes",
                    displayName: "Notes",
                    fieldType: .string
                ),
                value: nil
            )
        }
    }
}
