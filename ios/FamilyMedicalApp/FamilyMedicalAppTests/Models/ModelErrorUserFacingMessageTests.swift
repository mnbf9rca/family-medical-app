import Foundation
import Testing
@testable import FamilyMedicalApp

/// Tests for ModelError.userFacingMessage computed property
struct ModelErrorUserFacingMessageTests {
    // MARK: - Basic Tests

    @Test
    func modelErrorProducesUserFriendlyMessages() {
        let error1 = ModelError.fieldRequired(fieldName: "vaccine name")
        #expect(error1.userFacingMessage == "vaccine name is required.")

        let error2 = ModelError.stringTooLong(fieldName: "name", maxLength: 100)
        #expect(error2.userFacingMessage.contains("100") == true)

        let error3 = ModelError.numberOutOfRange(fieldName: "dose", min: 1, max: nil)
        #expect(error3.userFacingMessage.contains("at least 1") == true)
    }

    // MARK: - Person Error Messages

    @Test
    func modelErrorNameEmptyMessage() {
        let error = ModelError.nameEmpty
        #expect(error.userFacingMessage == "Name cannot be empty.")
    }

    @Test
    func modelErrorNameTooLongMessage() {
        let error = ModelError.nameTooLong(maxLength: 50)
        #expect(error.userFacingMessage == "Name must be no more than 50 characters.")
    }

    @Test
    func modelErrorNameTooLongSingularMessage() {
        let error = ModelError.nameTooLong(maxLength: 1)
        #expect(error.userFacingMessage == "Name must be no more than 1 character.")
    }

    @Test
    func modelErrorLabelEmptyMessage() {
        let error = ModelError.labelEmpty
        #expect(error.userFacingMessage == "Label cannot be empty.")
    }

    @Test
    func modelErrorLabelTooLongMessage() {
        let error = ModelError.labelTooLong(label: "TestLabel", maxLength: 20)
        #expect(error.userFacingMessage == "Label 'TestLabel' must be no more than 20 characters.")
    }

    // MARK: - Field Error Messages

    @Test
    func modelErrorFieldRequiredMessage() {
        let error = ModelError.fieldRequired(fieldName: "Vaccine Name")
        #expect(error.userFacingMessage == "Vaccine Name is required.")
    }

    @Test
    func modelErrorFieldTypeMismatchMessage() {
        let error = ModelError.fieldTypeMismatch(fieldName: "Dose", expected: "int", got: "string")
        #expect(error.userFacingMessage == "Dose has an invalid value. Expected int, got string.")
    }

    @Test
    func modelErrorStringTooShortMessage() {
        let error = ModelError.stringTooShort(fieldName: "Name", minLength: 3)
        #expect(error.userFacingMessage == "Name must be at least 3 characters.")
    }

    @Test
    func modelErrorStringTooShortSingularMessage() {
        let error = ModelError.stringTooShort(fieldName: "Code", minLength: 1)
        #expect(error.userFacingMessage == "Code must be at least 1 character.")
    }

    @Test
    func modelErrorStringTooLongMessage() {
        let error = ModelError.stringTooLong(fieldName: "Description", maxLength: 500)
        #expect(error.userFacingMessage == "Description must be no more than 500 characters.")
    }

    @Test
    func modelErrorStringTooLongSingularMessage() {
        let error = ModelError.stringTooLong(fieldName: "Flag", maxLength: 1)
        #expect(error.userFacingMessage == "Flag must be no more than 1 character.")
    }

    // MARK: - Number Range Error Messages

    @Test
    func modelErrorNumberOutOfRangeWithBothBoundsMessage() {
        let error = ModelError.numberOutOfRange(fieldName: "Quantity", min: 1, max: 100)
        #expect(error.userFacingMessage.contains("Quantity must be between"))
        #expect(error.userFacingMessage.contains("1"))
        #expect(error.userFacingMessage.contains("100"))
    }

    @Test
    func modelErrorNumberOutOfRangeWithMinOnlyMessage() {
        let error = ModelError.numberOutOfRange(fieldName: "Age", min: 0, max: nil)
        #expect(error.userFacingMessage.contains("Age must be at least"))
        #expect(error.userFacingMessage.contains("0"))
    }

