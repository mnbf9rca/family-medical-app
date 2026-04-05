import SwiftUI

/// Protocol-driven form that renders any `MedicalRecordContent` record type.
///
/// Iterates `viewModel.fieldMetadata` in `displayOrder` and dispatches each field to its
/// matching renderer based on `FieldRenderType`. The ViewModel owns all mutable state;
/// renderers read from and write to it via typed accessors.
struct GenericRecordFormView: View {
    @Bindable var viewModel: GenericRecordFormViewModel
    var onSaveComplete: (() -> Void)?

    @Environment(\.dismiss)
    private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                if let warning = viewModel.forwardCompatibilityWarning {
                    Section {
                        Label(warning, systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                Section {
                    ForEach(viewModel.fieldMetadata, id: \.keyPath) { metadata in
                        renderer(for: metadata)
                            .padding(.vertical, 4)
                    }
                }
                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(viewModel.isEditing ? "Edit \(viewModel.displayName)" : "New \(viewModel.displayName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await attemptSave() }
                    }
                    .disabled(viewModel.isSaving)
                }
            }
            .overlay {
                if viewModel.isSaving {
                    ProgressView()
                }
            }
            .task {
                await viewModel.loadProviders()
            }
        }
    }

    @ViewBuilder
    private func renderer(for metadata: FieldMetadata) -> some View {
        switch metadata.fieldType {
        case .multilineText, .text:
            TextFieldRenderer(metadata: metadata, viewModel: viewModel)
        case .date:
            DateFieldRenderer(metadata: metadata, viewModel: viewModel)
        case .integer, .number:
            NumberFieldRenderer(metadata: metadata, viewModel: viewModel)
        case .picker:
            PickerFieldRenderer(metadata: metadata, viewModel: viewModel)
        case .autocomplete:
            AutocompleteFieldRenderer(metadata: metadata, viewModel: viewModel)
        case .components:
            ObservationComponentRenderer(metadata: metadata, viewModel: viewModel)
        case .boolean:
            BooleanFieldRenderer(metadata: metadata, viewModel: viewModel)
        }
    }

    private func attemptSave() async {
        let ok = await viewModel.save()
        if ok {
            onSaveComplete?()
            dismiss()
        }
    }
}
