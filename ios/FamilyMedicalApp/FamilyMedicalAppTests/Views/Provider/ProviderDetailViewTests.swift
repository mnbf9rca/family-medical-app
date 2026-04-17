import SwiftUI
import Testing
import ViewInspector
@testable import FamilyMedicalApp

/// Structural, mode, button, and section tests for ProviderDetailView.
///
/// Field presence and pre-fill tests live in ProviderDetailViewFieldTests.
@MainActor
struct ProviderDetailViewTests {
    // MARK: - Test Data

    func makeTestPerson(name: String = "Test Person") throws -> Person {
        try PersonTestHelper.makeTestPerson(name: name)
    }

    func makeProvider(
        name: String? = "Dr. Smith",
        organization: String? = nil,
        specialty: String? = "Cardiology",
        phone: String? = "555-0100",
        address: String? = "123 Main St",
        notes: String? = "Great doctor"
    ) -> Provider {
        Provider(
            name: name,
            organization: organization,
            specialty: specialty,
            phone: phone,
            address: address,
            notes: notes
        )
    }

    // MARK: - Create Mode Tests

    @Test
    func viewRendersInCreateMode() throws {
        let person = try makeTestPerson()
        let view = ProviderDetailView(person: person) { _ in true }

        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            _ = try inspected.find(ViewType.NavigationStack.self)
        }
    }

    @Test
    func viewRendersFormInCreateMode() throws {
        let person = try makeTestPerson()
        let view = ProviderDetailView(person: person) { _ in true }

        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            _ = try inspected.find(ViewType.Form.self)
        }
    }

    @Test
    func viewShowsUXHintInCreateMode() throws {
        let person = try makeTestPerson()
        let view = ProviderDetailView(person: person) { _ in true }

        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            _ = try inspected.find(text: "Is this a person or a practice? Fill in their name, organization, or both.")
        }
    }

    @Test
    func viewDoesNotShowUXHintInEditMode() throws {
        let person = try makeTestPerson()
        let existingProvider = makeProvider()
        let view = ProviderDetailView(person: person, existingProvider: existingProvider) { _ in true }

        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            // In edit mode, the hint section should not be present
            let hintText = try? inspected
                .find(text: "Is this a person or a practice? Fill in their name, organization, or both.")
            #expect(hintText == nil)
        }
    }

    // MARK: - Edit Mode Tests

    @Test
    func viewRendersInEditMode() throws {
        let person = try makeTestPerson()
        let existingProvider = makeProvider()
        let view = ProviderDetailView(person: person, existingProvider: existingProvider) { _ in true }

        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            _ = try inspected.find(ViewType.NavigationStack.self)
        }
    }

    @Test
    func viewRendersFormInEditMode() throws {
        let person = try makeTestPerson()
        let existingProvider = makeProvider()
        let view = ProviderDetailView(person: person, existingProvider: existingProvider) { _ in true }

        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            _ = try inspected.find(ViewType.Form.self)
        }
    }

    // MARK: - Button Tests

    @Test
    func saveButtonExists() throws {
        let person = try makeTestPerson()
        let view = ProviderDetailView(person: person) { _ in true }

        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            _ = try inspected.find(button: "Save")
        }
    }

    @Test
    func cancelButtonExists() throws {
        let person = try makeTestPerson()
        let view = ProviderDetailView(person: person) { _ in true }

        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            _ = try inspected.find(button: "Cancel")
        }
    }

    // MARK: - Section Tests

    @Test
    func formHasProviderInformationSection() throws {
        let person = try makeTestPerson()
        let view = ProviderDetailView(person: person) { _ in true }

        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            let form = try inspected.find(ViewType.Form.self)
            // Create mode: section 0 is the hint, section 1 is Provider Information
            _ = try form.section(0)
            _ = try form.section(1)
        }
    }

    @Test
    func formHasContactSection() throws {
        let person = try makeTestPerson()
        let view = ProviderDetailView(person: person) { _ in true }

        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            let form = try inspected.find(ViewType.Form.self)
            // Create mode: section 0=hint, 1=provider info, 2=contact
            _ = try form.section(2)
        }
    }

    @Test
    func formHasNotesSection() throws {
        let person = try makeTestPerson()
        let view = ProviderDetailView(person: person) { _ in true }

        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            let form = try inspected.find(ViewType.Form.self)
            // Create mode: section 0=hint, 1=provider info, 2=contact, 3=notes
            _ = try form.section(3)
        }
    }

    @Test
    func editModeFormHasExpectedSections() throws {
        let person = try makeTestPerson()
        let existingProvider = makeProvider()
        let view = ProviderDetailView(person: person, existingProvider: existingProvider) { _ in true }

        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            let form = try inspected.find(ViewType.Form.self)
            // Edit mode: conditional hint section is absent (Optional at index 0),
            // so real sections start at index 1 in ViewInspector
            _ = try form.section(1)
            _ = try form.section(2)
            _ = try form.section(3)
        }
    }

    // MARK: - Empty Field Tests

    @Test
    func createModeFieldsStartEmpty() throws {
        let person = try makeTestPerson()
        let view = ProviderDetailView(person: person) { _ in true }

        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            let nameField = try inspected.find(ViewType.TextField.self) {
                try $0.labelView().text().string() == "Name"
            }
            let inputValue = try nameField.input()
            #expect(inputValue.isEmpty)
        }
    }

    @Test
    func viewRendersWithAllProviderFields() throws {
        let person = try makeTestPerson()
        let existingProvider = Provider(
            name: "Dr. Full",
            organization: "Full Org",
            specialty: "Full Spec",
            phone: "555-9999",
            address: "789 Full St",
            notes: "Full notes"
        )
        let view = ProviderDetailView(person: person, existingProvider: existingProvider) { _ in true }

        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            _ = try inspected.find(ViewType.Form.self)
            // Verify all text fields are present
            let textFields = inspected.findAll(ViewType.TextField.self)
            #expect(textFields.count == 5)
        }
    }
}
