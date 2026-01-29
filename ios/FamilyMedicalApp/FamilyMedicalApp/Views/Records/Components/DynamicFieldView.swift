import SwiftUI

/// Renders an input control for a medical record field based on its type
///
/// This component dynamically generates the appropriate SwiftUI control based on
/// the field's `FieldType`. It handles bi-directional binding between the UI and
/// the `FieldValue?` storage.
struct DynamicFieldView: View {
    // MARK: - Properties

    let field: FieldDefinition
    @Binding var value: FieldValue?

    /// Person ID for attachment encryption (required for .attachmentIds fields)
    var personId: UUID?

    /// Record ID for attachment linking (nil for new records)
    var recordId: UUID?

    /// Existing attachments for editing (pre-loaded by caller)
    var existingAttachments: [Attachment]

    // MARK: - State

    @FocusState private var isFocused: Bool
    @State private var attachmentPickerViewModel: AttachmentPickerViewModel?

    // MARK: - Initialization

    init(
        field: FieldDefinition,
        value: Binding<FieldValue?>,
        personId: UUID? = nil,
        recordId: UUID? = nil,
        existingAttachments: [Attachment] = []
    ) {
        self.field = field
        _value = value
        self.personId = personId
        self.recordId = recordId
        self.existingAttachments = existingAttachments
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Field label with required indicator
            HStack(spacing: 4) {
                Text(field.displayName)
                    .font(.headline)
                if field.isRequired {
                    Text("*")
                        .foregroundStyle(.red)
                }
            }

            // Input control based on field type
            switch field.fieldType {
            case .string:
                stringInputView

            case .int:
                intInputView

            case .double:
                doubleInputView

            case .bool:
                boolInputView

            case .date:
                dateInputView

            case .attachmentIds:
                attachmentInputView

            case .stringArray:
                stringArrayInputView
            }

            // Help text
            if let helpText = field.helpText {
                Text(helpText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Input Views

    private var stringInputView: some View {
        Group {
            // Use explicit isMultiline property instead of string matching on field ID
            if field.isMultiline {
                TextField(
                    field.placeholder ?? "",
                    text: stringBinding,
                    axis: .vertical
                )
                .textFieldStyle(.roundedBorder)
                .lineLimit(3 ... 6)
                .textInputAutocapitalization(field.capitalizationMode.toSwiftUI)
                .focused($isFocused)
                .accessibilityIdentifier(field.displayName)
            } else {
                TextField(
                    field.placeholder ?? "",
                    text: stringBinding
                )
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(field.capitalizationMode.toSwiftUI)
                .focused($isFocused)
                .accessibilityIdentifier(field.displayName)
            }
        }
    }

    private var intInputView: some View {
        TextField(
            field.placeholder ?? "",
            text: intBinding
        )
        .textFieldStyle(.roundedBorder)
        .keyboardType(.numberPad)
        .focused($isFocused)
        .accessibilityIdentifier(field.displayName)
    }

    private var doubleInputView: some View {
        TextField(
            field.placeholder ?? "",
            text: doubleBinding
        )
        .textFieldStyle(.roundedBorder)
        .keyboardType(.decimalPad)
        .focused($isFocused)
        .accessibilityIdentifier(field.displayName)
    }

    private var boolInputView: some View {
        Toggle(field.displayName, isOn: boolBinding)
            .toggleStyle(.switch)
            .accessibilityIdentifier(field.displayName)
    }

    private var dateInputView: some View {
        DatePicker(
            "",
            selection: dateBinding,
            displayedComponents: .date
        )
        .datePickerStyle(.compact)
        .labelsHidden()
        .accessibilityIdentifier(field.displayName)
    }

    @ViewBuilder private var attachmentInputView: some View {
        if let personId {
            // Real attachment picker when person context is available
            let viewModel = getOrCreateAttachmentViewModel(personId: personId)
            AttachmentPickerView(viewModel: viewModel) { ids in
                value = ids.isEmpty ? nil : .attachmentIds(ids)
            }
            .accessibilityIdentifier(field.displayName)
        } else {
            // Fallback when person context is not available
            VStack(alignment: .leading, spacing: 4) {
                Label {
                    Text("Attachments require person context")
                        .font(.caption)
                } icon: {
                    Image(systemName: "paperclip")
                }
                .foregroundStyle(.secondary)
            }
            .accessibilityIdentifier(field.displayName)
        }
    }

    /// Get or create the attachment picker view model
    private func getOrCreateAttachmentViewModel(personId: UUID) -> AttachmentPickerViewModel {
        if let existing = attachmentPickerViewModel {
            return existing
        }

        return AttachmentPickerViewModel(
            personId: personId,
            recordId: recordId,
            existingAttachments: existingAttachments
        )
        // Can't set @State in computed property, so we return new each time
        // The view should manage this at a higher level for persistence
    }

    private var stringArrayInputView: some View {
        TextField(
            field.placeholder ?? "Comma-separated values",
            text: stringArrayBinding
        )
        .textFieldStyle(.roundedBorder)
        .focused($isFocused)
        .accessibilityIdentifier(field.displayName)
    }

    // MARK: - Bindings

    /// Binding for string values
    ///
    /// Always stores the string value (even empty) so validation can properly
    /// distinguish between "no value" and "empty string" for minLength rules.
    private var stringBinding: Binding<String> {
        Binding(
            get: {
                value?.stringValue ?? ""
            },
            set: { newValue in
                value = .string(newValue)
            }
        )
    }

    /// Binding for int values as text
    ///
    /// Uses text-based input to distinguish between "no value" (empty) and "zero" ("0").
    /// Invalid input is ignored (keeps previous value).
    private var intBinding: Binding<String> {
        Binding(
            get: {
                if let intValue = value?.intValue {
                    return String(intValue)
                }
                return ""
            },
            set: { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    value = nil
                } else if let intValue = Int(trimmed) {
                    value = .int(intValue)
                }
                // Invalid input: ignore (keep existing value)
            }
        )
    }

    /// Binding for double values as text
    ///
    /// Uses text-based input to distinguish between "no value" (empty) and "zero" ("0.0").
    /// Invalid input is ignored (keeps previous value).
    private var doubleBinding: Binding<String> {
        Binding(
            get: {
                if let doubleValue = value?.doubleValue {
                    // Format without trailing zeros for cleaner display
                    return doubleValue.truncatingRemainder(dividingBy: 1) == 0
                        ? String(format: "%.0f", doubleValue)
                        : String(doubleValue)
                }
                return ""
            },
            set: { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    value = nil
                } else if let doubleValue = Double(trimmed) {
                    value = .double(doubleValue)
                }
                // Invalid input: ignore (keep existing value)
            }
        )
    }

    /// Binding for bool values
    private var boolBinding: Binding<Bool> {
        Binding(
            get: {
                value?.boolValue ?? false
            },
            set: { newValue in
                value = .bool(newValue)
            }
        )
    }

    /// Binding for date values
    private var dateBinding: Binding<Date> {
        Binding(
            get: {
                value?.dateValue ?? Date()
            },
            set: { newValue in
                value = .date(newValue)
            }
        )
    }

    /// Binding for string array as comma-separated text
    private var stringArrayBinding: Binding<String> {
        Binding(
            get: {
                value?.stringArrayValue?.joined(separator: ", ") ?? ""
            },
            set: { newValue in
                if newValue.isEmpty {
                    value = nil
                } else {
                    let array = newValue.split(separator: ",").map {
                        $0.trimmingCharacters(in: .whitespaces)
                    }
                    value = .stringArray(array)
                }
            }
        )
    }

    // MARK: - Accessibility

    private var accessibilityLabel: String {
        var label = field.displayName
        if field.isRequired {
            label += ", required"
        }
        if let helpText = field.helpText {
            label += ", \(helpText)"
        }
        return label
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var stringValue: FieldValue? = .string("Test")
    @Previewable @State var notesValue: FieldValue? = .string("Some notes here...")
    @Previewable @State var intValue: FieldValue? = .int(5)
    @Previewable @State var dateValue: FieldValue? = .date(Date())
    @Previewable @State var boolValue: FieldValue? = .bool(true)

    Form {
        Section("String Field (with capitalizationMode: .words)") {
            DynamicFieldView(
                field: .builtIn(
                    id: BuiltInFieldIds.Vaccine.name,
                    displayName: "Vaccine Name",
                    fieldType: .string,
                    isRequired: true,
                    displayOrder: 1,
                    placeholder: "e.g., COVID-19, MMR",
                    helpText: "Name of the vaccine administered",
                    capitalizationMode: .words
                ),
                value: $stringValue
            )
        }

        Section("Multiline Field (isMultiline: true)") {
            DynamicFieldView(
                field: .builtIn(
                    id: BuiltInFieldIds.Vaccine.notes,
                    displayName: "Notes",
                    fieldType: .string,
                    isRequired: false,
                    displayOrder: 2,
                    placeholder: "Any additional notes",
                    helpText: "Additional information or reactions",
                    isMultiline: true
                ),
                value: $notesValue
            )
        }

        Section("Int Field") {
            DynamicFieldView(
                field: .builtIn(
                    id: BuiltInFieldIds.Vaccine.doseNumber,
                    displayName: "Dose Number",
                    fieldType: .int,
                    isRequired: false,
                    displayOrder: 3,
                    placeholder: "e.g., 1, 2, 3",
                    helpText: "Which dose in the series"
                ),
                value: $intValue
            )
        }

        Section("Date Field") {
            DynamicFieldView(
                field: .builtIn(
                    id: BuiltInFieldIds.Vaccine.dateAdministered,
                    displayName: "Date Administered",
                    fieldType: .date,
                    isRequired: true,
                    displayOrder: 4,
                    helpText: "When the vaccine was given"
                ),
                value: $dateValue
            )
        }

        Section("Bool Field") {
            DynamicFieldView(
                field: .builtIn(
                    id: UUID(), // Random UUID for preview
                    displayName: "Is Active",
                    fieldType: .bool,
                    isRequired: false,
                    displayOrder: 5
                ),
                value: $boolValue
            )
        }

        Section("Attachments") {
            DynamicFieldView(
                field: .builtIn(
                    id: BuiltInFieldIds.Vaccine.attachmentIds,
                    displayName: "Attachments",
                    fieldType: .attachmentIds,
                    isRequired: false,
                    displayOrder: 6,
                    helpText: "Photos and documents"
                ),
                value: .constant(nil)
            )
        }
    }
}
