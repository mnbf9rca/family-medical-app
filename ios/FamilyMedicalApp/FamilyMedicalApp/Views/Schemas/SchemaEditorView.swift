import SwiftUI

/// View for editing a schema (adding/reordering fields, changing properties)
struct SchemaEditorView: View {
    // MARK: - Properties

    let person: Person
    @State private var viewModel: SchemaEditorViewModel

    @Environment(\.dismiss)
    private var dismiss

    @State private var showingAddField = false
    @State private var selectedFieldType: FieldType?
    @State private var fieldToEdit: FieldDefinition?
    @State private var showingFieldEditor = false
    @State private var showingDiscardAlert = false

    // MARK: - Initialization

    /// Initialize for editing an existing schema
    init(person: Person, schema: RecordSchema, viewModel: SchemaEditorViewModel? = nil) {
        self.person = person
        self._viewModel = State(initialValue: viewModel ?? SchemaEditorViewModel(
            person: person,
            schema: schema
        ))
    }

    /// Initialize for creating a new schema
    init(person: Person, newSchemaTemplate: RecordSchema, viewModel: SchemaEditorViewModel? = nil) {
        self.person = person
        self._viewModel = State(initialValue: viewModel ?? SchemaEditorViewModel(
            person: person,
            newSchemaTemplate: newSchemaTemplate
        ))
    }

    // MARK: - Body

    var body: some View {
        Form {
            schemaDetailsSection
            activeFieldsSection
            hiddenFieldsSection
        }
        .navigationTitle(viewModel.isNewSchema ? "New Record Type" : "Edit Record Type")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                if viewModel.isNewSchema {
                    Button("Cancel") {
                        handleCancel()
                    }
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    Task {
                        await viewModel.save()
                        if viewModel.didSaveSuccessfully {
                            dismiss()
                        }
                    }
                }
                .disabled(viewModel.isLoading)
            }
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
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
        .alert("Discard Changes?", isPresented: $showingDiscardAlert) {
            Button("Discard", role: .destructive) {
                dismiss()
            }
            Button("Keep Editing", role: .cancel) {}
        } message: {
            Text("You have unsaved changes. Are you sure you want to discard them?")
        }
        .confirmationDialog("Add Field", isPresented: $showingAddField) {
            ForEach(FieldType.allCases, id: \.self) { fieldType in
                Button(fieldType.displayName) {
                    addNewField(type: fieldType)
                }
            }
        }
        .sheet(isPresented: $showingFieldEditor) {
            if let field = fieldToEdit {
                NavigationStack {
                    FieldEditorSheet(
                        field: field,
                        onSave: { updatedField in
                            viewModel.updateField(updatedField)
                            fieldToEdit = nil
                        },
                        onCancel: {
                            fieldToEdit = nil
                        }
                    )
                }
            }
        }
    }

    // MARK: - Sections

    private var schemaDetailsSection: some View {
        Section("Record Type Details") {
            if viewModel.canEditName {
                TextField("Name", text: $viewModel.displayName)
                    .textInputAutocapitalization(.words)
            } else {
                LabeledContent("Name", value: viewModel.displayName)
            }

            Picker("Icon", selection: $viewModel.iconSystemName) {
                ForEach(schemaIconOptions, id: \.self) { icon in
                    Label(icon, systemImage: icon)
                        .tag(icon)
                }
            }

            TextField("Description (optional)", text: $viewModel.schemaDescription, axis: .vertical)
                .lineLimit(2 ... 4)
        }
    }

    private var activeFieldsSection: some View {
        Section {
            if viewModel.activeFields.isEmpty {
                Text("No fields yet. Add a field to get started.")
                    .foregroundStyle(.secondary)
                    .italic()
            } else {
                ForEach(viewModel.activeFields) { field in
                    FieldRowView(field: field)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            fieldToEdit = field
                            showingFieldEditor = true
                        }
                        .swipeActions(edge: .trailing) {
                            if BuiltInFieldIds.isBuiltIn(field.id) {
                                Button("Hide", systemImage: "eye.slash") {
                                    viewModel.hideField(withId: field.id)
                                }
                                .tint(.orange)
                            } else {
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    _ = viewModel.deleteField(withId: field.id)
                                }
                            }
                        }
                }
                .onMove(perform: moveFields)
            }

            Button {
                showingAddField = true
            } label: {
                Label("Add Field", systemImage: "plus.circle")
            }
        } header: {
            Text("Fields")
        } footer: {
            Text("Drag to reorder. Swipe to hide or delete.")
        }
    }

    @ViewBuilder private var hiddenFieldsSection: some View {
        if !viewModel.hiddenFields.isEmpty {
            Section("Hidden Fields") {
                ForEach(viewModel.hiddenFields) { field in
                    FieldRowView(field: field)
                        .foregroundStyle(.secondary)
                        .swipeActions(edge: .leading) {
                            Button("Show", systemImage: "eye") {
                                viewModel.unhideField(withId: field.id)
                            }
                            .tint(.green)
                        }
                }
            }
        }
    }

    // MARK: - Actions

    private func handleCancel() {
        if viewModel.hasUnsavedChanges {
            showingDiscardAlert = true
        } else {
            dismiss()
        }
    }

    private func addNewField(type: FieldType) {
        let newField = viewModel.createNewField(type: type)
        fieldToEdit = newField
        showingFieldEditor = true
    }

    private func moveFields(from source: IndexSet, to destination: Int) {
        viewModel.moveFields(from: source, to: destination)
    }

    // MARK: - Constants

    private let schemaIconOptions = [
        "doc.text",
        "heart.text.square",
        "cross.case",
        "pills",
        "syringe",
        "waveform.path.ecg",
        "stethoscope",
        "bandage",
        "testtube.2",
        "flask",
        "brain.head.profile",
        "eye",
        "ear",
        "hand.raised",
        "figure.walk",
        "bed.double",
        "fork.knife",
        "drop",
        "thermometer",
        "scalemass"
    ]
}

// MARK: - Field Row View

/// Row view for displaying a field in the schema editor
struct FieldRowView: View {
    let field: FieldDefinition

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(field.displayName)
                        .font(.body)

                    if field.isRequired {
                        Text("*")
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }

                Text(field.fieldType.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if BuiltInFieldIds.isBuiltIn(field.id) {
                Text("Built-in")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.secondary.opacity(0.2))
                    .clipShape(Capsule())
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(field.displayName), \(field.fieldType.displayName)\(field.isRequired ? ", required" : "")"
        )
    }
}

// MARK: - Preview

#Preview("New Schema") {
    NavigationStack {
        if let person = try? Person(
            id: UUID(),
            name: "Alice Smith",
            dateOfBirth: Date(),
            labels: ["Self"],
            notes: nil
        ) {
            SchemaEditorView(
                person: person,
                newSchemaTemplate: RecordSchema(
                    unsafeId: "custom-preview",
                    displayName: "New Record Type",
                    iconSystemName: "doc.text",
                    fields: [],
                    isBuiltIn: false,
                    description: nil
                )
            )
        }
    }
}

#Preview("Edit Built-in Schema") {
    NavigationStack {
        if let person = try? Person(
            id: UUID(),
            name: "Alice Smith",
            dateOfBirth: Date(),
            labels: ["Self"],
            notes: nil
        ) {
            SchemaEditorView(
                person: person,
                schema: RecordSchema.builtIn(.vaccine)
            )
        }
    }
}
