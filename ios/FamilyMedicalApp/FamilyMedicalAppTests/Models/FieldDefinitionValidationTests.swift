import Foundation
import Testing
@testable import FamilyMedicalApp

struct FieldDefinitionValidationTests {
    // MARK: - Initialization

    @Test
    func init_validDefinition_succeeds() {
        let definition = FieldDefinition(
            id: "vaccineName",
            displayName: "Vaccine Name",
            fieldType: .string,
            isRequired: true,
            displayOrder: 1
        )

        #expect(definition.id == "vaccineName")
        #expect(definition.isRequired)
        #expect(definition.displayOrder == 1)
    }

    // MARK: - Validation - Required Fields

    @Test
    func validate_requiredFieldPresent_succeeds() throws {
        let definition = FieldDefinition(
            id: "name",
            displayName: "Name",
            fieldType: .string,
            isRequired: true
        )

        let value = FieldValue.string("John")
        try definition.validate(value)
    }

    @Test
    func validate_requiredFieldMissing_throwsError() {
        let definition = FieldDefinition(
            id: "name",
            displayName: "Name",
            fieldType: .string,
            isRequired: true
        )

        #expect(throws: ModelError.self) {
            try definition.validate(nil)
        }
    }

    @Test
    func validate_optionalFieldMissing_succeeds() throws {
        let definition = FieldDefinition(
            id: "notes",
            displayName: "Notes",
            fieldType: .string,
            isRequired: false
        )

        try definition.validate(nil)
    }

    // MARK: - Validation - Type Matching

    @Test
    func validate_correctType_succeeds() throws {
        let definition = FieldDefinition(
            id: "age",
            displayName: "Age",
            fieldType: .int
        )

        try definition.validate(.int(42))
    }

    @Test
    func validate_wrongType_throwsError() {
        let definition = FieldDefinition(
            id: "age",
            displayName: "Age",
            fieldType: .int
        )

        #expect(throws: ModelError.self) {
            try definition.validate(.string("42"))
        }
    }

    // MARK: - Validation - String Length

    @Test
    func validate_minLength_valid_succeeds() throws {
        let definition = FieldDefinition(
            id: "name",
            displayName: "Name",
            fieldType: .string,
            validationRules: [.minLength(3)]
        )

        try definition.validate(.string("John"))
    }

    @Test
    func validate_minLength_tooShort_throwsError() {
        let definition = FieldDefinition(
            id: "name",
            displayName: "Name",
            fieldType: .string,
            validationRules: [.minLength(5)]
        )

        #expect(throws: ModelError.self) {
            try definition.validate(.string("Joe"))
        }
    }

    @Test
    func validate_maxLength_valid_succeeds() throws {
        let definition = FieldDefinition(
            id: "name",
            displayName: "Name",
            fieldType: .string,
            validationRules: [.maxLength(10)]
        )

        try definition.validate(.string("John"))
    }

    @Test
    func validate_maxLength_tooLong_throwsError() {
        let definition = FieldDefinition(
            id: "name",
            displayName: "Name",
            fieldType: .string,
            validationRules: [.maxLength(5)]
        )

        #expect(throws: ModelError.self) {
            try definition.validate(.string("Jonathan"))
        }
    }

    // MARK: - Validation - Number Range

    @Test
    func validate_intMinValue_valid_succeeds() throws {
        let definition = FieldDefinition(
            id: "age",
            displayName: "Age",
            fieldType: .int,
            validationRules: [.minValue(0)]
        )

        try definition.validate(.int(25))
    }

    @Test
    func validate_intMinValue_tooLow_throwsError() {
        let definition = FieldDefinition(
            id: "age",
            displayName: "Age",
            fieldType: .int,
            validationRules: [.minValue(0)]
        )

        #expect(throws: ModelError.self) {
            try definition.validate(.int(-5))
        }
    }

    @Test
    func validate_doubleMaxValue_valid_succeeds() throws {
        let definition = FieldDefinition(
            id: "price",
            displayName: "Price",
            fieldType: .double,
            validationRules: [.maxValue(100.0)]
        )

        try definition.validate(.double(50.5))
    }

    @Test
    func validate_doubleMaxValue_tooHigh_throwsError() {
        let definition = FieldDefinition(
            id: "price",
            displayName: "Price",
            fieldType: .double,
            validationRules: [.maxValue(100.0)]
        )

        #expect(throws: ModelError.self) {
            try definition.validate(.double(150.0))
        }
    }

    // MARK: - Validation - Date Range

    @Test
    func validate_minDate_valid_succeeds() throws {
        let minDate = Date(timeIntervalSince1970: 0)
        let definition = FieldDefinition(
            id: "startDate",
            displayName: "Start Date",
            fieldType: .date,
            validationRules: [.minDate(minDate)]
        )

        let futureDate = Date(timeIntervalSince1970: 1_000_000)
        try definition.validate(.date(futureDate))
    }

    @Test
    func validate_minDate_tooEarly_throwsError() {
        let minDate = Date(timeIntervalSince1970: 1_000_000)
        let definition = FieldDefinition(
            id: "startDate",
            displayName: "Start Date",
            fieldType: .date,
            validationRules: [.minDate(minDate)]
        )

        let earlierDate = Date(timeIntervalSince1970: 0)
        #expect(throws: ModelError.self) {
            try definition.validate(.date(earlierDate))
        }
    }

    // MARK: - Validation - Pattern

    @Test
    func validate_pattern_matches_succeeds() throws {
        let definition = FieldDefinition(
            id: "email",
            displayName: "Email",
            fieldType: .string,
            validationRules: [.pattern("^[a-z]+@[a-z]+\\.[a-z]+$")]
        )

        try definition.validate(.string("test@example.com"))
    }

    @Test
    func validate_pattern_noMatch_throwsError() {
        let definition = FieldDefinition(
            id: "email",
            displayName: "Email",
            fieldType: .string,
            validationRules: [.pattern("^[a-z]+@[a-z]+\\.[a-z]+$")]
        )

        #expect(throws: ModelError.self) {
            try definition.validate(.string("invalid"))
        }
    }
}
