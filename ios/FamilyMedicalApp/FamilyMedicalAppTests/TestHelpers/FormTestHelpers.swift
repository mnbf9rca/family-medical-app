import CryptoKit
import Foundation
@testable import FamilyMedicalApp

/// Shared stub for `AutocompleteServiceProtocol`. Named to avoid collision with the
/// file-private `MockAutocompleteService` defined inside `AutocompleteServiceTests.swift`.
final class AutocompleteServiceStub: AutocompleteServiceProtocol, @unchecked Sendable {
    var stubbedSuggestions: [AutocompleteSource: [String]] = [:]
    var stubbedObservationTypes: [ObservationTypeDefinition] = []

    func suggestions(for source: AutocompleteSource, query: String) -> [String] {
        let list = stubbedSuggestions[source] ?? []
        guard !query.isEmpty else { return list }
        return list.filter { $0.localizedCaseInsensitiveContains(query) }
    }

    func observationTypes() -> [ObservationTypeDefinition] {
        stubbedObservationTypes
    }
}

/// Dependency bag for `GenericRecordFormViewModel` tests. Wires a fresh set of mocks and
/// populates the primary key + FMK so `save()` can complete end-to-end without touching
/// the Keychain or Core Data.
struct FormViewModelDeps {
    let repo = MockMedicalRecordRepository()
    let content = MockRecordContentService()
    let keyProvider = MockPrimaryKeyProvider()
    let fmk = MockFamilyMemberKeyService()
    let providers = MockProviderRepository()
    let autocomplete = AutocompleteServiceStub()
    let fmkKey = SymmetricKey(size: .bits256)

    init(personId: UUID) {
        keyProvider.primaryKey = SymmetricKey(size: .bits256)
        fmk.setFMK(fmkKey, for: personId.uuidString)
    }
}

@MainActor
enum FormTestSupport {
    static func makeViewModel(
        person: Person,
        recordType: RecordType,
        existingRecord: DecryptedRecord? = nil,
        deps: FormViewModelDeps
    ) -> GenericRecordFormViewModel {
        GenericRecordFormViewModel(
            person: person,
            recordType: recordType,
            existingRecord: existingRecord,
            medicalRecordRepository: deps.repo,
            recordContentService: deps.content,
            primaryKeyProvider: deps.keyProvider,
            fmkService: deps.fmk,
            providerRepository: deps.providers,
            autocompleteService: deps.autocomplete
        )
    }
}
