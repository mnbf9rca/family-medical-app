import SwiftUI

/// List view for displaying medical records of a specific type
struct MedicalRecordListView: View {
    let person: Person
    let recordType: RecordType

    @State private var viewModel: MedicalRecordListViewModel
    @State private var recordToDelete: DecryptedRecord?
    @State private var showingDeleteConfirmation = false
    @State private var showingCascadeDialog = false
    @State private var pendingAttachments: [PersistedDocumentReference] = []
    @State private var showingCreateForm = false

    init(person: Person, recordType: RecordType, viewModel: MedicalRecordListViewModel? = nil) {
        self.person = person
        self.recordType = recordType
        self._viewModel = State(initialValue: viewModel ?? MedicalRecordListViewModel(
            person: person,
            recordType: recordType
        ))
    }

    var body: some View {
        Group {
            if viewModel.records.isEmpty, !viewModel.isLoading {
                EmptyRecordListView(recordType: recordType)
            } else {
                List {
                    ForEach(viewModel.records) { decryptedRecord in
                        NavigationLink(value: decryptedRecord) {
                            MedicalRecordRowView(decryptedRecord: decryptedRecord)
                        }
                    }
                    .onDelete(perform: deleteRecords)
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("\(person.name)'s \(recordType.displayName)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingCreateForm = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add \(recordType.displayName)")
            }
        }
        .sheet(isPresented: $showingCreateForm) {
            GenericRecordFormView(
                viewModel: GenericRecordFormViewModel(person: person, recordType: recordType)
            ) {
                Task { await viewModel.loadRecords() }
            }
        }
        .navigationDestination(for: DecryptedRecord.self) { decryptedRecord in
            MedicalRecordDetailView(
                person: person,
                decryptedRecord: decryptedRecord,
                onDelete: {
                    await viewModel.deleteRecord(
                        id: decryptedRecord.id,
                        strategy: .noAttachments
                    )
                },
                onRecordUpdated: {
                    Task {
                        await viewModel.loadRecords()
                    }
                }
            )
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
            "Delete Record",
            isPresented: $showingDeleteConfirmation,
            presenting: recordToDelete
        ) { record in
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.deleteRecord(
                        id: record.id,
                        strategy: .noAttachments
                    )
                }
            }
        } message: { _ in
            Text("Are you sure you want to delete this record?")
        }
        .confirmationDialog(
            "Delete Record with Attachments",
            isPresented: $showingCascadeDialog,
            presenting: recordToDelete
        ) { record in
            Button("Delete record and \(pendingAttachments.count) attachment(s)", role: .destructive) {
                let toDelete = pendingAttachments
                Task {
                    await viewModel.deleteRecord(
                        id: record.id,
                        strategy: .cascadeDelete,
                        attachments: toDelete
                    )
                }
            }
            Button("Delete record, keep attachments") {
                let toKeep = pendingAttachments
                Task {
                    await viewModel.deleteRecord(
                        id: record.id,
                        strategy: .keepStandalone,
                        attachments: toKeep
                    )
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("This record has \(pendingAttachments.count) attachment(s). What would you like to do?")
        }
        .task {
            await viewModel.loadRecords()
        }
        .refreshable {
            await viewModel.loadRecords()
        }
    }

    private func deleteRecords(at offsets: IndexSet) {
        guard let index = offsets.first else { return }
        let record = viewModel.records[index]
        recordToDelete = record
        Task {
            let attachments = await viewModel.prepareDelete(recordId: record.id)
            if attachments.isEmpty {
                showingDeleteConfirmation = true
            } else {
                pendingAttachments = attachments
                showingCascadeDialog = true
            }
        }
    }
}
