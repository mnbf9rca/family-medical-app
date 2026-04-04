import SwiftUI

/// Renders the repeating components group for Observation records.
///
/// Each component is a name + value + unit triple (e.g., "Systolic: 120 mmHg").
/// Users can add/remove rows. When an observation type is chosen upstream, the components
/// may be pre-seeded with defaults from the bundled observation-types catalog.
struct ObservationComponentRenderer: View {
    let metadata: FieldMetadata
    @Bindable var viewModel: GenericRecordFormViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(metadata.displayName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if metadata.isRequired {
                    Text("*")
                        .foregroundStyle(.red)
                }
                Spacer()
                Button {
                    addComponent()
                } label: {
                    Label("Add", systemImage: "plus.circle")
                        .font(.caption)
                }
            }
            ForEach(Array(components.enumerated()), id: \.offset) { index, component in
                componentRow(index: index, component: component)
            }
            if components.isEmpty {
                Text("No measurements. Tap Add to enter a value.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let error = viewModel.validationErrors[metadata.keyPath] {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private func componentRow(index: Int, component: ObservationComponent) -> some View {
        HStack(spacing: 8) {
            TextField("Name", text: binding(index: index, field: .name))
                .textFieldStyle(.roundedBorder)
            TextField("Value", text: binding(index: index, field: .value))
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 80)
            TextField("Unit", text: binding(index: index, field: .unit))
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 80)
            Button {
                removeComponent(at: index)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.red)
            }
            .accessibilityLabel("Remove \(component.name.isEmpty ? "component" : component.name)")
        }
    }

    // MARK: - Component manipulation

    private enum RowField { case name, value, unit }

    private var components: [ObservationComponent] {
        viewModel.componentsValue(for: metadata.keyPath)
    }

    private func binding(index: Int, field: RowField) -> Binding<String> {
        Binding(
            get: {
                guard index < components.count else { return "" }
                let component = components[index]
                switch field {
                case .name: return component.name
                case .value: return component.value == 0 ? "" : String(component.value)
                case .unit: return component.unit
                }
            },
            set: { newValue in
                var list = components
                guard index < list.count else { return }
                let old = list[index]
                let updated = switch field {
                case .name:
                    ObservationComponent(name: newValue, value: old.value, unit: old.unit)
                case .value:
                    ObservationComponent(name: old.name, value: Double(newValue) ?? 0, unit: old.unit)
                case .unit:
                    ObservationComponent(name: old.name, value: old.value, unit: newValue)
                }
                list[index] = updated
                viewModel.setValue(list, for: metadata.keyPath)
            }
        )
    }

    private func addComponent() {
        var list = components
        list.append(ObservationComponent(name: "", value: 0, unit: ""))
        viewModel.setValue(list, for: metadata.keyPath)
    }

    private func removeComponent(at index: Int) {
        var list = components
        guard index < list.count else { return }
        list.remove(at: index)
        viewModel.setValue(list.isEmpty ? nil : list, for: metadata.keyPath)
    }
}
