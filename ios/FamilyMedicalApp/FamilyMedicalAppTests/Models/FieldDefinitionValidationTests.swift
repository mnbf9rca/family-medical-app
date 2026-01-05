import Foundation
import Testing
@testable import FamilyMedicalApp

struct FieldDefinitionValidationTests {
    // MARK: - Initialization

    @Test
    func init_validDefinition_succeeds() {
        let fieldId = UUID()
        let definition = FieldDefinition.builtIn(
            id: fieldId,
            displayName: "Vaccine Name",
            fieldType: .string,
            isRequired: true,
            displayOrder: 1
        )

        #expect(definition.id == fieldId)
        #expect(definition.isRequired)
        #expect(definition.displayOrder == 1)
    }

    // MARK: - Validation - Required Fields

    @Test
    func validate_requiredFieldPresent_succeeds() throws {
        let definition = FieldDefinition.builtIn(
            id: UUID(),
            displayName: "Name",
            fieldType: .string,
            isRequired: true
        )

        let value = FieldValue.string("John")
        try definition.validate(value)
    }

    @Test
    func validate_requiredFieldMissing_throwsError() {
        let definition = FieldDefinition.builtIn(
            id: UUID(),
            displayName: "Name",
            fieldType: .string,
            isRequired: true
        )

        #expect(throws: ModelError.self) {
            try definition.validate(nil as FieldValue?)
        }
    }

    @Test
    func validate_optionalFieldMissing_succeeds() throws {
        let definition = FieldDefinition.builtIn(
            id: UUID(),
            displayName: "Notes",
            fieldType: .string,
            isRequired: false
        )

        try definition.validate(nil as FieldValue?)
    }

    // MARK: - Validation - Type Matching

    @Test
    func validate_correctType_succeeds() throws {
        let definition = FieldDefinition.builtIn(
            id: UUID(),
            displayName: "Age",
            fieldType: .int
        )

        try definition.validate(FieldValue.int(42))
    }

    @Test
    func validate_wrongType_throwsError() {
        let definition = FieldDefinition.builtIn(
            id: UUID(),
            displayName: "Age",
            fieldType: .int
        )

        #expect(throws: ModelError.self) {
            try definition.validate(FieldValue.string("42"))
        }
    }

    // MARK: - Validation - String Length

    @Test
    func validate_minLength_valid_succeeds() throws {
        let definition = FieldDefinition.builtIn(
            id: UUID(),
            displayName: "Name",
            fieldType: .string,
            validationRules: [.minLength(3)]
        )

        try definition.validate(FieldValue.string("John"))
    }

    @Test
    func validate_minLength_tooShort_throwsError() {
        let definition = FieldDefinition.builtIn(
            id: UUID(),
            displayName: "Name",
            fieldType: .string,
            validationRules: [.minLength(5)]
        )

        #expect(throws: ModelError.self) {
            try definition.validate(FieldValue.string("Joe"))
        }
    }

    @Test
    func validate_maxLength_valid_succeeds() throws {
        let definition = FieldDefinition.builtIn(
            id: UUID(),
            displayName: "Name",
            fieldType: .string,
            validationRules: [.maxLength(10)]
        )

        try definition.validate(FieldValue.string("John"))
    }

    @Test
    func validate_maxLength_tooLong_throwsError() {
        let definition = FieldDefinition.builtIn(
            id: UUID(),
            displayName: "Name",
            fieldType: .string,
            validationRules: [.maxLength(5)]
        )

        #expect(throws: ModelError.self) {
            try definition.validate(FieldValue.string("Jonathan"))
        }
    }

    // MARK: - Validation - Number Range

    @Test
    func validate_intMinValue_valid_succeeds() throws {
        let definition = FieldDefinition.builtIn(
            id: UUID(),
            displayName: "Age",
            fieldType: .int,
            validationRules: [.minValue(0)]
        )

        try definition.validate(FieldValue.int(25))
    }

    @Test
    func validate_intMinValue_tooLow_throwsError() {
        let definition = FieldDefinition.builtIn(
            id: UUID(),
            displayName: "Age",
            fieldType: .int,
            validationRules: [.minValue(0)]
        )

        #expect(throws: ModelError.self) {
            try definition.validate(FieldValue.int(-5))
        }
    }

    @Test
    func validate_doubleMaxValue_valid_succeeds() throws {
        let definition = FieldDefinition.builtIn(
            id: UUID(),
            displayName: "Price",
            fieldType: .double,
            validationRules: [.maxValue(100.0)]
        )

        try definition.validate(FieldValue.double(50.5))
    }

    @Test
    func validate_doubleMaxValue_tooHigh_throwsError() {
        let definition = FieldDefinition.builtIn(
            id: UUID(),
            displayName: "Price",
            fieldType: .double,
            validationRules: [.maxValue(100.0)]
        )

        #expect(throws: ModelError.self) {
            try definition.validate(FieldValue.double(150.0))
        }
    }

    // MARK: - Validation - Date Range

    @Test
    func validate_minDate_valid_succeeds() throws {
        let minDate = Date(timeIntervalSince1970: 0)
        let definition = FieldDefinition.builtIn(
            id: UUID(),
            displayName: "Start Date",
            fieldType: .date,
            validationRules: [.minDate(minDate)]
        )

        let futureDate = Date(timeIntervalSince1970: 1_000_000)
        try definition.validate(FieldValue.date(futureDate))
    }

    @Test
    func validate_minDate_tooEarly_throwsError() {
        let minDate = Date(timeIntervalSince1970: 1_000_000)
        let definition = FieldDefinition.builtIn(
            id: UUID(),
            displayName: "Start Date",
            fieldType: .date,
            validationRules: [.minDate(minDate)]
        )

        let earlierDate = Date(timeIntervalSince1970: 0)
        #expect(throws: ModelError.self) {
            try definition.validate(FieldValue.date(earlierDate))
        }
    }

    // MARK: - Validation - Pattern

    @Test
    func validate_pattern_matches_succeeds() throws {
        let definition = FieldDefinition.builtIn(
            id: UUID(),
            displayName: "Email",
            fieldType: .string,
            validationRules: [.pattern("^[a-z]+@[a-z]+\\.[a-z]+$")]
        )

        try definition.validate(FieldValue.string("test@example.com"))
    }

    @Test
    func validate_pattern_noMatch_throwsError() {
        let definition = FieldDefinition.builtIn(
            id: UUID(),
            displayName: "Email",
            fieldType: .string,
            validationRules: [.pattern("^[a-z]+@[a-z]+\\.[a-z]+$")]
        )

        #expect(throws: ModelError.self) {
            try definition.validate(FieldValue.string("invalid"))
        }
    }
}
