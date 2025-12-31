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

    // MARK: - State

    @FocusState private var isFocused: Bool

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
                attachmentPlaceholderView

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
            // Multi-line for notes and content fields
            if field.id.contains("notes") || field.id == "content" {
                TextField(
                    field.placeholder ?? "",
                    text: stringBinding,
                    axis: .vertical
                )
                .textFieldStyle(.roundedBorder)
                .lineLimit(3 ... 6)
                .focused($isFocused)
            } else {
                TextField(
                    field.placeholder ?? "",
                    text: stringBinding
                )
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(
                    field.id.contains("name") ? .words : .sentences
                )
                .focused($isFocused)
            }
        }
    }

    private var intInputView: some View {
        TextField(
            field.placeholder ?? "",
            value: intBinding,
            format: .number
        )
        .textFieldStyle(.roundedBorder)
        .keyboardType(.numberPad)
        .focused($isFocused)
    }

    private var doubleInputView: some View {
        TextField(
            field.placeholder ?? "",
            value: doubleBinding,
            format: .number
        )
        .textFieldStyle(.roundedBorder)
        .keyboardType(.decimalPad)
        .focused($isFocused)
    }

    private var boolInputView: some View {
        Toggle(field.displayName, isOn: boolBinding)
            .toggleStyle(.switch)
    }

    private var dateInputView: some View {
        DatePicker(
            "",
            selection: dateBinding,
            displayedComponents: .date
        )
        .datePickerStyle(.compact)
        .labelsHidden()
    }

    private var attachmentPlaceholderView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label {
                Text("Attachments will be available in a future update")
                    .font(.caption)
            } icon: {
                Image(systemName: "paperclip")
            }
            .foregroundStyle(.secondary)
        }
    }

    private var stringArrayInputView: some View {
        TextField(
            field.placeholder ?? "Comma-separated values",
            text: stringArrayBinding
        )
        .textFieldStyle(.roundedBorder)
        .focused($isFocused)
    }

    // MARK: - Bindings

    /// Binding for string values
    private var stringBinding: Binding<String> {
        Binding(
            get: {
                value?.stringValue ?? ""
            },
            set: { newValue in
                if newValue.isEmpty {
                    value = nil
                } else {
                    value = .string(newValue)
                }
            }
        )
    }

    /// Binding for int values
    private var intBinding: Binding<Int> {
        Binding(
            get: {
                value?.intValue ?? 0
            },
            set: { newValue in
                value = .int(newValue)
            }
        )
    }

    /// Binding for double values
    private var doubleBinding: Binding<Double> {
        Binding(
            get: {
                value?.doubleValue ?? 0.0
            },
            set: { newValue in
                value = .double(newValue)
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
    @Previewable @State var intValue: FieldValue? = .int(5)
    @Previewable @State var dateValue: FieldValue? = .date(Date())
    @Previewable @State var boolValue: FieldValue? = .bool(true)

    return Form {
        Section("String Field") {
            DynamicFieldView(
                field: FieldDefinition(
                    id: "vaccineName",
                    displayName: "Vaccine Name",
                    fieldType: .string,
                    isRequired: true,
                    displayOrder: 1,
                    placeholder: "e.g., COVID-19, MMR",
                    helpText: "Name of the vaccine administered"
                ),
                value: $stringValue
            )
        }

        Section("Int Field") {
            DynamicFieldView(
                field: FieldDefinition(
                    id: "doseNumber",
                    displayName: "Dose Number",
                    fieldType: .int,
                    isRequired: false,
                    displayOrder: 2,
                    placeholder: "e.g., 1, 2, 3",
                    helpText: "Which dose in the series"
                ),
                value: $intValue
            )
        }

        Section("Date Field") {
            DynamicFieldView(
                field: FieldDefinition(
                    id: "dateAdministered",
                    displayName: "Date Administered",
                    fieldType: .date,
                    isRequired: true,
                    displayOrder: 3,
                    helpText: "When the vaccine was given"
                ),
                value: $dateValue
            )
        }

        Section("Bool Field") {
            DynamicFieldView(
                field: FieldDefinition(
                    id: "isActive",
                    displayName: "Is Active",
                    fieldType: .bool,
                    isRequired: false,
                    displayOrder: 4
                ),
                value: $boolValue
            )
        }

        Section("Attachments") {
            DynamicFieldView(
                field: FieldDefinition(
                    id: "attachmentIds",
                    displayName: "Attachments",
                    fieldType: .attachmentIds,
                    isRequired: false,
                    displayOrder: 5,
                    helpText: "Photos and documents"
                ),
                value: .constant(nil)
            )
        }
    }
}
