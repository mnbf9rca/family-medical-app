import SwiftUI

/// Read-only display of a medical record field value
///
/// This component renders field values for viewing in detail screens.
/// It uses `LabeledContent` for consistent formatting across the app.
///
/// Uses `FieldDisplayFormatter` for formatting logic, enabling unit testing.
struct FieldDisplayView: View {
    // MARK: - Properties

    let field: FieldDefinition
    let value: FieldValue?

    /// Person ID for attachment viewing (required for .attachmentIds fields)
    var personId: UUID?

    /// Pre-loaded attachments for display
    var attachments: [Attachment]

    /// Callback when an attachment is tapped
    var onAttachmentTap: ((Attachment) -> Void)?

    // MARK: - Initialization

    init(
        field: FieldDefinition,
        value: FieldValue?,
        personId: UUID? = nil,
        attachments: [Attachment] = [],
        onAttachmentTap: ((Attachment) -> Void)? = nil
    ) {
        self.field = field
        self.value = value
        self.personId = personId
        self.attachments = attachments
        self.onAttachmentTap = onAttachmentTap
    }

    /// Computed formatted value using FieldDisplayFormatter
    private var formattedValue: FormattedFieldValue {
        FieldDisplayFormatter.format(value, attachments: attachments)
    }

    // MARK: - Body

    var body: some View {
        LabeledContent {
            valueView
                .accessibilityIdentifier("fieldValue")
        } label: {
            Text(field.displayName)
                .accessibilityLabel(field.displayName)
                .accessibilityIdentifier("fieldLabel")
        }
    }

    // MARK: - Value Views

    @ViewBuilder private var valueView: some View {
        switch formattedValue {
        case let .text(str):
            Text(str)

        case let .boolDisplay(text, isTrue):
            Label {
                Text(text)
            } icon: {
                Image(systemName: isTrue ? "checkmark.circle.fill" : "xmark.circle")
                    .foregroundStyle(isTrue ? .green : .secondary)
            }

        case let .date(date):
            Text(date, style: .date)

        case let .attachmentCount(count):
            Text(FieldDisplayFormatter.attachmentCountText(count))

        case .attachmentGrid:
            attachmentThumbnailGrid

        case .empty:
            emptyValueView
        }
    }

    private var emptyValueView: some View {
        Text("-")
            .foregroundStyle(.secondary)
            .italic()
    }

    /// Thumbnail grid for displaying attachments
    private var attachmentThumbnailGrid: some View {
        let columns = [GridItem(.adaptive(minimum: 50, maximum: 60), spacing: 6)]

        return LazyVGrid(columns: columns, alignment: .trailing, spacing: 6) {
            ForEach(attachments) { attachment in
                AttachmentThumbnailView(
                    attachment: attachment,
                    onTap: {
                        onAttachmentTap?(attachment)
                    },
                    onRemove: nil, // Read-only in display view
                    size: 50
                )
            }
        }
    }
}

// MARK: - Preview

#Preview {
    List {
        Section("String Value") {
            FieldDisplayView(
                field: .builtIn(
                    id: BuiltInFieldIds.Vaccine.name,
                    displayName: "Vaccine Name",
                    fieldType: .string
                ),
                value: .string("COVID-19 Pfizer")
            )
        }

        Section("Int Value") {
            FieldDisplayView(
                field: .builtIn(
                    id: BuiltInFieldIds.Vaccine.doseNumber,
                    displayName: "Dose Number",
                    fieldType: .int
                ),
                value: .int(2)
            )
        }

        Section("Double Value") {
            FieldDisplayView(
                field: .builtIn(
                    id: UUID(), // Random UUID for preview
                    displayName: "Temperature",
                    fieldType: .double
                ),
                value: .double(98.6)
            )
        }

        Section("Bool Value - True") {
            FieldDisplayView(
                field: .builtIn(
                    id: UUID(), // Random UUID for preview
                    displayName: "Is Active",
                    fieldType: .bool
                ),
                value: .bool(true)
            )
        }

        Section("Bool Value - False") {
            FieldDisplayView(
                field: .builtIn(
                    id: UUID(), // Random UUID for preview
                    displayName: "Is Active",
                    fieldType: .bool
                ),
                value: .bool(false)
            )
        }

        Section("Date Value") {
            FieldDisplayView(
                field: .builtIn(
                    id: BuiltInFieldIds.Vaccine.dateAdministered,
                    displayName: "Date Administered",
                    fieldType: .date
                ),
                value: .date(Date())
            )
        }

        Section("Attachment IDs") {
            FieldDisplayView(
                field: .builtIn(
                    id: BuiltInFieldIds.Vaccine.attachmentIds,
                    displayName: "Attachments",
                    fieldType: .attachmentIds
                ),
                value: .attachmentIds([UUID(), UUID(), UUID()])
            )
        }

        Section("String Array") {
            FieldDisplayView(
                field: .builtIn(
                    id: UUID(), // Random UUID for preview
                    displayName: "Tags",
                    fieldType: .stringArray
                ),
                value: .stringArray(["Important", "Follow-up", "Chronic"])
            )
        }

        Section("Empty Value") {
            FieldDisplayView(
                field: .builtIn(
                    id: BuiltInFieldIds.Vaccine.notes,
                    displayName: "Notes",
                    fieldType: .string
                ),
                value: nil
            )
        }
    }
}
