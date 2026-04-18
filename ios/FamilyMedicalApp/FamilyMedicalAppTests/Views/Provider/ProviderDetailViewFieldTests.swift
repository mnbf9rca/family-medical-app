import SwiftUI
import Testing
import ViewInspector
@testable import FamilyMedicalApp

/// Form field presence and pre-fill tests for ProviderDetailView.
///
/// Split from ProviderDetailViewTests to stay within type_body_length limits.
@MainActor
struct ProviderDetailViewFieldTests {
    // MARK: - Form Field Tests

    @Test
    func formHasNameField() throws {
        let person = try PersonTestHelper.makeTestPerson()
        let view = ProviderDetailView(person: person) { _ in true }

        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            let form = try inspected.find(ViewType.Form.self)
            // Provider Information section has Name, Organization, Specialty
            _ = try form.find(ViewType.TextField.self) {
                try $0.labelView().text().string() == "Name"
            }
        }
    }

    @Test
    func formHasOrganizationField() throws {
        let person = try PersonTestHelper.makeTestPerson()
        let view = ProviderDetailView(person: person) { _ in true }

        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            let form = try inspected.find(ViewType.Form.self)
            _ = try form.find(ViewType.TextField.self) {
                try $0.labelView().text().string() == "Organization"
            }
        }
    }

    @Test
    func formHasSpecialtyField() throws {
        let person = try PersonTestHelper.makeTestPerson()
        let view = ProviderDetailView(person: person) { _ in true }

        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            let form = try inspected.find(ViewType.Form.self)
            _ = try form.find(ViewType.TextField.self) {
                try $0.labelView().text().string() == "Specialty"
            }
        }
    }

    @Test
    func formHasPhoneField() throws {
        let person = try PersonTestHelper.makeTestPerson()
        let view = ProviderDetailView(person: person) { _ in true }

        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            let form = try inspected.find(ViewType.Form.self)
            _ = try form.find(ViewType.TextField.self) {
                try $0.labelView().text().string() == "Phone"
            }
        }
    }

    @Test
    func formHasAddressField() throws {
        let person = try PersonTestHelper.makeTestPerson()
        let view = ProviderDetailView(person: person) { _ in true }

        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            let form = try inspected.find(ViewType.Form.self)
            _ = try form.find(ViewType.TextField.self) {
                try $0.labelView().text().string() == "Address"
            }
        }
    }

    @Test
    func formHasNotesField() throws {
        let person = try PersonTestHelper.makeTestPerson()
        let view = ProviderDetailView(person: person) { _ in true }

        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            let form = try inspected.find(ViewType.Form.self)
            _ = try form.find(ViewType.TextEditor.self)
        }
    }

    // MARK: - Pre-filled Data Tests

    @Test
    func formPreFillsNameFromExistingProvider() throws {
        let person = try PersonTestHelper.makeTestPerson()
        let existingProvider = ProviderTestHelper.makeProvider(name: "Dr. Jane Doe")
        let view = ProviderDetailView(person: person, existingProvider: existingProvider) { _ in true }

        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            let nameField = try inspected.find(ViewType.TextField.self) {
                try $0.labelView().text().string() == "Name"
            }
            let inputValue = try nameField.input()
            #expect(inputValue == "Dr. Jane Doe")
        }
    }

    @Test
    func formPreFillsOrganizationFromExistingProvider() throws {
        let person = try PersonTestHelper.makeTestPerson()
        let existingProvider = ProviderTestHelper.makeProvider(name: "Dr. Smith", organization: "City Hospital")
        let view = ProviderDetailView(person: person, existingProvider: existingProvider) { _ in true }

        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            let orgField = try inspected.find(ViewType.TextField.self) {
                try $0.labelView().text().string() == "Organization"
            }
            let inputValue = try orgField.input()
            #expect(inputValue == "City Hospital")
        }
    }

    @Test
    func formPreFillsSpecialtyFromExistingProvider() throws {
        let person = try PersonTestHelper.makeTestPerson()
        let existingProvider = ProviderTestHelper.makeProvider(specialty: "Neurology")
        let view = ProviderDetailView(person: person, existingProvider: existingProvider) { _ in true }

        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            let specialtyField = try inspected.find(ViewType.TextField.self) {
                try $0.labelView().text().string() == "Specialty"
            }
            let inputValue = try specialtyField.input()
            #expect(inputValue == "Neurology")
        }
    }

    @Test
    func formPreFillsPhoneFromExistingProvider() throws {
        let person = try PersonTestHelper.makeTestPerson()
        let existingProvider = ProviderTestHelper.makeProvider(phone: "555-1234")
        let view = ProviderDetailView(person: person, existingProvider: existingProvider) { _ in true }

        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            let phoneField = try inspected.find(ViewType.TextField.self) {
                try $0.labelView().text().string() == "Phone"
            }
            let inputValue = try phoneField.input()
            #expect(inputValue == "555-1234")
        }
    }

    @Test
    func formPreFillsAddressFromExistingProvider() throws {
        let person = try PersonTestHelper.makeTestPerson()
        let existingProvider = ProviderTestHelper.makeProvider(address: "456 Oak Ave")
        let view = ProviderDetailView(person: person, existingProvider: existingProvider) { _ in true }

        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            let addressField = try inspected.find(ViewType.TextField.self) {
                try $0.labelView().text().string() == "Address"
            }
            let inputValue = try addressField.input()
            #expect(inputValue == "456 Oak Ave")
        }
    }

    @Test
    func formPreFillsNotesFromExistingProvider() throws {
        let person = try PersonTestHelper.makeTestPerson()
        let existingProvider = ProviderTestHelper.makeProvider(notes: "Very helpful")
        let view = ProviderDetailView(person: person, existingProvider: existingProvider) { _ in true }

        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            _ = try inspected.find(ViewType.TextEditor.self)
        }
    }
}
