import SwiftUI

/// Renders a Picker for enumerated options (e.g. severity: Mild/Moderate/Severe).
///
/// Includes an "Other…" option that reveals a text field for free-form entry, since medical
/// terminology often needs values outside the curated list.
struct PickerFieldRenderer: View {
    let metadata: FieldMetadata
    @Bindable var viewModel: GenericRecordFormViewModel

    private let otherSentinel = "Other…"

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
            Picker(metadata.displayName, selection: pickerBinding) {
                Text("— Select —").tag("")
                ForEach(metadata.pickerOptions ?? [], id: \.self) { option in
                    Text(option).tag(option)
                }
                Text(otherSentinel).tag(otherSentinel)
            }
            .pickerStyle(.menu)
            .accessibilityLabel(metadata.displayName)

            if isOtherSelected {
                TextField("Custom value", text: otherBinding)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("\(metadata.displayName) custom value")
            }
            if let error = viewModel.validationErrors[metadata.keyPath] {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var options: [String] {
        metadata.pickerOptions ?? []
    }

    private var currentValue: String {
        viewModel.stringValue(for: metadata.keyPath)
    }

    private var isOtherSelected: Bool {
        let value = currentValue
        return !value.isEmpty && !options.contains(value)
    }

    /// Binding that maps the Picker's selection: picking "Other…" reveals the text field
    /// and clears the stored value; picking a listed option stores it directly.
    private var pickerBinding: Binding<String> {
        Binding(
            get: {
                let value = currentValue
                if value.isEmpty { return "" }
                if options.contains(value) { return value }
                return otherSentinel
            },
            set: { newValue in
                if newValue == otherSentinel {
                    // Keep whatever custom value the user already typed, or blank it.
                    if options.contains(currentValue) {
                        viewModel.setValue("", for: metadata.keyPath)
                    }
                } else {
                    viewModel.setValue(newValue.isEmpty ? nil : newValue, for: metadata.keyPath)
                }
            }
        )
    }

    private var otherBinding: Binding<String> {
        Binding(
            get: { isOtherSelected ? currentValue : "" },
            set: { viewModel.setValue($0.isEmpty ? nil : $0, for: metadata.keyPath) }
        )
    }
}
