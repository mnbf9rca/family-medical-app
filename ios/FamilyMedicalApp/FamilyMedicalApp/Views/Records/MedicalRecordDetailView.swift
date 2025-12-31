import SwiftUI

/// Detail view displaying all fields of a medical record
struct MedicalRecordDetailView: View {
    // MARK: - Properties

    let person: Person
    let schemaType: BuiltInSchemaType
    let decryptedRecord: DecryptedRecord

    @Environment(\.dismiss)
    private var dismiss
    @State private var showingEditForm = false
    @State private var showingDeleteConfirmation = false

    // MARK: - Body

    var body: some View {
        List {
            ForEach(schema.fieldsByDisplayOrder) { field in
                if let value = decryptedRecord.content[field.id] {
                    FieldDisplayView(field: field, value: value)
                }
            }

            Section {
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
        .navigationTitle(primaryFieldValue)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") {
                    showingEditForm = true
                }
                .accessibilityLabel("Edit \(schema.displayName)")
            }

            ToolbarItem(placement: .destructiveAction) {
                Button("Delete", role: .destructive) {
                    showingDeleteConfirmation = true
                }
                .accessibilityLabel("Delete \(schema.displayName)")
            }
        }
        .sheet(isPresented: $showingEditForm) {
            MedicalRecordFormView(
                person: person,
                schema: schema,
                existingRecord: decryptedRecord.record,
                existingContent: decryptedRecord.content
            )
        }
        .confirmationDialog(
            "Delete Record",
            isPresented: $showingDeleteConfirmation
        ) {
            Button("Delete", role: .destructive) {
                // TODO: Implement delete from detail view
                // For now, user must delete from list view
                dismiss()
            }
        } message: {
            Text("Are you sure you want to delete this record?")
        }
        .onChange(of: showingEditForm) { _, isShowing in
            if !isShowing {
                // TODO: Refresh if record was updated
                // For now, changes will be reflected when returning to list
            }
        }
    }

    // MARK: - Computed Properties

    private var schema: RecordSchema {
        RecordSchema.builtIn(schemaType)
    }

    /// Value of the primary field for the title
    private var primaryFieldValue: String {
        guard let primaryField = schema.fields.first(where: { $0.isRequired }) else {
            return schema.displayName
        }
        return decryptedRecord.content.getString(primaryField.id) ?? "Untitled"
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
        ), let decryptedRecord = {
            var content = RecordContent(schemaId: "vaccine")
            content.setString("vaccineName", "COVID-19 Pfizer")
            content.setDate("dateAdministered", Date())
            content.setString("provider", "CVS Pharmacy")
            content.setInt("doseNumber", 2)

            let record = MedicalRecord(
                personId: person.id,
                encryptedContent: Data()
            )

            return DecryptedRecord(record: record, content: content)
        }() as DecryptedRecord? {
            MedicalRecordDetailView(
                person: person,
                schemaType: .vaccine,
                decryptedRecord: decryptedRecord
            )
        }
    }
}
