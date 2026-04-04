import SwiftUI

/// Renders a single-line or multi-line text field driven by `FieldMetadata`.
///
/// Uses the ViewModel's `stringValue(for:)` accessor so values persist between form renders,
/// and writes through `setValue(_:for:)` on each keystroke.
struct TextFieldRenderer: View {
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
            }
            Group {
                if metadata.fieldType == .multilineText {
                    TextField(
                        metadata.placeholder ?? "",
                        text: binding,
                        axis: .vertical
                    )
                    .lineLimit(3 ... 6)
                } else {
                    TextField(metadata.placeholder ?? "", text: binding)
                }
            }
            .textFieldStyle(.roundedBorder)
            .accessibilityLabel(metadata.displayName)
            if let error = viewModel.validationErrors[metadata.keyPath] {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var binding: Binding<String> {
        Binding(
            get: { viewModel.stringValue(for: metadata.keyPath) },
            set: { viewModel.setValue($0, for: metadata.keyPath) }
        )
    }
}
