import SwiftUI

/// Detail view displaying a medical record with typed fields from its envelope.
///
/// Thin display layer over `MedicalRecordDetailViewModel`, which owns the decoded field
/// values and provider resolution.
struct MedicalRecordDetailView: View {
    let person: Person
    let decryptedRecord: DecryptedRecord

    var onDelete: (() async -> Void)?
    var onRecordUpdated: (() -> Void)?

    @State private var viewModel: MedicalRecordDetailViewModel
    @Environment(\.dismiss)
    private var dismiss
    @State private var showingDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var showingEditForm = false

    init(
        person: Person,
        decryptedRecord: DecryptedRecord,
        onDelete: (() async -> Void)? = nil,
        onRecordUpdated: (() -> Void)? = nil,
        detailViewModel: MedicalRecordDetailViewModel? = nil
    ) {
        self.person = person
        self.decryptedRecord = decryptedRecord
        self.onDelete = onDelete
        self.onRecordUpdated = onRecordUpdated
        self._viewModel = State(
            initialValue: detailViewModel ?? MedicalRecordDetailViewModel(
                person: person,
                decryptedRecord: decryptedRecord
            )
        )
    }

    var body: some View {
        List {
            metadataSection
            if let errorMessage = viewModel.decodeErrorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
            }
            if !viewModel.knownFieldValues.isEmpty {
                fieldsSection
            }
            if !viewModel.unknownFields.isEmpty {
                unknownFieldsSection
            }
        }
        .navigationTitle(viewModel.recordType.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { showingEditForm = true }
            }
            ToolbarItem(placement: .destructiveAction) {
                Button("Delete", role: .destructive) {
                    showingDeleteConfirmation = true
                }
            }
        }
        .sheet(isPresented: $showingEditForm) {
            GenericRecordFormView(
                viewModel: GenericRecordFormViewModel(
                    person: person,
                    recordType: viewModel.recordType,
                    existingRecord: decryptedRecord
                )
            ) {
                onRecordUpdated?()
                dismiss()
            }
        }
        .confirmationDialog("Delete Record", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                Task {
                    isDeleting = true
                    await onDelete?()
                    isDeleting = false
                    dismiss()
                }
            }
        } message: {
            Text("Are you sure you want to delete this record?")
        }
        .overlay {
            if isDeleting {
                ProgressView()
            }
        }
        .task {
            await viewModel.loadProviderDisplayIfNeeded()
        }
    }

    // MARK: - Sections

    private var metadataSection: some View {
        Section("Record Info") {
            HStack {
                Text("Type")
                    .foregroundStyle(.secondary)
                Spacer()
                Label(viewModel.recordType.displayName, systemImage: viewModel.recordType.iconSystemName)
            }
            HStack {
                Text("Created")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(decryptedRecord.record.createdAt, style: .date)
            }
            HStack {
                Text("Last Updated")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(decryptedRecord.record.updatedAt, style: .date)
            }
        }
    }

    private var fieldsSection: some View {
        Section("Details") {
            ForEach(viewModel.orderedFieldMetadata, id: \.keyPath) { metadata in
                displayRow(for: metadata)
            }
        }
    }

    private var unknownFieldsSection: some View {
        Section {
            ForEach(Array(viewModel.unknownFields.keys.sorted()), id: \.self) { key in
                HStack(alignment: .top) {
                    Text(key)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(String(describing: viewModel.unknownFields[key] ?? ""))
                        .multilineTextAlignment(.trailing)
                }
            }
        } header: {
            Text("Additional Fields")
        } footer: {
            Text("Fields from a newer app version, preserved for forward compatibility.")
                .font(.caption)
        }
    }

    @ViewBuilder
    private func displayRow(for metadata: FieldMetadata) -> some View {
        if let text = displayText(for: metadata) {
            HStack(alignment: .top) {
                Text(metadata.displayName)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(text)
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    private func displayText(for metadata: FieldMetadata) -> String? {
        guard let raw = viewModel.knownFieldValues[metadata.keyPath] else { return nil }
        if metadata.isProviderReference {
            if let display = viewModel.providerDisplayString {
                return display
            }
            // Provider lookup hasn't resolved yet (or provider was deleted). Fall back to
            // the UUID so the row still renders — blank rows mislead the user into thinking
            // no provider was set when one was.
            if let uuid = raw as? UUID {
                return uuid.uuidString
            }
            return nil
        }
        switch metadata.fieldType {
        case .date:
            if let date = raw as? Date {
                return date.formatted(date: .abbreviated, time: .omitted)
            }
        case .components:
            if let components = raw as? [ObservationComponent] {
                return components
                    .map { "\($0.name): \($0.value) \($0.unit)" }
                    .joined(separator: "\n")
            }
        case .multilineText, .text:
            if metadata.isTagList, let array = raw as? [String] {
                return array.isEmpty ? nil : array.joined(separator: ", ")
            }
        default:
            break
        }
        let description = String(describing: raw)
        return description.isEmpty ? nil : description
    }
}
