import CryptoKit
import Foundation
import Testing
@testable import FamilyMedicalApp

@MainActor
struct GenericRecordFormViewModelSaveTests {
    // MARK: - Test Helpers

    func makeTestPerson() throws -> Person {
        try PersonTestHelper.makeTestPerson()
    }

    // MARK: - Save: Validation

    @Test
    func save_failsValidationWhenRequiredFieldMissing() async throws {
        let person = try makeTestPerson()
        let deps = FormViewModelDeps(personId: person.id)
        let vm = FormTestSupport.makeViewModel(person: person, recordType: .immunization, deps: deps)

        let ok = await vm.save()

        #expect(ok == false)
        #expect(vm.validationErrors["vaccineCode"] == "Required")
        #expect(vm.validationErrors["occurrenceDate"] == "Required")
        #expect(deps.repo.saveCallCount == 0)
    }

    @Test
    func save_failsValidationWhenRequiredTextFieldIsEmptyString() async throws {
        let person = try makeTestPerson()
        let deps = FormViewModelDeps(personId: person.id)
        let vm = FormTestSupport.makeViewModel(person: person, recordType: .immunization, deps: deps)
        vm.setValue("", for: "vaccineCode")
        vm.setValue(Date(), for: "occurrenceDate")

        let ok = await vm.save()

        #expect(ok == false)
        #expect(vm.validationErrors["vaccineCode"] == "Required")
    }

    @Test
    func save_passesValidationWhenAllRequiredFieldsPresent() async throws {
        let person = try makeTestPerson()
        let deps = FormViewModelDeps(personId: person.id)
        let vm = FormTestSupport.makeViewModel(person: person, recordType: .immunization, deps: deps)
        vm.setValue("Pfizer", for: "vaccineCode")
        vm.setValue(Date(), for: "occurrenceDate")

        let ok = await vm.save()

        #expect(ok == true)
        #expect(vm.validationErrors.isEmpty)
    }

    // MARK: - Save: Create Mode

    @Test
    func save_createMode_persistsEncryptedRecordToRepository() async throws {
        let person = try makeTestPerson()
        let deps = FormViewModelDeps(personId: person.id)
        let vm = FormTestSupport.makeViewModel(person: person, recordType: .immunization, deps: deps)
        vm.setValue("Moderna", for: "vaccineCode")
        vm.setValue(Date(timeIntervalSinceReferenceDate: 650_000_000), for: "occurrenceDate")

        let ok = await vm.save()

        #expect(ok == true)
        #expect(deps.repo.saveCallCount == 1)
        #expect(deps.content.encryptCallCount == 1)
        let saved = deps.repo.getAllRecords().first
        #expect(saved != nil)
        #expect(saved?.personId == person.id)
        #expect(saved?.version == 1)
        #expect(saved?.previousVersionId == nil)
    }

    @Test
    func save_createMode_envelopeCanBeDecodedBackToTypedStruct() async throws {
        let person = try makeTestPerson()
        let deps = FormViewModelDeps(personId: person.id)
        let vm = FormTestSupport.makeViewModel(person: person, recordType: .immunization, deps: deps)
        let date = Date(timeIntervalSinceReferenceDate: 720_000_000)
        vm.setValue("Pfizer-BioNTech COVID-19", for: "vaccineCode")
        vm.setValue(date, for: "occurrenceDate")
        vm.setValue("EL9262", for: "lotNumber")
        vm.setValue(2, for: "doseNumber")
        vm.setValue("Left arm injection", for: "notes")

        _ = await vm.save()

        let saved = try #require(deps.repo.getAllRecords().first)
        let envelope = try deps.content.decrypt(saved.encryptedContent, using: deps.fmkKey)
        #expect(envelope.recordType == .immunization)
        let decoded = try envelope.decode(ImmunizationRecord.self)
        #expect(decoded.vaccineCode == "Pfizer-BioNTech COVID-19")
        #expect(decoded.lotNumber == "EL9262")
        #expect(decoded.doseNumber == 2)
        #expect(decoded.notes == "Left arm injection")
        #expect(abs(decoded.occurrenceDate.timeIntervalSince(date)) < 0.001)
    }

    @Test
    func save_createMode_optionalEmptyStringsOmittedFromStoredRecord() async throws {
        let person = try makeTestPerson()
        let deps = FormViewModelDeps(personId: person.id)
        let vm = FormTestSupport.makeViewModel(person: person, recordType: .immunization, deps: deps)
        vm.setValue("Moderna", for: "vaccineCode")
        vm.setValue(Date(), for: "occurrenceDate")
        vm.setValue("", for: "lotNumber")

        _ = await vm.save()

        let saved = try #require(deps.repo.getAllRecords().first)
        let envelope = try deps.content.decrypt(saved.encryptedContent, using: deps.fmkKey)
        let decoded = try envelope.decode(ImmunizationRecord.self)
        #expect(decoded.lotNumber == nil)
    }

