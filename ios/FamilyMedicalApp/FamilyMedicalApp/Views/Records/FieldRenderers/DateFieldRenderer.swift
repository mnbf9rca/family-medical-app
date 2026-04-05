import SwiftUI

/// Renders a DatePicker for `.date` fields.
///
/// Required date fields are seeded with `Date()` on first appear so validation doesn't
/// fail silently while the picker is already displaying a value. Optional date fields
/// are NOT seeded — their display falls back to `Date()` in the binding only, and the
/// Clear button resets to unset.
struct DateFieldRenderer: View {
    let metadata: FieldMetadata
    @Bindable var viewModel: GenericRecordFormViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(metadata.displayName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if metadata.isRequired {
                    Text("*")
                        .foregroundStyle(.red)
                }
                Spacer()
                if !metadata.isRequired, viewModel.value(for: metadata.keyPath) != nil {
                    Button("Clear") {
                        viewModel.setValue(nil, for: metadata.keyPath)
                    }
                    .font(.caption)
                }
            }
            DatePicker(
                metadata.displayName,
                selection: binding,
                displayedComponents: .date
            )
            .labelsHidden()
            .accessibilityLabel(metadata.displayName)
            .onAppear {
                // For required date fields, seed today's date into the ViewModel if unset.
                // Without this, the renderer shows Date() via the binding's default but the
                // VM holds nil → validation fails with "Required" even though the user sees
                // today's date in the picker.
                if metadata.isRequired, viewModel.value(for: metadata.keyPath) == nil {
                    viewModel.setValue(Date(), for: metadata.keyPath)
                }
            }
            if let error = viewModel.validationErrors[metadata.keyPath] {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var binding: Binding<Date> {
        Binding(
            get: { viewModel.dateValue(for: metadata.keyPath, default: Date()) },
            set: { viewModel.setValue($0, for: metadata.keyPath) }
        )
    }
}
