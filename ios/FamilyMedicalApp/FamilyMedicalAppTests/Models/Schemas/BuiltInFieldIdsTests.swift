import Foundation
import Testing
@testable import FamilyMedicalApp

/// Tests for BuiltInFieldIds
struct BuiltInFieldIdsTests {
    // MARK: - allFieldIds Tests

    @Test
    func allFieldIds_containsExpectedTotalCount() {
        // 8 vaccine + 7 condition + 10 medication + 6 allergy + 3 note = 34
        #expect(BuiltInFieldIds.allFieldIds.count == 34)
    }

    @Test
    func allFieldIds_containsAllVaccineFields() {
        for fieldId in BuiltInFieldIds.Vaccine.allFields {
            #expect(BuiltInFieldIds.allFieldIds.contains(fieldId))
        }
    }

    @Test
    func allFieldIds_containsAllConditionFields() {
        for fieldId in BuiltInFieldIds.Condition.allFields {
            #expect(BuiltInFieldIds.allFieldIds.contains(fieldId))
        }
    }

    @Test
    func allFieldIds_containsAllMedicationFields() {
        for fieldId in BuiltInFieldIds.Medication.allFields {
            #expect(BuiltInFieldIds.allFieldIds.contains(fieldId))
        }
    }

    @Test
    func allFieldIds_containsAllAllergyFields() {
        for fieldId in BuiltInFieldIds.Allergy.allFields {
            #expect(BuiltInFieldIds.allFieldIds.contains(fieldId))
        }
    }

    @Test
    func allFieldIds_containsAllNoteFields() {
        for fieldId in BuiltInFieldIds.Note.allFields {
            #expect(BuiltInFieldIds.allFieldIds.contains(fieldId))
        }
    }

    @Test
    func allFieldIds_hasNoOverlapBetweenSchemas() {
        // Each schema's field IDs should be unique across all schemas
        let vaccine = Set(BuiltInFieldIds.Vaccine.allFields)
        let condition = Set(BuiltInFieldIds.Condition.allFields)
        let medication = Set(BuiltInFieldIds.Medication.allFields)
        let allergy = Set(BuiltInFieldIds.Allergy.allFields)
        let note = Set(BuiltInFieldIds.Note.allFields)

        // Check no overlaps
        #expect(vaccine.isDisjoint(with: condition))
        #expect(vaccine.isDisjoint(with: medication))
        #expect(vaccine.isDisjoint(with: allergy))
        #expect(vaccine.isDisjoint(with: note))
        #expect(condition.isDisjoint(with: medication))
        #expect(condition.isDisjoint(with: allergy))
        #expect(condition.isDisjoint(with: note))
        #expect(medication.isDisjoint(with: allergy))
        #expect(medication.isDisjoint(with: note))
        #expect(allergy.isDisjoint(with: note))
    }

    // MARK: - isBuiltIn Tests

    @Test
    func isBuiltIn_returnsTrueForVaccineFieldId() {
        #expect(BuiltInFieldIds.isBuiltIn(BuiltInFieldIds.Vaccine.name) == true)
        #expect(BuiltInFieldIds.isBuiltIn(BuiltInFieldIds.Vaccine.dateAdministered) == true)
        #expect(BuiltInFieldIds.isBuiltIn(BuiltInFieldIds.Vaccine.notes) == true)
    }

    @Test
    func isBuiltIn_returnsTrueForConditionFieldId() {
        #expect(BuiltInFieldIds.isBuiltIn(BuiltInFieldIds.Condition.name) == true)
        #expect(BuiltInFieldIds.isBuiltIn(BuiltInFieldIds.Condition.severity) == true)
    }

    @Test
    func isBuiltIn_returnsTrueForMedicationFieldId() {
        #expect(BuiltInFieldIds.isBuiltIn(BuiltInFieldIds.Medication.name) == true)
        #expect(BuiltInFieldIds.isBuiltIn(BuiltInFieldIds.Medication.dosage) == true)
    }

    @Test
    func isBuiltIn_returnsTrueForAllergyFieldId() {
        #expect(BuiltInFieldIds.isBuiltIn(BuiltInFieldIds.Allergy.allergen) == true)
        #expect(BuiltInFieldIds.isBuiltIn(BuiltInFieldIds.Allergy.reaction) == true)
    }

    @Test
    func isBuiltIn_returnsTrueForNoteFieldId() {
        #expect(BuiltInFieldIds.isBuiltIn(BuiltInFieldIds.Note.title) == true)
        #expect(BuiltInFieldIds.isBuiltIn(BuiltInFieldIds.Note.content) == true)
    }

    @Test
    func isBuiltIn_returnsFalseForRandomUUID() {
        let randomUUID = UUID()
        #expect(BuiltInFieldIds.isBuiltIn(randomUUID) == false)
    }

    @Test
    func isBuiltIn_returnsFalseForZeroUUID() {
        #expect(BuiltInFieldIds.isBuiltIn(UUID.zero) == false)
    }

    // MARK: - Schema Field Count Tests

    @Test
    func vaccineAllFields_hasExpectedCount() {
        #expect(BuiltInFieldIds.Vaccine.allFields.count == 8)
    }

    @Test
    func conditionAllFields_hasExpectedCount() {
        #expect(BuiltInFieldIds.Condition.allFields.count == 7)
    }

    @Test
    func medicationAllFields_hasExpectedCount() {
        #expect(BuiltInFieldIds.Medication.allFields.count == 10)
    }

    @Test
    func allergyAllFields_hasExpectedCount() {
        #expect(BuiltInFieldIds.Allergy.allFields.count == 6)
    }

    @Test
    func noteAllFields_hasExpectedCount() {
        #expect(BuiltInFieldIds.Note.allFields.count == 3)
    }

    // MARK: - UUID Format Tests

    @Test
    func vaccineFieldIds_followExpectedFormat() {
        // Vaccine schema uses 0001 in the schema segment
        let expectedPrefix = "00000001-0001-"
        for field in BuiltInFieldIds.Vaccine.allFields {
            #expect(field.uuidString.hasPrefix(expectedPrefix))
        }
    }

    @Test
    func conditionFieldIds_followExpectedFormat() {
        // Condition schema uses 0002 in the schema segment
        let expectedPrefix = "00000001-0002-"
        for field in BuiltInFieldIds.Condition.allFields {
            #expect(field.uuidString.hasPrefix(expectedPrefix))
        }
    }

    @Test
    func medicationFieldIds_followExpectedFormat() {
        // Medication schema uses 0003 in the schema segment
        let expectedPrefix = "00000001-0003-"
        for field in BuiltInFieldIds.Medication.allFields {
            #expect(field.uuidString.hasPrefix(expectedPrefix))
        }
    }

    @Test
    func allergyFieldIds_followExpectedFormat() {
        // Allergy schema uses 0004 in the schema segment
        let expectedPrefix = "00000001-0004-"
        for field in BuiltInFieldIds.Allergy.allFields {
            #expect(field.uuidString.hasPrefix(expectedPrefix))
        }
    }

    @Test
    func noteFieldIds_followExpectedFormat() {
        // Note schema uses 0005 in the schema segment
        let expectedPrefix = "00000001-0005-"
        for field in BuiltInFieldIds.Note.allFields {
            #expect(field.uuidString.hasPrefix(expectedPrefix))
        }
    }
}
