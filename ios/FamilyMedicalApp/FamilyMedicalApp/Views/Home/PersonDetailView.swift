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
                    Section {
                        NavigationLink {
                            ProviderListView(person: person)
                        } label: {
                            HStack {
                                Image(systemName: "stethoscope")
                                    .foregroundStyle(.tint)
                                    .frame(width: 30)
                                    .accessibilityHidden(true)

                                Text("My Providers")
                                    .font(.body)

                                Spacer()

                                if viewModel.providerCount > 0 {
                                    Text("\(viewModel.providerCount)")
                                        .foregroundStyle(.secondary)
                                        .font(.subheadline)
                                }
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel(providerAccessibilityLabel)
                        }
                    }

                    Section {
                        ForEach(RecordType.allCases, id: \.self) { recordType in
                            NavigationLink(value: recordType) {
                                RecordTypeRowView(
                                    recordType: recordType,
                                    recordCount: viewModel.recordCounts[recordType] ?? 0
                                )
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle(person.name)
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(for: RecordType.self) { recordType in
            MedicalRecordListView(person: person, recordType: recordType)
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

    private var providerAccessibilityLabel: String {
        if viewModel.providerCount == 0 {
            "My Providers, no providers"
        } else if viewModel.providerCount == 1 {
            "My Providers, 1 provider"
        } else {
            "My Providers, \(viewModel.providerCount) providers"
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
