import CryptoKit
import SwiftUI
import Testing
import ViewInspector
@testable import FamilyMedicalApp

@MainActor
struct BooleanFieldRendererTests {
    private func makeViewModel() throws -> GenericRecordFormViewModel {
        let person = try PersonTestHelper.makeTestPerson()
        let keyProvider = MockPrimaryKeyProvider()
        keyProvider.primaryKey = SymmetricKey(size: .bits256)
        let fmk = MockFamilyMemberKeyService()
        fmk.setFMK(SymmetricKey(size: .bits256), for: person.id.uuidString)
        return GenericRecordFormViewModel(
            person: person,
            recordType: .familyMemberHistory,
            medicalRecordRepository: MockMedicalRecordRepository(),
            recordContentService: MockRecordContentService(),
            primaryKeyProvider: keyProvider,
            fmkService: fmk,
            providerRepository: MockProviderRepository(),
            autocompleteService: AutocompleteServiceStub()
        )
    }

    private func deceasedMetadata() throws -> FieldMetadata {
        try #require(
            FamilyMemberHistoryRecord.fieldMetadata.first { $0.keyPath == "deceased" }
        )
    }

    @Test
    func rendersToggle() throws {
        let vm = try makeViewModel()
        let view = try BooleanFieldRenderer(metadata: deceasedMetadata(), viewModel: vm)
        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            _ = try inspected.find(ViewType.Toggle.self)
        }
    }

    @Test
    func displaysFieldName() throws {
        let vm = try makeViewModel()
        let view = try BooleanFieldRenderer(metadata: deceasedMetadata(), viewModel: vm)
        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            _ = try inspected.find(text: "Deceased")
        }
    }

    @Test
    func rendersWithPrePopulatedTrue() throws {
        let vm = try makeViewModel()
        vm.setValue(true, for: "deceased")
        let view = try BooleanFieldRenderer(metadata: deceasedMetadata(), viewModel: vm)
        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            _ = try inspected.find(ViewType.Toggle.self)
        }
    }

    @Test
    func bindingReadsStoredBoolean() throws {
        let vm = try makeViewModel()
        vm.setValue(true, for: "deceased")
        #expect(vm.boolValue(for: "deceased") == true)
        vm.setValue(false, for: "deceased")
        #expect(vm.boolValue(for: "deceased") == false)
    }

    @Test
    func boolValueReturnsNilWhenUnset() throws {
        let vm = try makeViewModel()
        #expect(vm.boolValue(for: "deceased") == nil)
    }

    @Test
    func bindingSetterWritesToViewModel() throws {
        // Drives the binding's `set` closure to verify the renderer writes back to the VM.
        let vm = try makeViewModel()
        let view = try BooleanFieldRenderer(metadata: deceasedMetadata(), viewModel: vm)
        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            let toggle = try inspected.find(ViewType.Toggle.self)
            try toggle.tap()
        }
        #expect(vm.boolValue(for: "deceased") == true)
    }

    @Test
    func displaysRequiredIndicator() throws {
        // Builds a required boolean metadata to exercise the isRequired true path
        // (FamilyMemberHistoryRecord.deceased is optional, so the production metadata
        // doesn't hit the required indicator branch).
        let requiredBool = FieldMetadata(
            keyPath: "mandatoryFlag",
            displayName: "Mandatory Flag",
            fieldType: .boolean,
            isRequired: true,
            displayOrder: 1
        )
        let vm = try makeViewModel()
        let view = BooleanFieldRenderer(metadata: requiredBool, viewModel: vm)
        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            _ = try inspected.find(text: "*")
        }
    }

    @Test
    func displaysValidationError() throws {
        let vm = try makeViewModel()
        vm.validationErrors["deceased"] = "Required"
        let view = try BooleanFieldRenderer(metadata: deceasedMetadata(), viewModel: vm)
        try HostedInspection.inspect(view) { view in
            let inspected = try view.inspect()
            _ = try inspected.find(text: "Required")
        }
    }

    @Test
    func saveRoundTripsBooleanThroughFamilyMemberHistoryRecord() async throws {
        // Guard against the bug: .boolean previously dispatched to TextFieldRenderer,
        // causing JSONDecoder to fail decoding a String as Bool?.
        let person = try PersonTestHelper.makeTestPerson()
        let keyProvider = MockPrimaryKeyProvider()
        keyProvider.primaryKey = SymmetricKey(size: .bits256)
        let fmk = MockFamilyMemberKeyService()
        let fmkKey = SymmetricKey(size: .bits256)
        fmk.setFMK(fmkKey, for: person.id.uuidString)
        let repo = MockMedicalRecordRepository()
        let content = MockRecordContentService()
        let vm = GenericRecordFormViewModel(
            person: person,
            recordType: .familyMemberHistory,
            medicalRecordRepository: repo,
            recordContentService: content,
            primaryKeyProvider: keyProvider,
            fmkService: fmk,
            providerRepository: MockProviderRepository(),
            autocompleteService: AutocompleteServiceStub()
        )
        vm.setValue("Mother", for: "relationship")
        vm.setValue("Hypertension", for: "conditionName")
        vm.setValue(true, for: "deceased")

        let ok = await vm.save()

        #expect(ok == true)
        let saved = try #require(repo.getAllRecords().first)
        let envelope = try content.decrypt(saved.encryptedContent, using: fmkKey)
        let decoded = try envelope.decode(FamilyMemberHistoryRecord.self)
        #expect(decoded.deceased == true)
    }
}
