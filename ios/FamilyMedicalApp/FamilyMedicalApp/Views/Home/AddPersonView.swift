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

    /// Track person being created to avoid race conditions
    @State private var creatingPersonId: UUID?

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
            .onChange(of: viewModel.persons) { _, newPersons in
                // Check if the person we created is now in the list
                if let creatingId = creatingPersonId,
                   newPersons.contains(where: { $0.id == creatingId }),
                   !viewModel.isLoading {
                    // Success - our person was added, dismiss the sheet
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

        guard trimmedName.count <= Person.nameMaxLength else {
            validationErrorMessage = "Name must be \(Person.nameMaxLength) characters or less"
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

            creatingPersonId = person.id
            Task {
                await viewModel.createPerson(person)
            }
        } catch {
            validationErrorMessage = "Unable to save this member. Please try again."
            LoggingService.shared.logger(category: .ui).logError(error, context: "AddPersonView.savePerson")
            showValidationError = true
            creatingPersonId = nil
        }
    }
}

#Preview {
    AddPersonView(viewModel: HomeViewModel())
}
