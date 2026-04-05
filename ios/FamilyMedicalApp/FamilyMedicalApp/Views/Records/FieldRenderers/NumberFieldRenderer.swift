import SwiftUI

/// Renders a numeric TextField for `.integer` or `.number` fields.
///
/// Uses a String-backed binding internally so users can clear the field cleanly.
/// Invalid input is simply not persisted (the last valid value is retained in `fieldValues`).
struct NumberFieldRenderer: View {
    let metadata: FieldMetadata
    @Bindable var viewModel: GenericRecordFormViewModel
    @State private var textValue: String = ""

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
            TextField(metadata.placeholder ?? "", text: $textValue)
                .keyboardType(metadata.fieldType == .integer ? .numberPad : .decimalPad)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel(metadata.displayName)
                .onChange(of: textValue) { _, newValue in
                    updateViewModel(from: newValue)
                }
                .onAppear {
                    textValue = currentTextFromViewModel()
                }
            if let error = viewModel.validationErrors[metadata.keyPath] {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private func currentTextFromViewModel() -> String {
        if metadata.fieldType == .integer {
            return viewModel.intValue(for: metadata.keyPath).map(String.init) ?? ""
        }
        if let double = viewModel.value(for: metadata.keyPath) as? Double {
            return String(double)
        }
        return ""
    }

    private func updateViewModel(from newValue: String) {
        if newValue.isEmpty {
            viewModel.setValue(nil, for: metadata.keyPath)
            return
        }
        if metadata.fieldType == .integer {
            if let intValue = Int(newValue) {
                viewModel.setValue(intValue, for: metadata.keyPath)
            }
        } else {
            if let doubleValue = Double(newValue) {
                viewModel.setValue(doubleValue, for: metadata.keyPath)
            }
        }
    }
}
