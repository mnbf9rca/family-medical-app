import SwiftUI

/// Row view displaying a summary of a medical record in a list
struct MedicalRecordRowView: View {
    // MARK: - Properties

    let schema: RecordSchema
    let content: RecordContent

    // MARK: - Body

    var body: some View {
        HStack(spacing: 12) {
            // Schema icon
            Image(systemName: schema.iconSystemName)
                .foregroundStyle(.tint)
                .font(.title2)
                .frame(width: 30)
                .accessibilityHidden(true)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                // Primary field (first required field)
                Text(primaryFieldValue)
                    .font(.body)
                    .lineLimit(1)

                // Date field (first date field)
                if let dateValue = firstDateValue {
                    Text(dateValue, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Computed Properties

    /// Value of the primary field (first required field)
    private var primaryFieldValue: String {
        guard let primaryField = schema.fields.first(where: { $0.isRequired }) else {
            return schema.displayName
        }
        return content.getString(primaryField.id) ?? "Untitled"
    }

    /// Value of the first date field
    private var firstDateValue: Date? {
        guard let dateField = schema.fields.first(where: { $0.fieldType == .date }) else {
            return nil
        }
        return content.getDate(dateField.id)
    }

    /// Accessibility label combining all information
    private var accessibilityLabel: String {
        var label = primaryFieldValue
        if let dateValue = firstDateValue {
            label += ", \(dateValue.formatted(date: .abbreviated, time: .omitted))"
        }
        label += ", \(schema.displayName)"
        return label
    }
}

// MARK: - Preview

#Preview {
    List {
        Section("Vaccine") {
            MedicalRecordRowView(
                schema: RecordSchema.builtIn(.vaccine),
                content: {
                    var content = RecordContent(schemaId: "vaccine")
                    content.setString("vaccineName", "COVID-19 Pfizer")
                    content.setDate("dateAdministered", Date())
                    return content
                }()
            )
        }

        Section("Medication") {
            MedicalRecordRowView(
                schema: RecordSchema.builtIn(.medication),
                content: {
                    var content = RecordContent(schemaId: "medication")
                    content.setString("medicationName", "Aspirin")
                    content.setDate("startDate", Date())
                    return content
                }()
            )
        }

        Section("Condition") {
            MedicalRecordRowView(
                schema: RecordSchema.builtIn(.condition),
                content: {
                    var content = RecordContent(schemaId: "condition")
                    content.setString("conditionName", "Asthma")
                    content.setDate("diagnosedDate", Date())
                    return content
                }()
            )
        }
    }
}
