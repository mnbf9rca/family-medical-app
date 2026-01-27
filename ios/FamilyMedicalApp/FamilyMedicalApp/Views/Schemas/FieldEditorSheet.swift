import SwiftUI

/// Sheet for editing a field's properties
struct FieldEditorSheet: View {
    // MARK: - Properties

    @State private var viewModel: FieldEditorViewModel

    let onSave: (FieldDefinition) -> Void
    let onCancel: () -> Void

    @Environment(\.dismiss)
    private var dismiss

    // MARK: - Initialization

    /// Initialize for editing an existing field
    init(
        field: FieldDefinition,
        viewModel: FieldEditorViewModel? = nil,
        onSave: @escaping (FieldDefinition) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self._viewModel = State(initialValue: viewModel ?? FieldEditorViewModel(field: field))
        self.onSave = onSave
        self.onCancel = onCancel
    }

    /// Initialize for creating a new field
    init(
        fieldType: FieldType,
        viewModel: FieldEditorViewModel? = nil,
        onSave: @escaping (FieldDefinition) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self._viewModel = State(initialValue: viewModel ?? FieldEditorViewModel(fieldType: fieldType))
        self.onSave = onSave
        self.onCancel = onCancel
    }

    // MARK: - Body

    var body: some View {
        Form {
            basicPropertiesSection
            uiHintsSection
            validationSection
        }
        .navigationTitle(viewModel.isNewField ? "New Field" : "Edit Field")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    onCancel()
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    saveField()
                }
            }
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Sections

    private var basicPropertiesSection: some View {
        Section("Field Properties") {
            TextField("Field Name", text: $viewModel.displayName)
                .textInputAutocapitalization(.words)

            LabeledContent("Type", value: viewModel.fieldType.displayName)

            Toggle("Required", isOn: $viewModel.isRequired)

            TextField("Placeholder (optional)", text: $viewModel.placeholder)

            TextField("Help Text (optional)", text: $viewModel.helpText, axis: .vertical)
                .lineLimit(2 ... 4)
        }
    }

    @ViewBuilder private var uiHintsSection: some View {
        if viewModel.fieldType == .string {
            Section("Text Options") {
                Toggle("Multiline Input", isOn: $viewModel.isMultiline)

                Picker("Capitalization", selection: $viewModel.capitalizationMode) {
                    Text("None").tag(TextCapitalizationMode.none)
                    Text("Words").tag(TextCapitalizationMode.words)
                    Text("Sentences").tag(TextCapitalizationMode.sentences)
                    Text("All Characters").tag(TextCapitalizationMode.allCharacters)
                }
            }
        }
    }

    @ViewBuilder private var validationSection: some View {
        if viewModel.canAddLengthValidation || viewModel.canAddNumericValidation || viewModel.canAddDateValidation {
            Section("Validation Rules") {
                if viewModel.canAddLengthValidation {
                    stringValidationControls
                }

                if viewModel.canAddNumericValidation {
                    numericValidationControls
                }

                if viewModel.canAddDateValidation {
                    dateValidationControls
                }

                if !viewModel.validationRules.isEmpty {
                    Button("Clear All Rules", role: .destructive) {
                        viewModel.clearValidationRules()
                    }
                }
            }
        }
    }

    private var stringValidationControls: some View {
        Group {
            HStack {
                Text("Min Length")
                Spacer()
                TextField("", value: minLengthBinding, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    .keyboardType(.numberPad)
            }

            HStack {
                Text("Max Length")
                Spacer()
                TextField("", value: maxLengthBinding, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    .keyboardType(.numberPad)
            }
        }
    }

    private var numericValidationControls: some View {
        Group {
            HStack {
                Text("Minimum Value")
                Spacer()
                TextField("", value: minValueBinding, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
                    .keyboardType(.decimalPad)
            }

            HStack {
                Text("Maximum Value")
                Spacer()
                TextField("", value: maxValueBinding, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
                    .keyboardType(.decimalPad)
            }
        }
    }

    private var dateValidationControls: some View {
        Group {
            DatePicker(
                "Earliest Date",
                selection: minDateBinding,
                displayedComponents: .date
            )

            DatePicker(
                "Latest Date",
                selection: maxDateBinding,
                displayedComponents: .date
            )
        }
    }

    // MARK: - Validation Bindings

    private var minLengthBinding: Binding<Int?> {
        Binding(
            get: {
                for rule in viewModel.validationRules {
                    if case let .minLength(value) = rule { return value }
                }
                return nil
            },
            set: { newValue in
                if let value = newValue, value > 0 {
                    viewModel.addMinLengthRule(value)
                } else {
                    viewModel.validationRules.removeAll { if case .minLength = $0 { return true }; return false }
                }
            }
        )
    }

    private var maxLengthBinding: Binding<Int?> {
        Binding(
            get: {
                for rule in viewModel.validationRules {
                    if case let .maxLength(value) = rule { return value }
                }
                return nil
            },
            set: { newValue in
                if let value = newValue, value > 0 {
                    viewModel.addMaxLengthRule(value)
                } else {
                    viewModel.validationRules.removeAll { if case .maxLength = $0 { return true }; return false }
                }
            }
        )
    }

    private var minValueBinding: Binding<Double?> {
        Binding(
            get: {
                for rule in viewModel.validationRules {
                    if case let .minValue(value) = rule { return value }
                }
                return nil
            },
            set: { newValue in
                if let value = newValue {
                    viewModel.addMinValueRule(value)
                } else {
                    viewModel.validationRules.removeAll { if case .minValue = $0 { return true }; return false }
                }
            }
        )
    }

    private var maxValueBinding: Binding<Double?> {
        Binding(
            get: {
                for rule in viewModel.validationRules {
                    if case let .maxValue(value) = rule { return value }
                }
                return nil
            },
            set: { newValue in
                if let value = newValue {
                    viewModel.addMaxValueRule(value)
                } else {
                    viewModel.validationRules.removeAll { if case .maxValue = $0 { return true }; return false }
                }
            }
        )
    }

    private var minDateBinding: Binding<Date> {
        Binding(
            get: {
                for rule in viewModel.validationRules {
                    if case let .minDate(value) = rule { return value }
                }
                return Date.distantPast
            },
            set: { newValue in
                if newValue != Date.distantPast {
                    viewModel.addMinDateRule(newValue)
                }
            }
        )
    }

    private var maxDateBinding: Binding<Date> {
        Binding(
            get: {
                for rule in viewModel.validationRules {
                    if case let .maxDate(value) = rule { return value }
                }
                return Date.distantFuture
            },
            set: { newValue in
                if newValue != Date.distantFuture {
                    viewModel.addMaxDateRule(newValue)
                }
            }
        )
    }

    // MARK: - Actions

    private func saveField() {
        // Use a placeholder device ID until device identity is implemented
        if let field = viewModel.buildField(
            deviceId: .zero,
            displayOrder: viewModel.originalField?.displayOrder ?? 0
        ) {
            onSave(field)
            dismiss()
        }
    }
}

// MARK: - Preview

#Preview("New String Field") {
    NavigationStack {
        FieldEditorSheet(
            fieldType: .string,
            onSave: { _ in },
            onCancel: {}
        )
    }
}

#Preview("Edit Existing Field") {
    let field = FieldDefinition.builtIn(
        id: UUID(),
        displayName: "Vaccine Name",
        fieldType: .string,
        isRequired: true,
        displayOrder: 1,
        placeholder: "Enter vaccine name"
    )

    return NavigationStack {
        FieldEditorSheet(
            field: field,
            onSave: { _ in },
            onCancel: {}
        )
    }
}
