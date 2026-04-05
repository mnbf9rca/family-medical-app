import CryptoKit
import SwiftUI
import Testing
import ViewInspector
@testable import FamilyMedicalApp

@MainActor
struct FieldRendererInteractionTests {
    // MARK: - Test Helpers

    private func makeViewModel(recordType: RecordType = .immunization) throws -> GenericRecordFormViewModel {
        let person = try PersonTestHelper.makeTestPerson()
        let keyProvider = MockPrimaryKeyProvider()
        keyProvider.primaryKey = SymmetricKey(size: .bits256)
        let fmk = MockFamilyMemberKeyService()
        fmk.setFMK(SymmetricKey(size: .bits256), for: person.id.uuidString)
        return GenericRecordFormViewModel(
            person: person,
            recordType: recordType,
            medicalRecordRepository: MockMedicalRecordRepository(),
            recordContentService: MockRecordContentService(),
            primaryKeyProvider: keyProvider,
            fmkService: fmk,
            providerRepository: MockProviderRepository(),
            autocompleteService: AutocompleteServiceStub()
        )
    }

    private func pickerMetadata() throws -> FieldMetadata {
        try #require(ConditionRecord.fieldMetadata.first { $0.keyPath == "severity" })
    }

    private func autocompleteMetadata() throws -> FieldMetadata {
        try #require(ImmunizationRecord.fieldMetadata.first { $0.keyPath == "vaccineCode" })
    }

    private func componentsMetadata() throws -> FieldMetadata {
        try #require(ObservationRecord.fieldMetadata.first { $0.keyPath == "components" })
    }

    private func providerMetadata() throws -> FieldMetadata {
        try #require(ImmunizationRecord.fieldMetadata.first { $0.keyPath == "providerId" })
    }

    // MARK: - PickerFieldRenderer