    @Test
    func save_createMode_storesProviderIdAsUUID() async throws {
        let person = try makeTestPerson()
        let deps = FormViewModelDeps(personId: person.id)
        let providerId = UUID()
        let vm = FormTestSupport.makeViewModel(person: person, recordType: .immunization, deps: deps)
        vm.setValue("Moderna", for: "vaccineCode")
        vm.setValue(Date(), for: "occurrenceDate")
        vm.setValue(providerId, for: "providerId")

        _ = await vm.save()

        let saved = try #require(deps.repo.getAllRecords().first)
        let envelope = try deps.content.decrypt(saved.encryptedContent, using: deps.fmkKey)
        let decoded = try envelope.decode(ImmunizationRecord.self)
        #expect(decoded.providerId == providerId)
    }

    @Test
    func save_createMode_splitsTagsFromCommaSeparatedString() async throws {
        let person = try makeTestPerson()
        let deps = FormViewModelDeps(personId: person.id)
        let vm = FormTestSupport.makeViewModel(person: person, recordType: .immunization, deps: deps)
        vm.setValue("Moderna", for: "vaccineCode")
        vm.setValue(Date(), for: "occurrenceDate")
        vm.setValue("travel, booster, covid", for: "tags")

        _ = await vm.save()

        let saved = try #require(deps.repo.getAllRecords().first)
        let envelope = try deps.content.decrypt(saved.encryptedContent, using: deps.fmkKey)
        let decoded = try envelope.decode(ImmunizationRecord.self)
        #expect(decoded.tags == ["travel", "booster", "covid"])
    }

    @Test
    func save_createMode_forConditionWithPickerFields() async throws {
        let person = try makeTestPerson()
        let deps = FormViewModelDeps(personId: person.id)
        let vm = FormTestSupport.makeViewModel(person: person, recordType: .condition, deps: deps)
        vm.setValue("Asthma", for: "conditionName")
        vm.setValue("Moderate", for: "severity")
        vm.setValue("Active", for: "status")

        let ok = await vm.save()

        #expect(ok == true)
        let saved = try #require(deps.repo.getAllRecords().first)
        let envelope = try deps.content.decrypt(saved.encryptedContent, using: deps.fmkKey)
        let decoded = try envelope.decode(ConditionRecord.self)
        #expect(decoded.conditionName == "Asthma")
        #expect(decoded.severity == "Moderate")
        #expect(decoded.status == "Active")
    }

    @Test
    func save_createMode_forObservationWithComponents() async throws {
        let person = try makeTestPerson()
        let deps = FormViewModelDeps(personId: person.id)
        let vm = FormTestSupport.makeViewModel(person: person, recordType: .observation, deps: deps)
        vm.setValue("Blood Pressure", for: "observationType")
        vm.setValue(Date(), for: "effectiveDate")
        vm.setValue(
            [
                ObservationComponent(name: "Systolic", value: 120, unit: "mmHg"),
                ObservationComponent(name: "Diastolic", value: 80, unit: "mmHg")
            ],
            for: "components"
        )

        let ok = await vm.save()

        #expect(ok == true)
        let saved = try #require(deps.repo.getAllRecords().first)
        let envelope = try deps.content.decrypt(saved.encryptedContent, using: deps.fmkKey)
        let decoded = try envelope.decode(ObservationRecord.self)
        #expect(decoded.components.count == 2)
        #expect(decoded.components[0].name == "Systolic")
        #expect(decoded.components[0].value == 120)
        #expect(decoded.components[1].name == "Diastolic")
    }

    // MARK: - Save: Edit Mode

    @Test
    func save_editMode_preservesCreatedAtAndIncrementsVersion() async throws {
        let person = try makeTestPerson()
        let deps = FormViewModelDeps(personId: person.id)
        let created = Date(timeIntervalSinceReferenceDate: 500_000_000)
        let originalContent = ImmunizationRecord(vaccineCode: "Moderna", occurrenceDate: created)
        let envelope = try RecordContentEnvelope(originalContent)
        let originalRecord = MedicalRecord(
            personId: person.id,
            encryptedContent: Data(),
            createdAt: created,
            updatedAt: created,
            version: 3
        )
        let decrypted = DecryptedRecord(record: originalRecord, envelope: envelope)

        let vm = FormTestSupport.makeViewModel(
            person: person, recordType: .immunization, existingRecord: decrypted, deps: deps
        )
        vm.setValue("Pfizer", for: "vaccineCode")

        let ok = await vm.save()

        #expect(ok == true)
        let saved = try #require(deps.repo.getAllRecords().first)
        #expect(saved.id == originalRecord.id)
        #expect(saved.createdAt == created)
        #expect(saved.version == 4)
        #expect(saved.previousVersionId == nil)
    }

