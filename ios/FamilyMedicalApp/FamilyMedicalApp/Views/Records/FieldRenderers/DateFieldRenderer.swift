import SwiftUI

/// Renders a DatePicker for `.date` fields.
///
/// Required date fields default to `Date()` (now) when unset; optional date fields default
/// to `Date()` as the display value but may be cleared via the clear-to-nil button.
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
