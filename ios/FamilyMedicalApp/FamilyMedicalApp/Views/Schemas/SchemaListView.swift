import SwiftUI

/// List view for managing schemas (built-in and custom) for a person
struct SchemaListView: View {
    // MARK: - Properties

    let person: Person

    @State private var viewModel: SchemaListViewModel
    @State private var showingAddSchema = false
    @State private var schemaToDelete: RecordSchema?
    @State private var showingDeleteConfirmation = false

    // MARK: - Initialization

    init(person: Person, viewModel: SchemaListViewModel? = nil) {
        self.person = person
        self._viewModel = State(initialValue: viewModel ?? SchemaListViewModel(person: person))
    }

    // MARK: - Body

    var body: some View {
        Group {
            if viewModel.schemas.isEmpty, !viewModel.isLoading {
                emptyStateView
            } else {
                schemaListView
            }
        }
        .navigationTitle("Manage Record Types")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: RecordSchema.self) { schema in
            SchemaEditorView(person: person, schema: schema)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingAddSchema = true }, label: {
                    Image(systemName: "plus")
                })
                .accessibilityLabel("Add Custom Record Type")
            }
        }
        .sheet(isPresented: $showingAddSchema) {
            NavigationStack {
                SchemaEditorView(
                    person: person,
                    newSchemaTemplate: viewModel.createNewSchemaTemplate()
                )
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
        .confirmationDialog(
            "Delete Record Type",
            isPresented: $showingDeleteConfirmation,
            presenting: schemaToDelete
        ) { schema in
            Button("Delete", role: .destructive) {
                Task {
                    _ = await viewModel.deleteSchema(schemaId: schema.id)
                }
            }
        } message: { schema in
            let count = viewModel.recordCounts[schema.id] ?? 0
            if count > 0 {
                Text(
                    """
                    This will delete "\(schema.displayName)" and all \(count) \
                    associated records. This cannot be undone.
                    """
                )
            } else {
                Text("Are you sure you want to delete \"\(schema.displayName)\"?")
            }
        }
        .task {
            await viewModel.loadSchemas()
        }
        .refreshable {
            await viewModel.loadSchemas()
        }
        .onChange(of: showingAddSchema) { _, isShowing in
            if !isShowing {
                Task {
                    await viewModel.loadSchemas()
                }
            }
        }
    }

    // MARK: - Subviews

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Record Types", systemImage: "doc.text")
        } description: {
            Text("Add a custom record type to start organizing your medical records.")
        } actions: {
            Button {
                showingAddSchema = true
            } label: {
                Text("Add Record Type")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var schemaListView: some View {
        List {
            // Built-in schemas section
            let builtInSchemas = viewModel.schemas.filter(\.isBuiltIn)
            if !builtInSchemas.isEmpty {
                Section("Built-in Types") {
                    ForEach(builtInSchemas) { schema in
                        NavigationLink(value: schema) {
                            SchemaRowView(
                                schema: schema,
                                recordCount: viewModel.recordCounts[schema.id] ?? 0
                            )
                        }
                    }
                }
            }

            // Custom schemas section
            let customSchemas = viewModel.schemas.filter { !$0.isBuiltIn }
            if !customSchemas.isEmpty {
                Section("Custom Types") {
                    ForEach(customSchemas) { schema in
                        NavigationLink(value: schema) {
                            SchemaRowView(
                                schema: schema,
                                recordCount: viewModel.recordCounts[schema.id] ?? 0
                            )
                        }
                    }
                    .onDelete(perform: deleteSchemas)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Actions

    /// Handle swipe-to-delete for custom schemas
    private func deleteSchemas(at offsets: IndexSet) {
        let customSchemas = viewModel.schemas.filter { !$0.isBuiltIn }
        guard let index = offsets.first, index < customSchemas.count else { return }
        schemaToDelete = customSchemas[index]
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
            SchemaListView(person: person)
        }
    }
}
