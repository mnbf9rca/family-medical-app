import SwiftUI

/// Form for adding or editing a medical record
struct MedicalRecordFormView: View {
    // MARK: - Properties

    let person: Person
    let schema: RecordSchema
    let existingRecord: MedicalRecord?
    let existingContent: RecordContent?

    /// Callback invoked after a successful save (before dismissal)
    var onSave: (() -> Void)?

    @Environment(\.dismiss)
    private var dismiss
    @State private var viewModel: MedicalRecordFormViewModel

    // MARK: - Initialization

    init(
        person: Person,
        schema: RecordSchema,
        existingRecord: MedicalRecord? = nil,
        existingContent: RecordContent? = nil,
        viewModel: MedicalRecordFormViewModel? = nil,
        onSave: (() -> Void)? = nil
    ) {
        self.person = person
        self.schema = schema
        self.existingRecord = existingRecord
        self.existingContent = existingContent
        self.onSave = onSave
        self._viewModel = State(initialValue: viewModel ?? MedicalRecordFormViewModel(
            person: person,
            schema: schema,
            existingRecord: existingRecord,
            existingContent: existingContent
        ))
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                ForEach(schema.activeFieldsByDisplayOrder) { field in
                    Section {
                        DynamicFieldView(
                            field: field,
                            value: Binding(
                                get: {
                                    viewModel.fieldValues[field.id.uuidString]
                                },
                                set: { newValue in
                                    viewModel.fieldValues[field.id.uuidString] = newValue
                                }
                            ),
                            personId: person.id,
                            recordId: existingRecord?.id
                        )
                    }
                }
            }
            .navigationTitle(viewModel.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await viewModel.save()
                        }
                    }
                    .disabled(viewModel.isLoading)
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
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                }
            }
            .onChange(of: viewModel.didSaveSuccessfully) { _, didSave in
                if didSave {
                    onSave?()
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Add Vaccine") {
    if let person = try? Person(
        id: UUID(),
        name: "Alice Smith",
        dateOfBirth: Date(),
        labels: ["Self"],
        notes: nil
    ) {
        MedicalRecordFormView(
            person: person,
            schema: RecordSchema.builtIn(.vaccine)
        )
    }
}

#Preview("Edit Vaccine") {
    if let person = try? Person(
        id: UUID(),
        name: "Alice Smith",
        dateOfBirth: Date(),
        labels: ["Self"],
        notes: nil
    ), let (record, content) = {
        var content = RecordContent(schemaId: "vaccine")
        content.setString(BuiltInFieldIds.Vaccine.name, "COVID-19 Pfizer")
        content.setDate(BuiltInFieldIds.Vaccine.dateAdministered, Date())

        let record = MedicalRecord(
            personId: person.id,
            encryptedContent: Data()
        )

        return (record, content)
    }() as (MedicalRecord, RecordContent)? {
        MedicalRecordFormView(
            person: person,
            schema: RecordSchema.builtIn(.vaccine),
            existingRecord: record,
            existingContent: content
        )
    }
}
