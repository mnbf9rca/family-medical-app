import Foundation
import Testing
@testable import FamilyMedicalApp

@Suite("RecordContentEnvelope decoded field values")
struct RecordContentEnvelopeDecodingTests {
    // MARK: - contentAsJSONDict

    @Test
    func contentAsJSONDict_parsesEnvelopeJSON() throws {
        let content = ImmunizationRecord(vaccineCode: "Moderna", occurrenceDate: Date())
        let envelope = try RecordContentEnvelope(content)

        let dict = try envelope.contentAsJSONDict()

        #expect(dict["vaccineCode"] as? String == "Moderna")
        #expect(dict["occurrenceDate"] is Double)
    }

    @Test
    func contentAsJSONDict_throwsForNonObjectJSON() throws {
        let envelope = RecordContentEnvelope(
            recordType: .immunization,
            schemaVersion: 1,
            content: Data("[1, 2, 3]".utf8)
        )

        #expect(throws: DecodingError.self) {
            _ = try envelope.contentAsJSONDict()
        }
    }

    // MARK: - decodedFieldValues

    @Test
    func decodedFieldValues_knownAndUnknownKeysNeverCollide() throws {
        // Invariant: a key lives in exactly one of known/unknown. This guards against a
        // future refactor that renames a keyPath while keeping the old name as unknown and
        // accidentally produces a dict where a key appears twice.
        let content = ImmunizationRecord(
            vaccineCode: "X",
            occurrenceDate: Date(),
            lotNumber: "L",
            providerId: UUID()
        )
        let envelope = try RecordContentEnvelope(content)

        let decoded = try envelope.decodedFieldValues()

        let knownKeys = Set(decoded.known.keys)
        let unknownKeys = Set(decoded.unknown.keys)
        #expect(knownKeys.isDisjoint(with: unknownKeys))
    }

    @Test
    func decodedFieldValues_partitionsKnownAndUnknownFields() throws {
        let json = """
        {"vaccineCode":"A","occurrenceDate":700000000,"tags":[],"extraField":"future"}
        """
        let envelope = RecordContentEnvelope(
            recordType: .immunization,
            schemaVersion: 1,
            content: Data(json.utf8)
        )

        let decoded = try envelope.decodedFieldValues()

        #expect(decoded.known["vaccineCode"] as? String == "A")
        #expect(decoded.known["extraField"] == nil)
        #expect(decoded.unknown["extraField"] as? String == "future")
    }

    @Test
    func decodedFieldValues_denormalizesDateFieldsToDate() throws {
        let content = ImmunizationRecord(
            vaccineCode: "A",
            occurrenceDate: Date(timeIntervalSinceReferenceDate: 500_000_000)
        )
        let envelope = try RecordContentEnvelope(content)

        let decoded = try envelope.decodedFieldValues()

        let date = decoded.known["occurrenceDate"] as? Date
        #expect(date != nil)
        if let date {
            #expect(abs(date.timeIntervalSinceReferenceDate - 500_000_000) < 0.001)
        }
    }

    @Test
    func decodedFieldValues_denormalizesProviderIdToUUID() throws {
        let providerId = UUID()
        let content = ImmunizationRecord(
            vaccineCode: "A",
            occurrenceDate: Date(),
            providerId: providerId
        )
        let envelope = try RecordContentEnvelope(content)

        let decoded = try envelope.decodedFieldValues()

        #expect(decoded.known["providerId"] as? UUID == providerId)
    }

    @Test
    func decodedFieldValues_denormalizesComponentsArray() throws {
        let components = [
            ObservationComponent(name: "Systolic", value: 120, unit: "mmHg"),
            ObservationComponent(name: "Diastolic", value: 80, unit: "mmHg")
        ]
        let content = ObservationRecord(
            observationType: "Blood Pressure",
            components: components,
            effectiveDate: Date()
        )
        let envelope = try RecordContentEnvelope(content)

        let decoded = try envelope.decodedFieldValues()

        let denormalized = decoded.known["components"] as? [ObservationComponent]
        #expect(denormalized?.count == 2)
        #expect(denormalized?[0].name == "Systolic")
        #expect(denormalized?[1].value == 80)
    }

    @Test(arguments: RecordType.allCases)
    func decodeAny_succeedsForEachRecordType(_ recordType: RecordType) throws {
        // Guards against forgetting a case in decodeAny(). This uses wrap() to produce
        // an envelope with a valid minimal JSON for each record type, then round-trips
        // through decodeAny() to confirm the switch covers every case.
        let jsonData = minimalJSON(for: recordType)
        let envelope = try RecordContentEnvelope.wrap(jsonData: jsonData, as: recordType)
        let content = try envelope.decodeAny()
        #expect(type(of: content).recordType == recordType)
    }

    /// Minimal valid JSON for each record type. Duplicated from RecordContentEnvelopeWrapTests
    /// for test isolation — keep in sync if record type required fields change.
    private func minimalJSON(for recordType: RecordType) -> Data {
        let json = switch recordType {
        case .immunization:
            "{\"vaccineCode\":\"X\",\"occurrenceDate\":0,\"tags\":[]}"
        case .medicationStatement:
            "{\"medicationName\":\"X\",\"tags\":[]}"
        case .allergyIntolerance:
            "{\"substance\":\"X\",\"tags\":[]}"
        case .condition:
            "{\"conditionName\":\"X\",\"tags\":[]}"
        case .observation:
            "{\"observationType\":\"X\",\"components\":[],\"effectiveDate\":0,\"tags\":[]}"
        case .procedure:
            "{\"procedureName\":\"X\",\"tags\":[]}"
        case .documentReference:
            """
            {"title":"X","mimeType":"application/octet-stream",\
            "fileSize":0,"contentHMAC":"AQID","tags":[]}
            """
        case .familyMemberHistory:
            "{\"relationship\":\"X\",\"conditionName\":\"Y\",\"tags\":[]}"
        case .clinicalNote:
            "{\"title\":\"X\",\"body\":\"\",\"tags\":[]}"
        }
        return Data(json.utf8)
    }
}

