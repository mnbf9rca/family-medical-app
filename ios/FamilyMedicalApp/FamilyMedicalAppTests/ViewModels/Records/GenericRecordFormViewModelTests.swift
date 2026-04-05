import CryptoKit
import Foundation
import Testing
@testable import FamilyMedicalApp

@MainActor
struct GenericRecordFormViewModelTests {
    // MARK: - Test Helpers

    func makeTestPerson() throws -> Person {
        try PersonTestHelper.makeTestPerson()
    }

    private func makeDecryptedRecord(
        _ content: some MedicalRecordContent,
        personId: UUID
    ) throws -> DecryptedRecord {
        let envelope = try RecordContentEnvelope(content)
        let record = MedicalRecord(personId: personId, encryptedContent: Data())
        return DecryptedRecord(record: record, envelope: envelope)
    }

    // MARK: - Initialization: Create Mode

    @Test
    func initCreateMode_startsWithEmptyFieldValues() throws {
        let person = try makeTestPerson()
        let deps = FormViewModelDeps(personId: person.id)

        let vm = FormTestSupport.makeViewModel(person: person, recordType: .immunization, deps: deps)

        #expect(vm.fieldValues.isEmpty)
        #expect(vm.isEditing == false)
        #expect(vm.errorMessage == nil)
        #expect(vm.validationErrors.isEmpty)
        #expect(vm.forwardCompatibilityWarning == nil)
    }

    @Test
    func initCreateMode_fieldMetadataMatchesRecordType() throws {
        let person = try makeTestPerson()
        let deps = FormViewModelDeps(personId: person.id)

        let vm = FormTestSupport.makeViewModel(person: person, recordType: .immunization, deps: deps)

        let keyPaths = vm.fieldMetadata.map(\.keyPath)
        #expect(keyPaths.contains("vaccineCode"))
        #expect(keyPaths.contains("occurrenceDate"))
        #expect(keyPaths.contains("notes"))
        #expect(keyPaths.contains("tags"))
    }

    @Test
    func initCreateMode_fieldMetadataIsSortedByDisplayOrder() throws {
        let person = try makeTestPerson()
        let deps = FormViewModelDeps(personId: person.id)

        let vm = FormTestSupport.makeViewModel(person: person, recordType: .immunization, deps: deps)

        let orders = vm.fieldMetadata.map(\.displayOrder)
        #expect(orders == orders.sorted())
    }

    @Test
    func initCreateMode_displayNameComesFromRecordType() throws {
        let person = try makeTestPerson()
        let deps = FormViewModelDeps(personId: person.id)

        let vm = FormTestSupport.makeViewModel(person: person, recordType: .allergyIntolerance, deps: deps)

        #expect(vm.displayName == "Allergy")
    }

    // MARK: - Initialization: Edit Mode

    @Test
    func initEditMode_hydratesKnownFieldsFromExistingRecord() throws {
        let person = try makeTestPerson()
        let deps = FormViewModelDeps(personId: person.id)
        let occurrence = Date(timeIntervalSinceReferenceDate: 700_000_000)
        let original = ImmunizationRecord(
            vaccineCode: "Pfizer-BioNTech COVID-19",
            occurrenceDate: occurrence,
            lotNumber: "EL9262",
            doseNumber: 2,
            notes: "Left arm"
        )
        let decrypted = try makeDecryptedRecord(original, personId: person.id)

        let vm = FormTestSupport.makeViewModel(
            person: person, recordType: .immunization, existingRecord: decrypted, deps: deps
        )

        #expect(vm.isEditing == true)
        #expect(vm.stringValue(for: "vaccineCode") == "Pfizer-BioNTech COVID-19")
        #expect(vm.stringValue(for: "lotNumber") == "EL9262")
        #expect(vm.intValue(for: "doseNumber") == 2)
        #expect(vm.stringValue(for: "notes") == "Left arm")
        let loadedDate = vm.dateValue(for: "occurrenceDate", default: Date())
        #expect(abs(loadedDate.timeIntervalSince(occurrence)) < 0.001)
    }

    @Test
    func initEditMode_forwardCompatWarningSetWhenSchemaVersionIsNewer() throws {
        let person = try makeTestPerson()
        let deps = FormViewModelDeps(personId: person.id)
        let future = RecordContentEnvelope(
            recordType: .immunization,
            schemaVersion: 99,
            content: Data("{\"vaccineCode\":\"X\",\"occurrenceDate\":0,\"tags\":[]}".utf8)
        )
        let decrypted = DecryptedRecord(
            record: MedicalRecord(personId: person.id, encryptedContent: Data()),
            envelope: future
        )

        let vm = FormTestSupport.makeViewModel(
            person: person, recordType: .immunization, existingRecord: decrypted, deps: deps
        )

        #expect(vm.forwardCompatibilityWarning != nil)
    }

