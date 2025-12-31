import SwiftUI

/// Detail view showing record types for a person
struct PersonDetailView: View {
    let person: Person
    @State private var viewModel: PersonDetailViewModel

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
                                schemaType: schemaType,
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
        .navigationDestination(for: BuiltInSchemaType.self) { schemaType in
            // Placeholder for record list view (Issue #9)
            PlaceholderRecordListView(
                personName: person.name,
                schemaType: schemaType
            )
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

/// Placeholder view for record list (to be implemented in Issue #9)
private struct PlaceholderRecordListView: View {
    let personName: String
    let schemaType: BuiltInSchemaType

    var body: some View {
        ContentUnavailableView {
            Label("\(schemaType.displayName) Records", systemImage: schemaType.iconSystemName)
        } description: {
            Text("Record list view will be implemented in Issue #9")
        }
        .navigationTitle("\(personName)'s \(schemaType.displayName)")
        .navigationBarTitleDisplayMode(.inline)
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