    @Test
    func pickerFieldRendererRendersWithoutError() throws {
        let vm = try makeViewModel(recordType: .condition)
        let view = try PickerFieldRenderer(metadata: pickerMetadata(), viewModel: vm)
        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            _ = try inspected.find(ViewType.Picker.self)
        }
    }

    @Test
    func pickerFieldRendererDisplaysFieldName() throws {
        let vm = try makeViewModel(recordType: .condition)
        let view = try PickerFieldRenderer(metadata: pickerMetadata(), viewModel: vm)
        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            _ = try inspected.find(text: "Severity")
        }
    }

    @Test
    func pickerFieldRendererWithUnsetValue() throws {
        let vm = try makeViewModel(recordType: .condition)
        let view = try PickerFieldRenderer(metadata: pickerMetadata(), viewModel: vm)
        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            _ = try inspected.find(ViewType.Picker.self)
        }
    }

    @Test
    func pickerFieldRendererWithListedOption() throws {
        let vm = try makeViewModel(recordType: .condition)
        vm.setValue("Moderate", for: "severity")
        let view = try PickerFieldRenderer(metadata: pickerMetadata(), viewModel: vm)
        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            _ = try inspected.find(ViewType.Picker.self)
            #expect(throws: (any Error).self) {
                _ = try inspected.find(ViewType.TextField.self)
            }
        }
    }

    @Test
    func pickerFieldRendererWithCustomValueRevealsTextField() throws {
        let vm = try makeViewModel(recordType: .condition)
        vm.setValue("Extreme", for: "severity")
        let view = try PickerFieldRenderer(metadata: pickerMetadata(), viewModel: vm)
        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            _ = try inspected.find(ViewType.Picker.self)
            _ = try inspected.find(ViewType.TextField.self)
        }
    }

    // MARK: - AutocompleteFieldRenderer

    @Test
    func autocompleteFieldRendererRendersWithoutError() throws {
        let vm = try makeViewModel(recordType: .immunization)
        let view = try AutocompleteFieldRenderer(metadata: autocompleteMetadata(), viewModel: vm)
        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            _ = try inspected.find(ViewType.TextField.self)
        }
    }

    @Test
    func autocompleteFieldRendererDisplaysFieldName() throws {
        let vm = try makeViewModel(recordType: .immunization)
        let view = try AutocompleteFieldRenderer(metadata: autocompleteMetadata(), viewModel: vm)
        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            _ = try inspected.find(text: "Vaccine Name")
        }
    }

    @Test
    func autocompleteFieldRendererWithCatalogSource() throws {
        let person = try PersonTestHelper.makeTestPerson()
        let keyProvider = MockPrimaryKeyProvider()
        keyProvider.primaryKey = SymmetricKey(size: .bits256)
        let fmk = MockFamilyMemberKeyService()
        fmk.setFMK(SymmetricKey(size: .bits256), for: person.id.uuidString)
        let stub = AutocompleteServiceStub()
        stub.stubbedSuggestions[.cvxVaccines] = ["Pfizer-BioNTech COVID-19", "Moderna COVID-19"]
        let vm = GenericRecordFormViewModel(
            person: person,
            recordType: .immunization,
            medicalRecordRepository: MockMedicalRecordRepository(),
            recordContentService: MockRecordContentService(),
            primaryKeyProvider: keyProvider,
            fmkService: fmk,
            providerRepository: MockProviderRepository(),
            autocompleteService: stub
        )
        vm.setValue("Pfizer-BioNTech COVID-19", for: "vaccineCode")
        let view = try AutocompleteFieldRenderer(metadata: autocompleteMetadata(), viewModel: vm)
        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            _ = try inspected.find(ViewType.TextField.self)
        }
    }

    @Test
    func autocompleteFieldRendererWithProviderId() throws {
        let vm = try makeViewModel(recordType: .immunization)
        let providerUUID = UUID()
        vm.providers = [Provider(id: providerUUID, name: "Dr Who", organization: "Mercy")]
        vm.setValue(providerUUID, for: "providerId")
        let view = try AutocompleteFieldRenderer(metadata: providerMetadata(), viewModel: vm)
        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            _ = try inspected.find(ViewType.TextField.self)
            _ = try inspected.find(text: "Provider")
        }
    }

    @Test
    func autocompleteFieldRendererWithProviderIdButUnresolved() throws {
        let vm = try makeViewModel(recordType: .immunization)
        vm.setValue(UUID(), for: "providerId")
        let view = try AutocompleteFieldRenderer(metadata: providerMetadata(), viewModel: vm)
        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            _ = try inspected.find(ViewType.TextField.self)
        }
    }

    @Test
    func autocompleteFieldRendererWithEmptyProviderList() throws {
        let vm = try makeViewModel(recordType: .immunization)
        let view = try AutocompleteFieldRenderer(metadata: providerMetadata(), viewModel: vm)
        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            _ = try inspected.find(ViewType.TextField.self)
        }
    }

    // MARK: - ObservationComponentRenderer

    @Test
    func observationComponentRendererRendersWithoutError() throws {
        let vm = try makeViewModel(recordType: .observation)
        let view = try ObservationComponentRenderer(metadata: componentsMetadata(), viewModel: vm)
        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            _ = try inspected.find(ViewType.VStack.self)
        }
    }

    @Test
    func observationComponentRendererDisplaysFieldName() throws {
        let vm = try makeViewModel(recordType: .observation)
        let view = try ObservationComponentRenderer(metadata: componentsMetadata(), viewModel: vm)
        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            _ = try inspected.find(text: "Measurements")
        }
    }

    @Test
    func observationComponentRendererRendersEmptyStateMessage() throws {
        let vm = try makeViewModel(recordType: .observation)
        let view = try ObservationComponentRenderer(metadata: componentsMetadata(), viewModel: vm)
        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            _ = try inspected.find(text: "No measurements. Tap Add to enter a value.")
        }
    }

    @Test
    func observationComponentRendererRendersPrePopulatedComponent() throws {
        let vm = try makeViewModel(recordType: .observation)
        vm.setValue([ObservationComponent(name: "Weight", value: 70, unit: "kg")], for: "components")
        let view = try ObservationComponentRenderer(metadata: componentsMetadata(), viewModel: vm)
        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            _ = try inspected.find(ViewType.HStack.self)
        }
    }

    @Test
    func observationComponentRendererAddsComponentOnButtonTap() throws {
        let vm = try makeViewModel(recordType: .observation)
        let view = try ObservationComponentRenderer(metadata: componentsMetadata(), viewModel: vm)
        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            let addButton = try inspected.find(ViewType.Button.self)
            try addButton.tap()
        }
        let stored = vm.componentsValue(for: "components")
        #expect(stored.count == 1)
    }

    @Test
    func observationComponentRendererRemovesComponentOnMinusTap() throws {
        let vm = try makeViewModel(recordType: .observation)
        vm.setValue(
            [
                ObservationComponent(name: "Systolic", value: 120, unit: "mmHg"),
                ObservationComponent(name: "Diastolic", value: 80, unit: "mmHg")
            ],
            for: "components"
        )
        let view = try ObservationComponentRenderer(metadata: componentsMetadata(), viewModel: vm)
        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            let removeButton = try inspected.find(viewWithAccessibilityLabel: "Remove Systolic").button()
            try removeButton.tap()
        }
        let remaining = vm.componentsValue(for: "components")
        #expect(remaining.count == 1)
        #expect(remaining.first?.name == "Diastolic")
    }

    @Test
    func observationComponentRenderer_prePopulatedValuePersistsOnRender() throws {
        // Guards `syncToParent`'s new parse-guard: rendering a component with a valid
        // prior value must not clobber that value. Before the fix, seeding the renderer
        // with a prepopulated component would sync a parsed 0 back to the parent on
        // certain @State lifecycle events.
        let vm = try makeViewModel(recordType: .observation)
        let original = ObservationComponent(name: "Weight", value: 70, unit: "kg")
        vm.setValue([original], for: "components")
        let view = try ObservationComponentRenderer(metadata: componentsMetadata(), viewModel: vm)

        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            _ = try inspected.find(ViewType.HStack.self)
        }

        let components = vm.componentsValue(for: "components")
        #expect(components.count == 1)
        #expect(components.first?.value == 70)
        // id is preserved through the render cycle.
        #expect(components.first?.id == original.id)
    }

    @Test
    func observationComponentRendererRemovesLastComponentStoresNil() throws {
        let vm = try makeViewModel(recordType: .observation)
        vm.setValue([ObservationComponent(name: "Weight", value: 70, unit: "kg")], for: "components")
        let view = try ObservationComponentRenderer(metadata: componentsMetadata(), viewModel: vm)
        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            let removeButton = try inspected.find(viewWithAccessibilityLabel: "Remove Weight").button()
            try removeButton.tap()
        }
        #expect(vm.value(for: "components") == nil)
    }
}
