import CryptoKit
import Foundation
import Testing
@testable import FamilyMedicalApp

@MainActor
struct MedicalRecordDetailViewModelTests {
    // MARK: - Helpers

    func makeTestPerson() throws -> Person {
        try PersonTestHelper.makeTestPerson()
    }

    func makeDecryptedRecord(_ content: some MedicalRecordContent, personId: UUID) throws -> DecryptedRecord {
        let envelope = try RecordContentEnvelope(content)
        let record = MedicalRecord(personId: personId, encryptedContent: Data())
        return DecryptedRecord(record: record, envelope: envelope)
    }

    struct Deps {
        let providers = MockProviderRepository()
        let keyProvider = MockPrimaryKeyProvider()
        let fmk = MockFamilyMemberKeyService()

        init(personId: UUID) {
            keyProvider.primaryKey = SymmetricKey(size: .bits256)
            fmk.setFMK(SymmetricKey(size: .bits256), for: personId.uuidString)
        }
    }

    private func makeViewModel(
        person: Person,
        decryptedRecord: DecryptedRecord,
        deps: Deps
    ) -> MedicalRecordDetailViewModel {
        MedicalRecordDetailViewModel(
            person: person,
            decryptedRecord: decryptedRecord,
            providerRepository: deps.providers,
            primaryKeyProvider: deps.keyProvider,
            fmkService: deps.fmk
        )
    }

    // MARK: - Initialization & Decoding

    @Test
    func init_decodesKnownFieldsFromEnvelope() throws {
        let person = try makeTestPerson()
        let deps = Deps(personId: person.id)
        let content = ImmunizationRecord(
            vaccineCode: "Pfizer",
            occurrenceDate: Date(timeIntervalSinceReferenceDate: 700_000_000),
            lotNumber: "ABC123",
            doseNumber: 2
        )
        let decrypted = try makeDecryptedRecord(content, personId: person.id)

        let vm = makeViewModel(person: person, decryptedRecord: decrypted, deps: deps)

        #expect(vm.knownFieldValues["vaccineCode"] as? String == "Pfizer")
        #expect(vm.knownFieldValues["lotNumber"] as? String == "ABC123")
        #expect(vm.knownFieldValues["doseNumber"] as? Int == 2)
        // occurrenceDate should be denormalized to Date
        #expect(vm.knownFieldValues["occurrenceDate"] is Date)
    }

    @Test
    func init_separatesUnknownForwardCompatFields() throws {
        let person = try makeTestPerson()
        let deps = Deps(personId: person.id)
        // Envelope with an unknown field that won't match any metadata keyPath.
        let json = """
        {"vaccineCode":"X","occurrenceDate":0,"tags":[],"mysteryField":"hello"}
        """
        let envelope = RecordContentEnvelope(
            recordType: .immunization,
            schemaVersion: 1,
            content: Data(json.utf8)
        )
        let decrypted = DecryptedRecord(
            record: MedicalRecord(personId: person.id, encryptedContent: Data()),
            envelope: envelope
        )

        let vm = makeViewModel(person: person, decryptedRecord: decrypted, deps: deps)

        #expect(vm.knownFieldValues["vaccineCode"] as? String == "X")
        #expect(vm.unknownFields["mysteryField"] as? String == "hello")
        #expect(vm.knownFieldValues["mysteryField"] == nil)
    }

    @Test
    func init_exposesRecordTypeFromEnvelope() throws {
        let person = try makeTestPerson()
        let deps = Deps(personId: person.id)
        let content = ConditionRecord(conditionName: "Asthma")
        let decrypted = try makeDecryptedRecord(content, personId: person.id)

        let vm = makeViewModel(person: person, decryptedRecord: decrypted, deps: deps)

        #expect(vm.recordType == .condition)
    }

    @Test
    func init_orderedFieldMetadataIsSortedByDisplayOrder() throws {
        let person = try makeTestPerson()
        let deps = Deps(personId: person.id)
        let content = ImmunizationRecord(vaccineCode: "X", occurrenceDate: Date())
        let decrypted = try makeDecryptedRecord(content, personId: person.id)

        let vm = makeViewModel(person: person, decryptedRecord: decrypted, deps: deps)

        let orders = vm.orderedFieldMetadata.map(\.displayOrder)
        #expect(orders == orders.sorted())
    }

    // MARK: - Provider Resolution

    @Test
    func loadProviderDisplayIfNeeded_resolvesProviderString() async throws {
        let person = try makeTestPerson()
        let deps = Deps(personId: person.id)
        let provider = Provider(name: "Dr. Strange", organization: "Sanctum")
        deps.providers.addProvider(provider, personId: person.id)
        let content = ImmunizationRecord(
            vaccineCode: "Pfizer",
            occurrenceDate: Date(),
            providerId: provider.id
        )
        let decrypted = try makeDecryptedRecord(content, personId: person.id)
        let vm = makeViewModel(person: person, decryptedRecord: decrypted, deps: deps)

        await vm.loadProviderDisplayIfNeeded()

        #expect(vm.providerDisplayString == provider.displayString)
    }

    @Test
    func loadProviderDisplayIfNeeded_noOpWhenProviderIdAbsent() async throws {
        let person = try makeTestPerson()
        let deps = Deps(personId: person.id)
        let content = ImmunizationRecord(vaccineCode: "Pfizer", occurrenceDate: Date())
        let decrypted = try makeDecryptedRecord(content, personId: person.id)
        let vm = makeViewModel(person: person, decryptedRecord: decrypted, deps: deps)

        await vm.loadProviderDisplayIfNeeded()

        #expect(vm.providerDisplayString == nil)
        #expect(deps.providers.fetchCallCount == 0)
    }

    @Test
    func loadProviderDisplayIfNeeded_leavesNilOnProviderFetchFailure() async throws {
        let person = try makeTestPerson()
        let deps = Deps(personId: person.id)
        deps.providers.shouldFailFetch = true
        let content = ImmunizationRecord(
            vaccineCode: "Pfizer",
            occurrenceDate: Date(),
            providerId: UUID()
        )
        let decrypted = try makeDecryptedRecord(content, personId: person.id)
        let vm = makeViewModel(person: person, decryptedRecord: decrypted, deps: deps)

        await vm.loadProviderDisplayIfNeeded()

        #expect(vm.providerDisplayString == nil)
    }

    // MARK: - Refresh

    @Test
    func refresh_rebuildsFieldValuesFromNewRecord() throws {
        let person = try makeTestPerson()
        let deps = Deps(personId: person.id)
        let original = ImmunizationRecord(vaccineCode: "OldName", occurrenceDate: Date())
        let decrypted = try makeDecryptedRecord(original, personId: person.id)
        let vm = makeViewModel(person: person, decryptedRecord: decrypted, deps: deps)
        #expect(vm.knownFieldValues["vaccineCode"] as? String == "OldName")

        let updated = ImmunizationRecord(vaccineCode: "NewName", occurrenceDate: Date())
        let newDecrypted = try makeDecryptedRecord(updated, personId: person.id)
        vm.refresh(with: newDecrypted)

        #expect(vm.knownFieldValues["vaccineCode"] as? String == "NewName")
    }
}