    @Test
    func modelErrorNumberOutOfRangeWithMaxOnlyMessage() {
        let error = ModelError.numberOutOfRange(fieldName: "Score", min: nil, max: 100)
        #expect(error.userFacingMessage.contains("Score must be at most"))
        #expect(error.userFacingMessage.contains("100"))
    }

    @Test
    func modelErrorNumberOutOfRangeWithNoBoundsMessage() {
        let error = ModelError.numberOutOfRange(fieldName: "Value", min: nil, max: nil)
        #expect(error.userFacingMessage == "Value has an invalid value.")
    }

    // MARK: - Date Range Error Messages

    @Test
    func modelErrorDateOutOfRangeWithBothBoundsMessage() {
        let minDate = Date(timeIntervalSince1970: 0)
        let maxDate = Date(timeIntervalSince1970: 86_400)
        let error = ModelError.dateOutOfRange(fieldName: "Date", min: minDate, max: maxDate)
        #expect(error.userFacingMessage.contains("must be between"))
    }

    @Test
    func modelErrorDateOutOfRangeWithMinOnlyMessage() {
        let minDate = Date(timeIntervalSince1970: 0)
        let error = ModelError.dateOutOfRange(fieldName: "Start Date", min: minDate, max: nil)
        #expect(error.userFacingMessage.contains("must be after"))
    }

    @Test
    func modelErrorDateOutOfRangeWithMaxOnlyMessage() {
        let maxDate = Date(timeIntervalSince1970: 86_400)
        let error = ModelError.dateOutOfRange(fieldName: "End Date", min: nil, max: maxDate)
        #expect(error.userFacingMessage.contains("must be before"))
    }

    @Test
    func modelErrorDateOutOfRangeWithNoBoundsMessage() {
        let error = ModelError.dateOutOfRange(fieldName: "Event Date", min: nil, max: nil)
        #expect(error.userFacingMessage == "Event Date has an invalid date.")
    }

    // MARK: - Validation Error Messages

    @Test
    func modelErrorValidationFailedMessage() {
        let error = ModelError.validationFailed(fieldName: "Email", reason: "Invalid format")
        #expect(error.userFacingMessage == "Email: Invalid format")
    }

    // MARK: - Attachment Error Messages

    @Test
    func modelErrorFileNameEmptyMessage() {
        let error = ModelError.fileNameEmpty
        #expect(error.userFacingMessage == "File name cannot be empty.")
    }

    @Test
    func modelErrorFileNameTooLongMessage() {
        let error = ModelError.fileNameTooLong(maxLength: 255)
        #expect(error.userFacingMessage == "File name must be no more than 255 characters.")
    }

    @Test
    func modelErrorMimeTypeTooLongMessage() {
        let error = ModelError.mimeTypeTooLong(maxLength: 100)
        #expect(error.userFacingMessage == "MIME type must be no more than 100 characters.")
    }

    @Test
    func modelErrorInvalidFileSizeMessage() {
        let error = ModelError.invalidFileSize
        #expect(error.userFacingMessage == "File size is invalid.")
    }

    // MARK: - Schema Error Messages

    @Test
    func modelErrorSchemaNotFoundMessage() {
        let error = ModelError.schemaNotFound(schemaId: "custom_schema")
        #expect(error.userFacingMessage == "Schema 'custom_schema' not found.")
    }

    @Test
    func modelErrorInvalidSchemaIdMessage() {
        let error = ModelError.invalidSchemaId("bad-id")
        #expect(error.userFacingMessage == "Invalid schema ID: bad-id")
    }

    @Test
    func modelErrorDuplicateFieldIdMessage() {
        let error = ModelError.duplicateFieldId(fieldId: "name")
        #expect(error.userFacingMessage == "Duplicate field: name")
    }

    @Test
    func modelErrorFieldNotFoundMessage() {
        let error = ModelError.fieldNotFound(fieldId: "missingField")
        #expect(error.userFacingMessage == "Field 'missingField' not found.")
    }
}
