import SwiftUI

/// Toggle-based renderer for `.boolean` FieldRenderType.
///
/// Stored value: `Bool` (or nil when unset). Optional boolean fields — the common case in
/// medical records — can be tri-stated: unset (nil) / true / false. This renderer treats
/// any current storage of nil as "false" for the toggle UI but does NOT automatically
/// commit false to the model until the user flips the toggle. That keeps "never touched"
/// distinguishable from "explicitly false" at the JSON level.
struct BooleanFieldRenderer: View {
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
                Toggle("", isOn: binding)
                    .labelsHidden()
                    .accessibilityLabel(metadata.displayName)
            }
            if let error = viewModel.validationErrors[metadata.keyPath] {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var binding: Binding<Bool> {
        Binding(
            get: { viewModel.boolValue(for: metadata.keyPath) ?? false },
            set: { viewModel.setValue($0, for: metadata.keyPath) }
        )
    }
}
