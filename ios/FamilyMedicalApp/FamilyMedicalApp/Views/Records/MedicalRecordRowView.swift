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
    /// Handles different field types appropriately
    private var primaryFieldValue: String {
        // Prefer a required field that has a string value
        if let stringValue = schema.fields
            .filter(\.isRequired)
            .compactMap({ content.getString($0.id) })
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
            if let intValue = content.getInt(fieldId) {
                return String(intValue)
            }
        case .double:
            if let doubleValue = content.getDouble(fieldId) {
                return String(format: "%.2f", doubleValue)
            }
        case .bool:
            if let boolValue = content.getBool(fieldId) {
                return boolValue ? "Yes" : "No"
            }
        case .date:
            if let dateValue = content.getDate(fieldId) {
                return dateValue.formatted(date: .abbreviated, time: .omitted)
            }
        case .attachmentIds, .string, .stringArray:
            break
        }

        return schema.displayName
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
                    content.setString(BuiltInFieldIds.Vaccine.name, "COVID-19 Pfizer")
                    content.setDate(BuiltInFieldIds.Vaccine.dateAdministered, Date())
                    return content
                }()
            )
        }

        Section("Medication") {
            MedicalRecordRowView(
                schema: RecordSchema.builtIn(.medication),
                content: {
                    var content = RecordContent(schemaId: "medication")
                    content.setString(BuiltInFieldIds.Medication.name, "Aspirin")
                    content.setDate(BuiltInFieldIds.Medication.startDate, Date())
                    return content
                }()
            )
        }

        Section("Condition") {
            MedicalRecordRowView(
                schema: RecordSchema.builtIn(.condition),
                content: {
                    var content = RecordContent(schemaId: "condition")
                    content.setString(BuiltInFieldIds.Condition.name, "Asthma")
                    content.setDate(BuiltInFieldIds.Condition.diagnosedDate, Date())
                    return content
                }()
            )
        }
    }
}
