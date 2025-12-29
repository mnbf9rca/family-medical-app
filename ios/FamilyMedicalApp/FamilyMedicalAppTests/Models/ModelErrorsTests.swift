import Foundation
import Testing
@testable import FamilyMedicalApp

struct ModelErrorsTests {
    // MARK: - Person Errors

    @Test
    func nameEmpty_hasDescription() {
        let error = ModelError.nameEmpty
        #expect(error.errorDescription == "Name cannot be empty")
    }

    @Test
    func nameTooLong_hasDescription() {
        let error = ModelError.nameTooLong(maxLength: 100)
        #expect(error.errorDescription == "Name cannot exceed 100 characters")
    }

    @Test
    func labelEmpty_hasDescription() {
        let error = ModelError.labelEmpty
        #expect(error.errorDescription == "Label cannot be empty")
    }

    @Test
    func labelTooLong_hasDescription() {
        let error = ModelError.labelTooLong(label: "test", maxLength: 50)
        #expect(error.errorDescription == "Label 'test' cannot exceed 50 characters")
    }

    // MARK: - Field Errors

    @Test
    func fieldRequired_hasDescription() {
        let error = ModelError.fieldRequired(fieldName: "name")
        #expect(error.errorDescription == "Field 'name' is required")
    }

    @Test
    func fieldTypeMismatch_hasDescription() {
        let error = ModelError.fieldTypeMismatch(
            fieldName: "age",
            expected: "int",
            got: "string"
        )
        #expect(error.errorDescription == "Field 'age' expected type int, got string")
    }

    @Test
    func validationFailed_hasDescription() {
        let error = ModelError.validationFailed(
            fieldName: "email",
            reason: "Invalid format"
        )
        #expect(error.errorDescription == "Field 'email' validation failed: Invalid format")
    }

    @Test
    func stringTooLong_hasDescription() {
        let error = ModelError.stringTooLong(fieldName: "notes", maxLength: 500)
        #expect(error.errorDescription == "Field 'notes' cannot exceed 500 characters")
    }

    @Test
    func stringTooShort_hasDescription() {
        let error = ModelError.stringTooShort(fieldName: "name", minLength: 3)
        #expect(error.errorDescription == "Field 'name' must be at least 3 characters")
    }

    @Test
    func numberOutOfRange_bothMinMax_hasDescription() {
        let error = ModelError.numberOutOfRange(fieldName: "age", min: 0, max: 120)
        #expect(error.errorDescription == "Field 'age' must be between 0.0 and 120.0")
    }

    @Test
    func numberOutOfRange_minOnly_hasDescription() {
        let error = ModelError.numberOutOfRange(fieldName: "price", min: 0, max: nil)
        #expect(error.errorDescription == "Field 'price' must be at least 0.0")
    }

    @Test
    func numberOutOfRange_maxOnly_hasDescription() {
        let error = ModelError.numberOutOfRange(fieldName: "discount", min: nil, max: 100)
        #expect(error.errorDescription == "Field 'discount' must be at most 100.0")
    }

    @Test
    func numberOutOfRange_neither_hasDescription() {
        let error = ModelError.numberOutOfRange(fieldName: "value", min: nil, max: nil)
        #expect(error.errorDescription == "Field 'value' is out of range")
    }

    @Test
    func dateOutOfRange_bothMinMax_hasDescription() {
        let minDate = Date(timeIntervalSince1970: 0)
        let maxDate = Date(timeIntervalSince1970: 1_000_000)
        let error = ModelError.dateOutOfRange(fieldName: "birthDate", min: minDate, max: maxDate)

        // Just verify it contains the field name and "between"
        let description = error.errorDescription ?? ""
        #expect(description.contains("birthDate"))
        #expect(description.contains("between"))
    }

    @Test
    func dateOutOfRange_minOnly_hasDescription() {
        let minDate = Date(timeIntervalSince1970: 0)
        let error = ModelError.dateOutOfRange(fieldName: "startDate", min: minDate, max: nil)

        let description = error.errorDescription ?? ""
        #expect(description.contains("startDate"))
        #expect(description.contains("on or after"))
    }

    @Test
    func dateOutOfRange_maxOnly_hasDescription() {
        let maxDate = Date(timeIntervalSince1970: 1_000_000)
        let error = ModelError.dateOutOfRange(fieldName: "endDate", min: nil, max: maxDate)

        let description = error.errorDescription ?? ""
        #expect(description.contains("endDate"))
        #expect(description.contains("on or before"))
    }

    @Test
    func dateOutOfRange_neither_hasDescription() {
        let error = ModelError.dateOutOfRange(fieldName: "date", min: nil, max: nil)
        #expect(error.errorDescription == "Field 'date' date is out of range")
    }

    // MARK: - Attachment Errors

    @Test
    func fileNameEmpty_hasDescription() {
        let error = ModelError.fileNameEmpty
        #expect(error.errorDescription == "File name cannot be empty")
    }

    @Test
    func fileNameTooLong_hasDescription() {
        let error = ModelError.fileNameTooLong(maxLength: 255)
        #expect(error.errorDescription == "File name cannot exceed 255 characters")
    }

    @Test
    func mimeTypeTooLong_hasDescription() {
        let error = ModelError.mimeTypeTooLong(maxLength: 100)
        #expect(error.errorDescription == "MIME type cannot exceed 100 characters")
    }

    @Test
    func invalidFileSize_hasDescription() {
        let error = ModelError.invalidFileSize
        #expect(error.errorDescription == "File size must be non-negative")
    }

    // MARK: - Schema Errors

    @Test
    func schemaNotFound_hasDescription() {
        let error = ModelError.schemaNotFound(schemaId: "custom-type")
        #expect(error.errorDescription == "Schema 'custom-type' not found")
    }

    @Test
    func invalidSchemaId_hasDescription() {
        let error = ModelError.invalidSchemaId("  ")
        #expect(error.errorDescription == "Invalid schema ID: '  '")
    }

    @Test
    func duplicateFieldId_hasDescription() {
        let error = ModelError.duplicateFieldId(fieldId: "name")
        #expect(error.errorDescription == "Duplicate field ID: 'name'")
    }

    @Test
    func fieldNotFound_hasDescription() {
        let error = ModelError.fieldNotFound(fieldId: "age")
        #expect(error.errorDescription == "Field 'age' not found in schema")
    }

    // MARK: - Equatable

    @Test
    func equatable_sameError_equal() {
        let error1 = ModelError.nameEmpty
        let error2 = ModelError.nameEmpty
        #expect(error1 == error2)
    }

    @Test
    func equatable_differentError_notEqual() {
        let error1 = ModelError.nameEmpty
        let error2 = ModelError.fileNameEmpty
        #expect(error1 != error2)
    }

    @Test
    func equatable_sameErrorWithParameters_equal() {
        let error1 = ModelError.nameTooLong(maxLength: 100)
        let error2 = ModelError.nameTooLong(maxLength: 100)
        #expect(error1 == error2)
    }

    @Test
    func equatable_sameErrorDifferentParameters_notEqual() {
        let error1 = ModelError.nameTooLong(maxLength: 100)
        let error2 = ModelError.nameTooLong(maxLength: 200)
        #expect(error1 != error2)
    }
}
