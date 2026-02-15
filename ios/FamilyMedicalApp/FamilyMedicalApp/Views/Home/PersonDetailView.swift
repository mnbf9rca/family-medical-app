import SwiftUI

/// Detail view showing record types for a person
struct PersonDetailView: View {
    let person: Person
    @State private var viewModel: PersonDetailViewModel
    @State private var showingSchemaManager = false

    init(person: Person, viewModel: PersonDetailViewModel? = nil) {
        self.person = person
        self._viewModel = State(initialValue: viewModel ?? PersonDetailViewModel(person: person))
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
            } else {
                List {
                    ForEach(BuiltInSchemaType.allCases, id: \.self) { schemaType in
                        NavigationLink(value: schemaType) {
                            RecordTypeRowView(
                                schema: viewModel.schemaForType(schemaType) ?? schemaType.schema,
                                recordCount: viewModel.recordCounts[schemaType.rawValue] ?? 0
                            )
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle(person.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingSchemaManager = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                .accessibilityLabel("Manage Record Types")
            }
        }
        .navigationDestination(for: BuiltInSchemaType.self) { schemaType in
            MedicalRecordListView(person: person, schemaType: schemaType)
        }
        .sheet(isPresented: $showingSchemaManager) {
            NavigationStack {
                SchemaListView(person: person)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") {
                                showingSchemaManager = false
                            }
                        }
                    }
            }
        }
        .onChange(of: showingSchemaManager) { _, isShowing in
            if !isShowing {
                // Refresh record counts when schema manager is dismissed
                Task {
                    await viewModel.loadRecordCounts()
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
        .task {
            await viewModel.loadRecordCounts()
        }
        .refreshable {
            await viewModel.loadRecordCounts()
        }
    }
}

#Preview {
    if let person = try? Person(
        id: UUID(),
        name: "Alice Smith",
        dateOfBirth: Date(timeIntervalSince1970: 631_152_000),
        labels: ["Self"],
        notes: nil
    ) {
        NavigationStack {
            PersonDetailView(person: person)
        }
    }
}
