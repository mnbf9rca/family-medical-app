import CryptoKit
import SwiftUI
import Testing
import ViewInspector
@testable import FamilyMedicalApp

@MainActor
struct FieldRendererTests {
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

    private func textMetadata() throws -> FieldMetadata {
        try #require(ImmunizationRecord.fieldMetadata.first { $0.keyPath == "lotNumber" })
    }

    private func dateMetadata() throws -> FieldMetadata {
        try #require(ImmunizationRecord.fieldMetadata.first { $0.keyPath == "occurrenceDate" })
    }

    private func integerMetadata() throws -> FieldMetadata {
        try #require(ImmunizationRecord.fieldMetadata.first { $0.keyPath == "doseNumber" })
    }

    // MARK: - TextFieldRenderer

    @Test
    func textFieldRendererRendersWithoutError() throws {
        let vm = try makeViewModel(recordType: .immunization)
        let view = try TextFieldRenderer(metadata: textMetadata(), viewModel: vm)
        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.TextField.self)
    }

    @Test
    func textFieldRendererDisplaysFieldName() throws {
        let vm = try makeViewModel(recordType: .immunization)
        let view = try TextFieldRenderer(metadata: textMetadata(), viewModel: vm)
        let inspected = try view.inspect()
        _ = try inspected.find(text: "Lot Number")
    }

    @Test
    func textFieldRendererShowsPlaceholderText() throws {
        let vm = try makeViewModel(recordType: .immunization)
        let metadata = try textMetadata()
        let view = TextFieldRenderer(metadata: metadata, viewModel: vm)
        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.TextField.self)
        #expect(metadata.placeholder == "e.g., EL9262")
    }

    @Test
    func textFieldRendererShowsRequiredIndicator() throws {
        let vm = try makeViewModel(recordType: .condition)
        let conditionNameMetadata = try #require(
            ConditionRecord.fieldMetadata.first { $0.keyPath == "conditionName" }
        )
        let view = TextFieldRenderer(metadata: conditionNameMetadata, viewModel: vm)
        let inspected = try view.inspect()
        _ = try inspected.find(text: "*")
    }

    // MARK: - DateFieldRenderer

    @Test
    func dateFieldRendererRendersWithoutError() throws {
        let vm = try makeViewModel(recordType: .immunization)
        let view = try DateFieldRenderer(metadata: dateMetadata(), viewModel: vm)
        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.DatePicker.self)
    }

    @Test
    func dateFieldRendererDisplaysFieldName() throws {
        let vm = try makeViewModel(recordType: .immunization)
        let view = try DateFieldRenderer(metadata: dateMetadata(), viewModel: vm)
        let inspected = try view.inspect()
        _ = try inspected.find(text: "Date Administered")
    }

    @Test
    func dateFieldRendererRendersWithPrePopulatedDate() throws {
        let vm = try makeViewModel(recordType: .immunization)
        vm.setValue(Date(timeIntervalSinceReferenceDate: 100_000), for: "occurrenceDate")
        let view = try DateFieldRenderer(metadata: dateMetadata(), viewModel: vm)
        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.DatePicker.self)
    }

    @Test
    func dateFieldRendererShowsClearButtonForOptionalDateWhenSet() throws {
        let vm = try makeViewModel(recordType: .immunization)
        let expirationMetadata = try #require(
            ImmunizationRecord.fieldMetadata.first { $0.keyPath == "expirationDate" }
        )
        vm.setValue(Date(), for: "expirationDate")
        let view = DateFieldRenderer(metadata: expirationMetadata, viewModel: vm)
        let inspected = try view.inspect()
        _ = try inspected.find(button: "Clear")
    }

    @Test
    func dateFieldRendererHidesClearButtonForOptionalDateWhenUnset() throws {
        let vm = try makeViewModel(recordType: .immunization)
        let expirationMetadata = try #require(
            ImmunizationRecord.fieldMetadata.first { $0.keyPath == "expirationDate" }
        )
        let view = DateFieldRenderer(metadata: expirationMetadata, viewModel: vm)
        let inspected = try view.inspect()
        #expect(throws: (any Error).self) {
            _ = try inspected.find(button: "Clear")
        }
    }

    @Test
    func dateFieldRendererClearButtonTriggersNilValue() throws {
        let vm = try makeViewModel(recordType: .immunization)
        let expirationMetadata = try #require(
            ImmunizationRecord.fieldMetadata.first { $0.keyPath == "expirationDate" }
        )
        vm.setValue(Date(), for: "expirationDate")
        #expect(vm.value(for: "expirationDate") != nil)
        let view = DateFieldRenderer(metadata: expirationMetadata, viewModel: vm)
        let inspected = try view.inspect()
        let clearButton = try inspected.find(button: "Clear")
        try clearButton.tap()
        #expect(vm.value(for: "expirationDate") == nil)
    }

    @Test
    func dateFieldRendererBindingSetUpdatesViewModel() throws {
        let vm = try makeViewModel(recordType: .immunization)
        let newDate = Date(timeIntervalSinceReferenceDate: 777_000)
        vm.setValue(newDate, for: "occurrenceDate")
        let view = try DateFieldRenderer(metadata: dateMetadata(), viewModel: vm)
        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.DatePicker.self)
        let storedDate = vm.value(for: "occurrenceDate") as? Date
        #expect(storedDate == newDate)
    }

    // MARK: - NumberFieldRenderer

    @Test
    func numberFieldRendererRendersWithoutError() throws {
        let vm = try makeViewModel(recordType: .immunization)
        let view = try NumberFieldRenderer(metadata: integerMetadata(), viewModel: vm)
        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.TextField.self)
    }

    @Test
    func numberFieldRendererDisplaysFieldName() throws {
        let vm = try makeViewModel(recordType: .immunization)
        let view = try NumberFieldRenderer(metadata: integerMetadata(), viewModel: vm)
        let inspected = try view.inspect()
        _ = try inspected.find(text: "Dose Number")
    }

    @Test
    func numberFieldRendererRendersWithPrePopulatedIntValue() throws {
        let vm = try makeViewModel(recordType: .immunization)
        vm.setValue(5, for: "doseNumber")
        let view = try NumberFieldRenderer(metadata: integerMetadata(), viewModel: vm)
        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.TextField.self)
    }

    @Test
    func numberFieldRendererHandlesDoubleValue() throws {
        let vm = try makeViewModel(recordType: .immunization)
        let numberMetadata = FieldMetadata(
            keyPath: "customNumber",
            displayName: "Custom Number",
            fieldType: .number,
            placeholder: "0.0",
            displayOrder: 1
        )
        vm.setValue(Double(3.14), for: "customNumber")
        let view = NumberFieldRenderer(metadata: numberMetadata, viewModel: vm)
        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.TextField.self)
        _ = try inspected.find(text: "Custom Number")
    }

    @Test
    func numberFieldRendererHandlesEmptyValue() throws {
        let vm = try makeViewModel(recordType: .immunization)
        let numberMetadata = FieldMetadata(
            keyPath: "otherNumber",
            displayName: "Other Number",
            fieldType: .number,
            displayOrder: 1
        )
        let view = NumberFieldRenderer(metadata: numberMetadata, viewModel: vm)
        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.TextField.self)
    }
}
