import CryptoKit
import Foundation
import Testing
@testable import FamilyMedicalApp

@MainActor
struct GenericRecordFormViewModelExtraTests {
    // MARK: - Test Helpers

    func makeTestPerson() throws -> Person {
        try PersonTestHelper.makeTestPerson()
    }

    fileprivate struct Deps {
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

    private func makeViewModel(
        person: Person,
        recordType: RecordType,
        existingRecord: DecryptedRecord? = nil,
        deps: Deps
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

    // MARK: - UUID accessor

    @Test
    func uuidValue_returnsNilWhenUnset() throws {
        let person = try makeTestPerson()
        let deps = Deps(personId: person.id)
        let vm = makeViewModel(person: person, recordType: .immunization, deps: deps)

        #expect(vm.uuidValue(for: "providerId") == nil)
    }

    @Test
    func uuidValue_returnsStoredUUID() throws {
        let person = try makeTestPerson()
        let deps = Deps(personId: person.id)
        let vm = makeViewModel(person: person, recordType: .immunization, deps: deps)
        let uuid = UUID()

        vm.setValue(uuid, for: "providerId")

        #expect(vm.uuidValue(for: "providerId") == uuid)
    }

    // MARK: - Components accessor

    @Test
    func componentsValue_returnsEmptyWhenUnset() throws {
        let person = try makeTestPerson()
        let deps = Deps(personId: person.id)
        let vm = makeViewModel(person: person, recordType: .observation, deps: deps)

        #expect(vm.componentsValue(for: "components").isEmpty)
    }

    @Test
    func componentsValue_returnsStoredComponents() throws {
        let person = try makeTestPerson()
        let deps = Deps(personId: person.id)
        let vm = makeViewModel(person: person, recordType: .observation, deps: deps)
        let components = [
            ObservationComponent(name: "Systolic", value: 120, unit: "mmHg"),
            ObservationComponent(name: "Diastolic", value: 80, unit: "mmHg")
        ]

        vm.setValue(components, for: "components")

        let returned = vm.componentsValue(for: "components")
        #expect(returned.count == 2)
        #expect(returned[0].name == "Systolic")
        #expect(returned[1].name == "Diastolic")
    }

    // MARK: - Simple typed accessors

    @Test
    func stringValue_returnsStoredString() throws {
        let person = try makeTestPerson()
        let deps = Deps(personId: person.id)
        let vm = makeViewModel(person: person, recordType: .immunization, deps: deps)

        vm.setValue("Pfizer", for: "vaccineCode")

        #expect(vm.stringValue(for: "vaccineCode") == "Pfizer")
    }

    @Test
    func dateValue_returnsStoredDate() throws {
        let person = try makeTestPerson()
        let deps = Deps(personId: person.id)
        let vm = makeViewModel(person: person, recordType: .immunization, deps: deps)
        let date = Date(timeIntervalSinceReferenceDate: 420_000_000)
        let fallback = Date(timeIntervalSinceReferenceDate: 0)

        vm.setValue(date, for: "occurrenceDate")

        #expect(vm.dateValue(for: "occurrenceDate", default: fallback) == date)
    }

    @Test
    func intValue_returnsStoredInt() throws {
        let person = try makeTestPerson()
        let deps = Deps(personId: person.id)
        let vm = makeViewModel(person: person, recordType: .immunization, deps: deps)

        vm.setValue(3, for: "doseNumber")

        #expect(vm.intValue(for: "doseNumber") == 3)
    }

    // MARK: - Display names

    @Test
    func displayNameForObservation_returnsObservation() throws {
        let person = try makeTestPerson()
        let deps = Deps(personId: person.id)
        let vm = makeViewModel(person: person, recordType: .observation, deps: deps)

        #expect(vm.displayName == "Observation")
    }

    @Test
    func displayNameForDocumentReference_returnsDocument() throws {
        let person = try makeTestPerson()
        let deps = Deps(personId: person.id)
        let vm = makeViewModel(person: person, recordType: .documentReference, deps: deps)

        #expect(vm.displayName == "Document")
    }

    // MARK: - Save: MedicationStatement create mode

    @Test
    func save_createMode_forMedicationStatement() async throws {
        let person = try makeTestPerson()
        let deps = Deps(personId: person.id)
        let vm = makeViewModel(person: person, recordType: .medicationStatement, deps: deps)
        vm.setValue("Ibuprofen", for: "medicationName")

        let ok = await vm.save()

        #expect(ok == true)
        #expect(deps.repo.saveCallCount == 1)
        let saved = try #require(deps.repo.getAllRecords().first)
        let envelope = try deps.content.decrypt(saved.encryptedContent, using: deps.fmkKey)
        #expect(envelope.recordType == .medicationStatement)
        let decoded = try envelope.decode(MedicationStatementRecord.self)
        #expect(decoded.medicationName == "Ibuprofen")
    }

    // MARK: - Metadata cannot be overridden via fieldValues

    @Test
    func save_createMode_preservesMetadataInsteadOfUserEditsWhenConflict() async throws {
        let person = try makeTestPerson()
        let deps = Deps(personId: person.id)
        let vm = makeViewModel(person: person, recordType: .immunization, deps: deps)
        // User supplies valid required fields
        vm.setValue("Moderna", for: "vaccineCode")
        vm.setValue(Date(), for: "occurrenceDate")
        // Attempt to inject envelope-level fields via fieldValues (should be ignored because
        // there's no FieldMetadata entry matching these keyPaths).
        vm.setValue("clinicalNote", for: "recordType")
        vm.setValue(99, for: "schemaVersion")

        let ok = await vm.save()

        #expect(ok == true)
        let saved = try #require(deps.repo.getAllRecords().first)
        let envelope = try deps.content.decrypt(saved.encryptedContent, using: deps.fmkKey)
        // Envelope remains keyed to the real record type + current schema version.
        #expect(envelope.recordType == .immunization)
        #expect(envelope.schemaVersion == ImmunizationRecord.schemaVersion)
    }
}
