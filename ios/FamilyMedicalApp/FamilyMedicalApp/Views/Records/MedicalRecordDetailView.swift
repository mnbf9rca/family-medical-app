import SwiftUI

/// Detail view displaying all fields of a medical record
struct MedicalRecordDetailView: View {
    // MARK: - Properties

    let person: Person
    let schemaType: BuiltInSchemaType
    let decryptedRecord: DecryptedRecord

    /// Callback invoked when the record is deleted
    var onDelete: (() async -> Void)?

    /// Callback invoked when the record is updated (triggers refresh in parent)
    var onRecordUpdated: (() -> Void)?

    @Environment(\.dismiss)
    private var dismiss
    @State private var showingEditForm = false
    @State private var showingDeleteConfirmation = false
    @State private var isDeleting = false

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
            ) {
                // Only refresh and dismiss on successful save
                onRecordUpdated?()
                dismiss()
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

    // MARK: - Computed Properties

    private var schema: RecordSchema {
        RecordSchema.builtIn(schemaType)
    }

    /// Value of the primary field for the title
    /// Handles different field types appropriately
    private var primaryFieldValue: String {
        // Prefer a required field that has a string value
        if let stringValue = schema.fields
            .filter(\.isRequired)
            .compactMap({ decryptedRecord.content.getString($0.id) })
            .first, !stringValue.isEmpty {
            return stringValue
        }

        // Fallback: check first required field for other types
        guard let primaryField = schema.fields.first(where: { $0.isRequired }) else {
            return schema.displayName
        }

        let fieldId = primaryField.id
        switch primaryField.fieldType {
        case .int:
            if let intValue = decryptedRecord.content.getInt(fieldId) {
                return String(intValue)
            }
        case .double:
            if let doubleValue = decryptedRecord.content.getDouble(fieldId) {
                return String(format: "%.2f", doubleValue)
            }
        case .bool:
            if let boolValue = decryptedRecord.content.getBool(fieldId) {
                return boolValue ? "Yes" : "No"
            }
        case .date:
            if let dateValue = decryptedRecord.content.getDate(fieldId) {
                return dateValue.formatted(date: .abbreviated, time: .omitted)
            }
        case .attachmentIds, .string, .stringArray:
            break
        }

        return schema.displayName
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
            content.setString(BuiltInFieldIds.Vaccine.name, "COVID-19 Pfizer")
            content.setDate(BuiltInFieldIds.Vaccine.dateAdministered, Date())
            content.setString(BuiltInFieldIds.Vaccine.provider, "CVS Pharmacy")
            content.setInt(BuiltInFieldIds.Vaccine.doseNumber, 2)

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
