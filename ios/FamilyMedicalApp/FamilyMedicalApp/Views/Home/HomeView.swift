import SwiftUI

/// Main home screen displaying the list of members
struct HomeView: View {
    @Bindable var viewModel: HomeViewModel
    @State private var showingAddPerson = false

    init(viewModel: HomeViewModel = HomeViewModel()) {
        self.viewModel = viewModel
    }

    var body: some View {
        Group {
            if viewModel.persons.isEmpty, !viewModel.isLoading {
                EmptyMembersView {
                    showingAddPerson = true
                }
            } else {
                List {
                    ForEach(viewModel.persons) { person in
                        NavigationLink(value: person) {
                            PersonRowView(person: person)
                        }
                    }
                    .onDelete(perform: deletePerson)
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Members")
        .navigationDestination(for: Person.self) { person in
            PersonDetailView(person: person)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(
                    action: { showingAddPerson = true },
                    label: {
                        Image(systemName: "plus")
                    }
                )
                .accessibilityLabel("Add Member")
                .accessibilityIdentifier("toolbarAddMember")
            }
        }
        .sheet(isPresented: $showingAddPerson) {
            AddPersonView(viewModel: viewModel)
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(1.5)
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
            await viewModel.loadPersons()
        }
        .refreshable {
            await viewModel.loadPersons()
        }
    }

    func deletePerson(at offsets: IndexSet) {
        for index in offsets {
            let person = viewModel.persons[index]
            Task {
                await viewModel.deletePerson(id: person.id)
            }
        }
    }
}

#Preview {
    NavigationStack {
        HomeView()
    }
}