    @Test
    func initEditMode_noForwardCompatWarningWhenSchemaVersionMatches() throws {
        let person = try makeTestPerson()
        let deps = FormViewModelDeps(personId: person.id)
        let original = ImmunizationRecord(vaccineCode: "X", occurrenceDate: Date())
        let decrypted = try makeDecryptedRecord(original, personId: person.id)

        let vm = FormTestSupport.makeViewModel(
            person: person, recordType: .immunization, existingRecord: decrypted, deps: deps
        )

        #expect(vm.forwardCompatibilityWarning == nil)
    }

    // MARK: - Field Value Access

    @Test
    func setValue_storesValueInFieldValues() throws {
        let person = try makeTestPerson()
        let deps = FormViewModelDeps(personId: person.id)
        let vm = FormTestSupport.makeViewModel(person: person, recordType: .immunization, deps: deps)

        vm.setValue("Tylenol", for: "vaccineCode")

        #expect(vm.stringValue(for: "vaccineCode") == "Tylenol")
        #expect(vm.value(for: "vaccineCode") as? String == "Tylenol")
    }

    @Test
    func setValue_nilRemovesStoredValue() throws {
        let person = try makeTestPerson()
        let deps = FormViewModelDeps(personId: person.id)
        let vm = FormTestSupport.makeViewModel(person: person, recordType: .immunization, deps: deps)
        vm.setValue("Tylenol", for: "vaccineCode")

        vm.setValue(nil, for: "vaccineCode")

        #expect(vm.value(for: "vaccineCode") == nil)
        #expect(vm.stringValue(for: "vaccineCode").isEmpty)
    }

    @Test
    func setValue_clearsValidationErrorForThatKeyPath() throws {
        let person = try makeTestPerson()
        let deps = FormViewModelDeps(personId: person.id)
        let vm = FormTestSupport.makeViewModel(person: person, recordType: .immunization, deps: deps)
        vm.validationErrors["vaccineCode"] = "Required"

        vm.setValue("Moderna", for: "vaccineCode")

        #expect(vm.validationErrors["vaccineCode"] == nil)
    }

    @Test
    func stringValue_returnsEmptyStringWhenUnset() throws {
        let person = try makeTestPerson()
        let deps = FormViewModelDeps(personId: person.id)
        let vm = FormTestSupport.makeViewModel(person: person, recordType: .immunization, deps: deps)

        #expect(vm.stringValue(for: "notes").isEmpty)
    }

    @Test
    func dateValue_returnsDefaultWhenUnset() throws {
        let person = try makeTestPerson()
        let deps = FormViewModelDeps(personId: person.id)
        let vm = FormTestSupport.makeViewModel(person: person, recordType: .immunization, deps: deps)
        let fallback = Date(timeIntervalSinceReferenceDate: 12_345)

        #expect(vm.dateValue(for: "occurrenceDate", default: fallback) == fallback)
    }

    @Test
    func intValue_returnsNilWhenUnset() throws {
        let person = try makeTestPerson()
        let deps = FormViewModelDeps(personId: person.id)
        let vm = FormTestSupport.makeViewModel(person: person, recordType: .immunization, deps: deps)

        #expect(vm.intValue(for: "doseNumber") == nil)
    }

    // MARK: - Providers

    @Test
    func loadProviders_populatesProvidersArray() async throws {
        let person = try makeTestPerson()
        let deps = FormViewModelDeps(personId: person.id)
        let provider = Provider(name: "Dr. Smith", organization: "Mercy")
        deps.providers.addProvider(provider, personId: person.id)
        let vm = FormTestSupport.makeViewModel(person: person, recordType: .immunization, deps: deps)

        await vm.loadProviders()

        #expect(vm.providers.count == 1)
        #expect(vm.providers.first?.name == "Dr. Smith")
    }

    @Test
    func loadProviders_setsEmptyArrayOnError() async throws {
        let person = try makeTestPerson()
        let deps = FormViewModelDeps(personId: person.id)
        deps.providers.shouldFailFetchAll = true
        let vm = FormTestSupport.makeViewModel(person: person, recordType: .immunization, deps: deps)
        vm.providers = [Provider(name: "Bogus", organization: nil)]

        await vm.loadProviders()

        #expect(vm.providers.isEmpty)
    }
}
