import SwiftUI

/// Row view displaying a summary of a medical record in a list.
/// Shows the record type icon, display name, and creation date.
/// Task 7 (#127) will add rich field display via protocol-driven rendering.
struct MedicalRecordRowView: View {
    let decryptedRecord: DecryptedRecord

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: decryptedRecord.recordType.iconSystemName)
                .foregroundStyle(.tint)
                .font(.title2)
                .frame(width: 30)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(decryptedRecord.recordType.displayName)
                    .font(.body)
                    .lineLimit(1)

                Text(decryptedRecord.record.createdAt, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(decryptedRecord.recordType.displayName), "
                + decryptedRecord.record.createdAt.formatted(date: .abbreviated, time: .omitted)
        )
    }
}
