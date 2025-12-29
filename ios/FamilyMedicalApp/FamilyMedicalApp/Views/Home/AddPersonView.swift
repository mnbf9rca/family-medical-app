import SwiftUI

/// Form view for adding a new person
struct AddPersonView: View {
    @Bindable var viewModel: HomeViewModel
    @Environment(\.dismiss)
    private var dismiss

    // Form state
    @State private var name = ""
    @State private var dateOfBirth: Date?
    @State private var selectedLabels: Set<String> = []
    @State private var customLabel = ""
    @State private var notes = ""
    @State private var showDatePicker = false

    // Validation
    @State private var showValidationError = false
    @State private var validationErrorMessage = ""

    // Common label suggestions
    private let suggestedLabels = ["Self", "Spouse", "Partner", "Child", "Parent", "Sibling"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Basic Information") {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()

                    Toggle("Include Date of Birth", isOn: $showDatePicker)

                    if showDatePicker {
                        DatePicker(
                            "Date of Birth",
                            selection: Binding(
                                get: { dateOfBirth ?? Date() },
                                set: { dateOfBirth = $0 }
                            ),
                            displayedComponents: .date
                        )
                        .datePickerStyle(.compact)
                    }
                }

                Section("Labels") {
                    ForEach(suggestedLabels, id: \.self) { label in
                        Toggle(label, isOn: Binding(
                            get: { selectedLabels.contains(label) },
                            set: { isSelected in
                                if isSelected {
                                    selectedLabels.insert(label)
                                } else {
                                    selectedLabels.remove(label)
                                }
                            }
                        ))
                    }

                    HStack {
                        TextField("Custom label", text: $customLabel)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()

                        Button("Add") {
                            addCustomLabel()
                        }
                        .disabled(customLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }

                    if !selectedLabels.subtracting(suggestedLabels).isEmpty {
                        Section("Custom Labels") {
                            ForEach(Array(selectedLabels.subtracting(suggestedLabels)).sorted(), id: \.self) { label in
                                HStack {
                                    Text(label)
                                    Spacer()
                                    Button(role: .destructive) {
                                        selectedLabels.remove(label)
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundStyle(.red)
                                    }
                                    .buttonStyle(.borderless)
                                }
                            }
                        }
                    }
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("Add Member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        savePerson()
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .alert("Validation Error", isPresented: $showValidationError) {
                Button("OK") {
                    showValidationError = false
                }
            } message: {
                Text(validationErrorMessage)
            }
            .onChange(of: viewModel.errorMessage) { _, newValue in
                if newValue == nil, !viewModel.isLoading {
                    // Success - dismiss the sheet
                    dismiss()
                }
            }
        }
    }

    private func addCustomLabel() {
        let trimmed = customLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        selectedLabels.insert(trimmed)
        customLabel = ""
    }

    private func savePerson() {
        // Validate name
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            validationErrorMessage = "Name is required"
            showValidationError = true
            return
        }

        guard trimmedName.count <= 100 else {
            validationErrorMessage = "Name must be 100 characters or less"
            showValidationError = true
            return
        }

        // Create person
        do {
            let person = try Person(
                id: UUID(),
                name: trimmedName,
                dateOfBirth: showDatePicker ? dateOfBirth : nil,
                labels: Array(selectedLabels),
                notes: notes.isEmpty ? nil : notes
            )

            Task {
                await viewModel.createPerson(person)
            }
        } catch {
            validationErrorMessage = error.localizedDescription
            showValidationError = true
        }
    }
}

#Preview {
    AddPersonView(viewModel: HomeViewModel())
}