    @Test
    func save_editMode_doesNotSetPreviousVersionIdToSelf() async throws {
        // Regression guard: previousVersionId must not point at the record's own id.
        // The repository upserts by id (in-place update), so a self-referential
        // previousVersionId is bogus data for a history traversal that doesn't exist.
        let person = try makeTestPerson()
        let deps = FormViewModelDeps(personId: person.id)
        let originalContent = ImmunizationRecord(vaccineCode: "X", occurrenceDate: Date())
        let envelope = try RecordContentEnvelope(originalContent)
        let originalRecord = MedicalRecord(
            personId: person.id,
            encryptedContent: Data()
        )
        let decrypted = DecryptedRecord(record: originalRecord, envelope: envelope)
        let vm = FormTestSupport.makeViewModel(
            person: person, recordType: .immunization, existingRecord: decrypted, deps: deps
        )
        vm.setValue("Y", for: "vaccineCode")

        _ = await vm.save()

        let saved = try #require(deps.repo.getAllRecords().first)
        #expect(saved.id == originalRecord.id)
        #expect(saved.previousVersionId != saved.id) // not self-referential
        #expect(saved.previousVersionId == nil) // nil is the chosen representation
    }

    @Test
    func save_editMode_preservesUnknownFieldsFromOriginalRecord() async throws {
        let person = try makeTestPerson()
        let deps = FormViewModelDeps(personId: person.id)
        let jsonWithUnknown = """
        {"vaccineCode":"Pfizer","occurrenceDate":700000000,"tags":[],"futureField":"preserved"}
        """
        let envelope = RecordContentEnvelope(
            recordType: .immunization, schemaVersion: 1, content: Data(jsonWithUnknown.utf8)
        )
        let originalRecord = MedicalRecord(personId: person.id, encryptedContent: Data())
        let decrypted = DecryptedRecord(record: originalRecord, envelope: envelope)

        let vm = FormTestSupport.makeViewModel(
            person: person, recordType: .immunization, existingRecord: decrypted, deps: deps
        )
        vm.setValue("Moderna", for: "vaccineCode")

        _ = await vm.save()

        let saved = try #require(deps.repo.getAllRecords().first)
        let savedEnvelope = try deps.content.decrypt(saved.encryptedContent, using: deps.fmkKey)
        guard let json = try JSONSerialization.jsonObject(with: savedEnvelope.content) as? [String: Any] else {
            Issue.record("Expected JSON object")
            return
        }
        #expect(json["futureField"] as? String == "preserved")
        #expect(json["vaccineCode"] as? String == "Moderna")
    }

    // MARK: - Save: Error Handling

    @Test
    func save_returnsFalseAndSetsErrorMessageWhenRepositoryFails() async throws {
        let person = try makeTestPerson()
        let deps = FormViewModelDeps(personId: person.id)
        deps.repo.shouldFailSave = true
        let vm = FormTestSupport.makeViewModel(person: person, recordType: .immunization, deps: deps)
        vm.setValue("Pfizer", for: "vaccineCode")
        vm.setValue(Date(), for: "occurrenceDate")

        let ok = await vm.save()

        #expect(ok == false)
        #expect(vm.errorMessage != nil)
    }

    @Test
    func save_returnsFalseWhenPrimaryKeyUnavailable() async throws {
        let person = try makeTestPerson()
        let deps = FormViewModelDeps(personId: person.id)
        deps.keyProvider.shouldFail = true
        let vm = FormTestSupport.makeViewModel(person: person, recordType: .immunization, deps: deps)
        vm.setValue("Pfizer", for: "vaccineCode")
        vm.setValue(Date(), for: "occurrenceDate")

        let ok = await vm.save()

        #expect(ok == false)
        #expect(vm.errorMessage != nil)
        #expect(deps.repo.saveCallCount == 0)
    }

    @Test
    func save_refusesEditWhenEnvelopeSchemaVersionIsNewerThanKnown() async throws {
        let person = try makeTestPerson()
        let deps = FormViewModelDeps(personId: person.id)
        // Envelope saved by a future app version (schemaVersion 99).
        let futureJSON = """
        {"vaccineCode":"Pfizer","occurrenceDate":0,"tags":[]}
        """
        let envelope = RecordContentEnvelope(
            recordType: .immunization,
            schemaVersion: 99,
            content: Data(futureJSON.utf8)
        )
        let decrypted = DecryptedRecord(
            record: MedicalRecord(personId: person.id, encryptedContent: Data()),
            envelope: envelope
        )
        let vm = FormTestSupport.makeViewModel(
            person: person, recordType: .immunization, existingRecord: decrypted, deps: deps
        )
        vm.setValue("Moderna", for: "vaccineCode")

        let ok = await vm.save()

        #expect(ok == false)
        #expect(vm.errorMessage != nil)
        #expect(deps.repo.saveCallCount == 0)
    }

    @Test
    func save_isSavingFlagResetAfterCompletion() async throws {
        let person = try makeTestPerson()
        let deps = FormViewModelDeps(personId: person.id)
        let vm = FormTestSupport.makeViewModel(person: person, recordType: .immunization, deps: deps)
        vm.setValue("Pfizer", for: "vaccineCode")
        vm.setValue(Date(), for: "occurrenceDate")

        _ = await vm.save()

        #expect(vm.isSaving == false)
    }
}