// MARK: - FieldValueDenormalizer

@Suite("FieldValueDenormalizer")
struct FieldValueDenormalizerTests {
    @Test
    func denormalize_dateDoubleBecomesDate() {
        let metadata = FieldMetadata(
            keyPath: "date", displayName: "Date", fieldType: .date, displayOrder: 1
        )
        let result = FieldValueDenormalizer.denormalize(700_000_000.0, for: metadata)
        #expect(result is Date)
    }

    @Test
    func denormalize_dateNonDoubleUnchanged() {
        let metadata = FieldMetadata(
            keyPath: "date", displayName: "Date", fieldType: .date, displayOrder: 1
        )
        let result = FieldValueDenormalizer.denormalize("not a double", for: metadata)
        #expect(result as? String == "not a double")
    }

    @Test
    func denormalize_autocompleteIdBecomesUUID() {
        let uuid = UUID()
        let metadata = FieldMetadata(
            keyPath: "providerId",
            displayName: "Provider",
            fieldType: .autocomplete,
            displayOrder: 1,
            semantic: .entityReference(.provider)
        )
        let result = FieldValueDenormalizer.denormalize(uuid.uuidString, for: metadata)
        #expect(result as? UUID == uuid)
    }

    @Test
    func denormalize_autocompleteNonIdUnchanged() {
        let metadata = FieldMetadata(
            keyPath: "vaccineCode",
            displayName: "Vaccine",
            fieldType: .autocomplete,
            autocompleteSource: .cvxVaccines,
            displayOrder: 1
        )
        let result = FieldValueDenormalizer.denormalize("Pfizer", for: metadata)
        #expect(result as? String == "Pfizer")
    }

    @Test
    func denormalize_componentsArrayDecodedToComponents() {
        let metadata = FieldMetadata(
            keyPath: "components", displayName: "Measurements", fieldType: .components, displayOrder: 1
        )
        let input: [[String: Any]] = [
            ["name": "Weight", "value": 70.5, "unit": "kg"]
        ]
        let result = FieldValueDenormalizer.denormalize(input, for: metadata)
        let components = result as? [ObservationComponent]
        #expect(components?.count == 1)
        #expect(components?.first?.name == "Weight")
    }

    @Test
    func denormalize_unrelatedFieldTypeReturnsValueUnchanged() {
        let metadata = FieldMetadata(
            keyPath: "notes", displayName: "Notes", fieldType: .text, displayOrder: 1
        )
        let result = FieldValueDenormalizer.denormalize("hello", for: metadata)
        #expect(result as? String == "hello")
    }

    @Test
    func denormalize_componentsWithMalformedEntryPreservesRawValue() {
        let metadata = FieldMetadata(
            keyPath: "components",
            displayName: "Measurements",
            fieldType: .components,
            displayOrder: 1
        )
        // Missing 'unit' field — won't decode as ObservationComponent.
        let malformed: [[String: Any]] = [["name": "Weight", "value": 70]]
        let result = FieldValueDenormalizer.denormalize(malformed, for: metadata)
        // Should NOT return an empty array — raw value is preserved so callers can
        // see the payload and forward-compat data isn't silently dropped.
        let arr = result as? [[String: Any]]
        #expect(arr?.count == 1)
        #expect(arr?.first?["name"] as? String == "Weight")
    }
}

// MARK: - FieldValueNormalizer

@Suite("FieldValueNormalizer")
struct FieldValueNormalizerTests {
    @Test
    func normalize_dateBecomesTimeIntervalSinceReferenceDate() {
        let metadata = FieldMetadata(
            keyPath: "occurrenceDate", displayName: "Date", fieldType: .date, displayOrder: 1
        )
        let date = Date(timeIntervalSinceReferenceDate: 123_456)
        let result = FieldValueNormalizer.normalize(date, for: metadata)
        #expect(result as? Double == 123_456)
    }

