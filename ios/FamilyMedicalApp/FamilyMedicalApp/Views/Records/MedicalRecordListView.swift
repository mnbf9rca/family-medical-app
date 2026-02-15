import SwiftUI

/// List view for displaying medical records of a specific type
struct MedicalRecordListView: View {
    // MARK: - Properties

    let person: Person
    let schemaType: BuiltInSchemaType

    @State private var viewModel: MedicalRecordListViewModel
    @State private var showingAddForm = false
    @State private var recordToDelete: DecryptedRecord?
    @State private var showingDeleteConfirmation = false

    // MARK: - Initialization

    init(person: Person, schemaType: BuiltInSchemaType, viewModel: MedicalRecordListViewModel? = nil) {
        self.person = person
        self.schemaType = schemaType
        self._viewModel = State(initialValue: viewModel ?? MedicalRecordListViewModel(
            person: person,
            schemaType: schemaType
        ))
    }

    // MARK: - Body

    var body: some View {
        Group {
            if let schema = viewModel.schema {
                if viewModel.records.isEmpty, !viewModel.isLoading {
                    EmptyRecordListView(schema: schema) {
                        showingAddForm = true
                    }
                } else {
                    List {
                        ForEach(viewModel.records) { decryptedRecord in
                            NavigationLink(value: decryptedRecord) {
                                MedicalRecordRowView(
                                    schema: schema,
                                    content: decryptedRecord.content
                                )
                            }
                        }
                        .onDelete(perform: deleteRecords)
                    }
                    .listStyle(.insetGrouped)
                }
            } else if viewModel.isLoading {
                ProgressView()
            }
        }
        .navigationTitle(viewModel.schema.map { "\(person.name)'s \($0.displayName)" } ?? person.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: DecryptedRecord.self) { decryptedRecord in
            if let schema = viewModel.schema {
                MedicalRecordDetailView(
                    person: person,
                    schema: schema,
                    decryptedRecord: decryptedRecord,
                    onDelete: {
                        await viewModel.deleteRecord(id: decryptedRecord.id)
                    },
                    onRecordUpdated: {
                        Task {
                            await viewModel.loadRecords()
                        }
                    }
                )
            }
        }
        .toolbar {
            if let schema = viewModel.schema {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddForm = true }, label: {
                        Image(systemName: "plus")
                    })
                    .accessibilityLabel("Add \(schema.displayName)")
                }
            }
        }
        .sheet(isPresented: $showingAddForm) {
            if let schema = viewModel.schema {
                MedicalRecordFormView(person: person, schema: schema)
            }
        }
        .overlay {
            if viewModel.isLoading, viewModel.schema != nil {
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
        .confirmationDialog(
            "Delete Record",
            isPresented: $showingDeleteConfirmation,
            presenting: recordToDelete
        ) { record in
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.deleteRecord(id: record.id)
                }
            }
        } message: { _ in
            Text("Are you sure you want to delete this record?")
        }
        .task {
            await viewModel.loadRecords()
        }
        .refreshable {
            await viewModel.loadRecords()
        }
        .onChange(of: showingAddForm) { _, isShowing in
            if !isShowing {
                // Refresh list when form is dismissed
                Task {
                    await viewModel.loadRecords()
                }
            }
        }
    }

    // MARK: - Actions

    /// Handle swipe-to-delete gesture
    ///
    /// SwiftUI's `.onDelete` modifier for swipe gestures always provides a single-element IndexSet.
    /// Multi-row deletion would require Edit mode with selection, which is not currently implemented.
    /// If multi-select is added later, update this to handle all indices.
    private func deleteRecords(at offsets: IndexSet) {
        guard let index = offsets.first else { return }
        recordToDelete = viewModel.records[index]
        showingDeleteConfirmation = true
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        if let person = try? Person(
            id: UUID(),
            name: "Alice Smith",
            dateOfBirth: Date(),
            labels: ["Self"],
            notes: nil
        ) {
            MedicalRecordListView(person: person, schemaType: .vaccine)
        }
    }
}
