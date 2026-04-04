import SwiftUI

/// Renders the repeating components group for Observation records.
///
/// Each component is a name + value + unit triple (e.g., "Systolic: 120 mmHg").
/// Users can add/remove rows. Rows delegate text-field state to `ComponentRowView` so
/// partial input (e.g. "12." mid-decimal) isn't clobbered by Double round-tripping, and
/// so a real `0` value is visually distinct from an unset one.
struct ObservationComponentRenderer: View {
    let metadata: FieldMetadata
    @Bindable var viewModel: GenericRecordFormViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            ForEach(Array(components.enumerated()), id: \.offset) { index, component in
                ComponentRowView(
                    component: component,
                    onChange: { updated in updateComponent(at: index, with: updated) },
                    onRemove: { removeComponent(at: index) }
                )
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

    private var header: some View {
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
    }

    // MARK: - Component manipulation

    private var components: [ObservationComponent] {
        viewModel.componentsValue(for: metadata.keyPath)
    }

    private func updateComponent(at index: Int, with updated: ObservationComponent) {
        var list = components
        guard index < list.count else { return }
        list[index] = updated
        viewModel.setValue(list, for: metadata.keyPath)
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

// MARK: - ComponentRowView

/// Single row inside `ObservationComponentRenderer`. Owns its own `@State` for the value
/// text so partial input and explicit zero are preserved correctly while the user is typing.
private struct ComponentRowView: View {
    let component: ObservationComponent
    let onChange: (ObservationComponent) -> Void
    let onRemove: () -> Void

    @State private var nameText: String = ""
    @State private var valueText: String = ""
    @State private var unitText: String = ""

    var body: some View {
        HStack(spacing: 8) {
            TextField("Name", text: $nameText)
                .textFieldStyle(.roundedBorder)
                .onChange(of: nameText) { _, _ in syncToParent() }
            TextField("Value", text: $valueText)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 80)
                .onChange(of: valueText) { _, _ in syncToParent() }
            TextField("Unit", text: $unitText)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 80)
                .onChange(of: unitText) { _, _ in syncToParent() }
            Button {
                onRemove()
            } label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.red)
            }
            .accessibilityLabel("Remove \(component.name.isEmpty ? "component" : component.name)")
        }
        .onAppear {
            seedLocalState(from: component)
        }
        // Re-seed when the parent's component value changes out from under us. This happens
        // after a mid-list delete/reorder: SwiftUI's `ForEach(id: \.offset)` reuses the same
        // view instance but feeds it a different `component`, so without this the visible
        // text drifts from the source of truth.
        .onChange(of: component) { _, newValue in
            seedLocalState(from: newValue)
        }
    }

    private func seedLocalState(from component: ObservationComponent) {
        nameText = component.name
        valueText = Self.formatInitialValueText(component.value, componentHasContent: !component.name.isEmpty)
        unitText = component.unit
    }

    /// Initial text for a component's value field.
    /// A freshly-added component (name empty, value 0, unit empty) shows a blank field so
    /// the user isn't forced to delete a leading "0" before typing. An existing component
    /// with value 0 shows "0" (distinct from unset).
    private static func formatInitialValueText(_ value: Double, componentHasContent: Bool) -> String {
        if value == 0, !componentHasContent { return "" }
        // Avoid trailing ".0" on whole numbers for cleaner UX.
        if value == value.rounded() { return String(Int(value)) }
        return String(value)
    }

    private func syncToParent() {
        // Accept the value even if the numeric parse fails (keep trailing "." mid-input).
        // We commit 0 when the text is non-parseable or empty so the model remains valid;
        // the partial text persists in our local @State and will re-render as the user edits.
        let parsedValue = Double(valueText) ?? 0
        onChange(ObservationComponent(name: nameText, value: parsedValue, unit: unitText))
    }
}
