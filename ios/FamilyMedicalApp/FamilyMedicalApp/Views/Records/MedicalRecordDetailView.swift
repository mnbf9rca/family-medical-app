import SwiftUI

/// Detail view displaying a medical record.
/// Currently shows minimal metadata. Task 7 (#127) will add full
/// protocol-driven field rendering via GenericRecordFormView.
struct MedicalRecordDetailView: View {
    let person: Person
    let decryptedRecord: DecryptedRecord

    var onDelete: (() async -> Void)?
    var onRecordUpdated: (() -> Void)?

    @Environment(\.dismiss)
    private var dismiss
    @State private var showingDeleteConfirmation = false
    @State private var isDeleting = false

    var body: some View {
        List {
            Section("Record Info") {
                HStack {
                    Text("Type")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Label(
                        decryptedRecord.recordType.displayName,
                        systemImage: decryptedRecord.recordType.iconSystemName
                    )
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
        .navigationTitle(decryptedRecord.recordType.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .destructiveAction) {
                Button("Delete", role: .destructive) {
                    showingDeleteConfirmation = true
                }
            }
        }
        .confirmationDialog(
            "Delete Record",
            isPresented: $showingDeleteConfirmation
        ) {
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
    }
}