    @Test
    func normalize_uuidBecomesString() {
        let uuid = UUID()
        let metadata = FieldMetadata(
            keyPath: "providerId", displayName: "Provider", fieldType: .autocomplete, displayOrder: 1
        )
        let result = FieldValueNormalizer.normalize(uuid, for: metadata)
        #expect(result as? String == uuid.uuidString)
    }

    @Test
    func normalize_emptyStringOnOptionalFieldReturnsNil() {
        let metadata = FieldMetadata(
            keyPath: "lotNumber", displayName: "Lot", fieldType: .text, isRequired: false, displayOrder: 1
        )
        let result = FieldValueNormalizer.normalize("", for: metadata)
        #expect(result == nil)
    }

    @Test
    func normalize_emptyStringOnRequiredFieldReturnsEmpty() {
        let metadata = FieldMetadata(
            keyPath: "name", displayName: "Name", fieldType: .text, isRequired: true, displayOrder: 1
        )
        let result = FieldValueNormalizer.normalize("", for: metadata)
        #expect((result as? String)?.isEmpty == true)
    }

    @Test
    func normalize_tagsStringBecomesArray() {
        let metadata = FieldMetadata(
            keyPath: "tags",
            displayName: "Tags",
            fieldType: .text,
            displayOrder: 1,
            semantic: .tagList
        )
        let result = FieldValueNormalizer.normalize("a, b, c", for: metadata)
        #expect(result as? [String] == ["a", "b", "c"])
    }

    @Test
    func normalize_componentsArrayBecomesJSONDicts() {
        let metadata = FieldMetadata(
            keyPath: "components", displayName: "Measurements", fieldType: .components, displayOrder: 1
        )
        let components = [ObservationComponent(name: "Weight", value: 70, unit: "kg")]
        let result = FieldValueNormalizer.normalize(components, for: metadata)
        let dicts = result as? [[String: Any]]
        #expect(dicts?.count == 1)
        #expect(dicts?.first?["name"] as? String == "Weight")
    }

    @Test
    func normalize_emptyStringInOptionalProviderIdReturnsNil() {
        let metadata = FieldMetadata(
            keyPath: "providerId", displayName: "Provider", fieldType: .autocomplete, displayOrder: 1
        )
        let result = FieldValueNormalizer.normalize("", for: metadata)
        #expect(result == nil)
    }

    @Test
    func normalize_plainStringPassesThrough() {
        let metadata = FieldMetadata(
            keyPath: "notes", displayName: "Notes", fieldType: .multilineText, displayOrder: 1
        )
        let result = FieldValueNormalizer.normalize("hello world", for: metadata)
        #expect(result as? String == "hello world")
    }
}

// MARK: - RecordContentEnvelope.wrap

@Suite("RecordContentEnvelope.wrap dispatches per RecordType")
struct RecordContentEnvelopeWrapTests {
    @Test(arguments: RecordType.allCases)
    func wrap_succeedsForEachRecordType(_ recordType: RecordType) throws {
        let jsonData = minimalJSON(for: recordType)
        let envelope = try RecordContentEnvelope.wrap(jsonData: jsonData, as: recordType)
        #expect(envelope.recordType == recordType)
        #expect(envelope.schemaVersion == recordType.currentSchemaVersion)
    }

    @Test
    func wrap_surfacesDecodeErrorForMissingRequiredField() {
        // Immunization requires vaccineCode and occurrenceDate; omit them.
        let jsonData = Data("{\"tags\":[]}".utf8)
        #expect(throws: DecodingError.self) {
            _ = try RecordContentEnvelope.wrap(jsonData: jsonData, as: .immunization)
        }
    }

    /// Minimal valid JSON for each record type, matching its required fields.
    private func minimalJSON(for recordType: RecordType) -> Data {
        let json = switch recordType {
        case .immunization:
            "{\"vaccineCode\":\"X\",\"occurrenceDate\":0,\"tags\":[]}"
        case .medicationStatement:
            "{\"medicationName\":\"X\",\"tags\":[]}"
        case .allergyIntolerance:
            "{\"substance\":\"X\",\"tags\":[]}"
        case .condition:
            "{\"conditionName\":\"X\",\"tags\":[]}"
        case .observation:
            "{\"observationType\":\"X\",\"components\":[],\"effectiveDate\":0,\"tags\":[]}"
        case .procedure:
            "{\"procedureName\":\"X\",\"tags\":[]}"
        case .documentReference:
            """
            {"title":"X","mimeType":"application/octet-stream",\
            "fileSize":0,"contentHMAC":"AQID","tags":[]}
            """
        case .familyMemberHistory:
            "{\"relationship\":\"X\",\"conditionName\":\"Y\",\"tags\":[]}"
        case .clinicalNote:
            "{\"title\":\"X\",\"body\":\"\",\"tags\":[]}"
        }
        return Data(json.utf8)
    }
}
