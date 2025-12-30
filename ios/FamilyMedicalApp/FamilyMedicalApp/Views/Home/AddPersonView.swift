import SwiftUI

/// Form view for adding a new person
struct AddPersonView: View {
    @Bindable var viewModel: HomeViewModel
    @Environment(\.dismiss)
    private var dismiss

    // Form state
    @State private var name = ""
    @State private var dateOfBirth: Date?
    @State private var notes = ""
    @State private var showDatePicker = false

    // Validation
    @State private var showValidationError = false
    @State private var validationErrorMessage = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()

                    Toggle("Include Date of Birth", isOn: $showDatePicker)
                        .accessibilityIdentifier("includeDateOfBirthToggle")

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
                        .accessibilityIdentifier("dateOfBirthPicker")
                    }

                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3 ... 6)
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
            .onChange(of: viewModel.persons.count) { oldCount, newCount in
                if newCount > oldCount, !viewModel.isLoading {
                    // Success - new person added, dismiss the sheet
                    dismiss()
                }
            }
        }
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
                labels: [],
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
