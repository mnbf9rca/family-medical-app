import CryptoKit
import SwiftUI
import Testing
import ViewInspector
@testable import FamilyMedicalApp

@MainActor
struct GenericRecordFormViewTests {
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

    // MARK: - Rendering tests

    @Test
    func viewRendersForm() throws {
        let vm = try makeViewModel()
        let view = GenericRecordFormView(viewModel: vm)

        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.Form.self)
    }

    @Test
    func viewRendersNavigationStack() throws {
        let vm = try makeViewModel()
        let view = GenericRecordFormView(viewModel: vm)

        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.NavigationStack.self)
    }

    @Test
    func viewRendersTitleForCreateMode() throws {
        let vm = try makeViewModel(recordType: .immunization)
        let view = GenericRecordFormView(viewModel: vm)

        // In create mode the title is "New \(displayName)".
        // displayName for .immunization is "Immunization".
        #expect(vm.isEditing == false)
        #expect(vm.displayName == "Immunization")

        // Ensure the view renders (navigation title is set as a modifier).
        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.Form.self)
    }

    @Test
    func viewRendersForwardCompatWarning() throws {
        let vm = try makeViewModel()
        vm.forwardCompatibilityWarning = "Test warning"
        let view = GenericRecordFormView(viewModel: vm)

        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.Label.self)
    }

    @Test
    func viewRendersErrorMessageSection() throws {
        let vm = try makeViewModel()
        vm.errorMessage = "boom"
        let view = GenericRecordFormView(viewModel: vm)

        let inspected = try view.inspect()
        _ = try inspected.find(text: "boom")
    }

    @Test
    func viewRendersSaveButton() throws {
        let vm = try makeViewModel()
        let view = GenericRecordFormView(viewModel: vm)

        let inspected = try view.inspect()
        _ = try inspected.find(button: "Save")
    }

    @Test
    func viewRendersCancelButton() throws {
        let vm = try makeViewModel()
        let view = GenericRecordFormView(viewModel: vm)

        let inspected = try view.inspect()
        _ = try inspected.find(button: "Cancel")
    }

    @Test(arguments: RecordType.allCases)
    func viewRendersForEachRecordType(_ recordType: RecordType) throws {
        let vm = try makeViewModel(recordType: recordType)
        let view = GenericRecordFormView(viewModel: vm)

        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.Form.self)
        // Validate the ViewModel has metadata entries for this record type.
        #expect(vm.fieldMetadata.count == recordType.fieldMetadata.count)
    }

    @Test
    func viewRendersSavingProgressOverlayWhenIsSaving() throws {
        let vm = try makeViewModel()
        vm.isSaving = true
        let view = GenericRecordFormView(viewModel: vm)

        let inspected = try view.inspect()
        _ = try inspected.find(ViewType.ProgressView.self)
    }
}
