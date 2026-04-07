import SwiftUI

/// List view for displaying and managing providers for a person
struct ProviderListView: View {
    let person: Person

    @State private var viewModel: ProviderListViewModel
    @State private var showingCreateSheet = false
    @State private var providerToEdit: Provider?
    @State private var providerToDelete: Provider?
    @State private var showingDeleteConfirmation = false

    init(person: Person, viewModel: ProviderListViewModel? = nil) {
        self.person = person
        self._viewModel = State(initialValue: viewModel ?? ProviderListViewModel(person: person))
    }

    var body: some View {
        Group {
            if viewModel.filteredProviders.isEmpty, !viewModel.isLoading {
                ContentUnavailableView(
                    "No Providers",
                    systemImage: "stethoscope",
                    description: Text("No providers yet. Tap + to add one.")
                )
            } else {
                List {
                    ForEach(viewModel.filteredProviders) { provider in
                        Button {
                            providerToEdit = provider
                        } label: {
                            ProviderRowView(provider: provider)
                        }
                        .tint(.primary)
                    }
                    .onDelete(perform: deleteProviders)
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("\(person.name)'s Providers")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $viewModel.searchText, prompt: "Search providers")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add Provider")
            }
        }
        .sheet(isPresented: $showingCreateSheet) {
            ProviderDetailView(person: person) { provider in
                await viewModel.saveProvider(provider)
                return viewModel.errorMessage == nil
            }
        }
        .sheet(item: $providerToEdit) { provider in
            ProviderDetailView(person: person, existingProvider: provider) { updated in
                await viewModel.saveProvider(updated)
                return viewModel.errorMessage == nil
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
            "Delete Provider",
            isPresented: $showingDeleteConfirmation,
            presenting: providerToDelete
        ) { provider in
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.deleteProvider(id: provider.id)
                }
            }
        } message: { _ in
            Text("Are you sure you want to delete this provider?")
        }
        .task {
            await viewModel.loadProviders()
        }
        .refreshable {
            await viewModel.loadProviders()
        }
    }

    private func deleteProviders(at offsets: IndexSet) {
        guard let index = offsets.first else { return }
        let provider = viewModel.filteredProviders[index]
        providerToDelete = provider
        showingDeleteConfirmation = true
    }
}

// MARK: - Provider Row View

private struct ProviderRowView: View {
    let provider: Provider

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(provider.displayString)
                .font(.body)

            if let specialty = provider.specialty {
                Text(specialty)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var accessibilityDescription: String {
        var parts = [provider.displayString]
        if let specialty = provider.specialty {
            parts.append(specialty)
        }
        return parts.joined(separator: ", ")
    }
}
