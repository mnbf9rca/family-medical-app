import SwiftUI

/// Detail view for creating or editing a Provider
struct ProviderDetailView: View {
    let person: Person
    let existingProvider: Provider?
    let onSave: (Provider) async -> Bool

    @Environment(\.dismiss)
    private var dismiss

    @State private var name: String
    @State private var organization: String
    @State private var specialty: String
    @State private var phone: String
    @State private var address: String
    @State private var notes: String
    @State private var validationError: String?
    @State private var saveError: String?
    @State private var isSaving = false

    init(
        person: Person,
        existingProvider: Provider? = nil,
        onSave: @escaping (Provider) async -> Bool
    ) {
        self.person = person
        self.existingProvider = existingProvider
        self.onSave = onSave
        self._name = State(initialValue: existingProvider?.name ?? "")
        self._organization = State(initialValue: existingProvider?.organization ?? "")
        self._specialty = State(initialValue: existingProvider?.specialty ?? "")
        self._phone = State(initialValue: existingProvider?.phone ?? "")
        self._address = State(initialValue: existingProvider?.address ?? "")
        self._notes = State(initialValue: existingProvider?.notes ?? "")
    }

    private var isEditing: Bool {
        existingProvider != nil
    }

    private var trimmedName: String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var trimmedOrganization: String? {
        let trimmed = organization.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var body: some View {
        NavigationStack {
            Form {
                if existingProvider == nil {
                    Section {
                        Text("Is this a person or a practice? Fill in their name, organization, or both.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Provider Information") {
                    TextField("Name", text: $name)
                        .textContentType(.name)
                        .accessibilityLabel("Provider name")

                    TextField("Organization", text: $organization)
                        .textContentType(.organizationName)
                        .accessibilityLabel("Organization")

                    TextField("Specialty", text: $specialty)
                        .accessibilityLabel("Specialty")
                }

                Section("Contact") {
                    TextField("Phone", text: $phone)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                        .accessibilityLabel("Phone number")

                    TextField("Address", text: $address)
                        .textContentType(.fullStreetAddress)
                        .accessibilityLabel("Address")
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                        .accessibilityLabel("Notes")
                }

                if let validationError {
                    Section {
                        Text(validationError)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }

                if let saveError {
                    Section {
                        Text(saveError)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Provider" : "New Provider")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(isSaving)
                }
            }
        }
    }

    private func save() async {
        validationError = nil
        saveError = nil

        guard trimmedName != nil || trimmedOrganization != nil else {
            validationError = "Please provide at least a name or organization."
            return
        }

        isSaving = true

        let provider = if let existing = existingProvider {
            Provider(
                id: existing.id,
                name: trimmedName,
                organization: trimmedOrganization,
                specialty: nonEmpty(specialty),
                phone: nonEmpty(phone),
                address: nonEmpty(address),
                notes: nonEmpty(notes),
                createdAt: existing.createdAt,
                updatedAt: Date(),
                version: existing.version + 1,
                previousVersionId: nil
            )
        } else {
            Provider(
                name: trimmedName,
                organization: trimmedOrganization,
                specialty: nonEmpty(specialty),
                phone: nonEmpty(phone),
                address: nonEmpty(address),
                notes: nonEmpty(notes)
            )
        }

        let success = await onSave(provider)
        isSaving = false

        if success {
            dismiss()
        } else {
            saveError = "Unable to save provider. Please try again."
        }
    }

    private func nonEmpty(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
