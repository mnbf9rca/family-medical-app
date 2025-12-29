import Foundation

/// Validation errors for medical record models
enum ModelError: LocalizedError, Equatable {
    // MARK: - Person Errors

    case nameEmpty
    case nameTooLong(maxLength: Int)
    case labelEmpty
    case labelTooLong(label: String, maxLength: Int)

    // MARK: - Record Field Errors

    case fieldRequired(fieldName: String)
    case fieldTypeMismatch(fieldName: String, expected: String, got: String)
    case validationFailed(fieldName: String, reason: String)
    case stringTooLong(fieldName: String, maxLength: Int)
    case stringTooShort(fieldName: String, minLength: Int)
    case numberOutOfRange(fieldName: String, min: Double?, max: Double?)
    case dateOutOfRange(fieldName: String, min: Date?, max: Date?)

    // MARK: - Attachment Errors

    case fileNameEmpty
    case fileNameTooLong(maxLength: Int)
    case mimeTypeTooLong(maxLength: Int)
    case invalidFileSize

    // MARK: - Schema Errors

    case schemaNotFound(schemaId: String)
    case invalidSchemaId(String)
    case duplicateFieldId(fieldId: String)
    case fieldNotFound(fieldId: String)

    // MARK: - LocalizedError Conformance

    var errorDescription: String? {
        switch self {
        // Person errors
        case .nameEmpty:
            "Name cannot be empty"
        case let .nameTooLong(maxLength):
            "Name cannot exceed \(maxLength) characters"
        case .labelEmpty:
            "Label cannot be empty"
        case let .labelTooLong(label, maxLength):
            "Label '\(label)' cannot exceed \(maxLength) characters"
        // Field errors
        case let .fieldRequired(fieldName):
            "Field '\(fieldName)' is required"
        case let .fieldTypeMismatch(fieldName, expected, got):
            "Field '\(fieldName)' expected type \(expected), got \(got)"
        case let .validationFailed(fieldName, reason):
            "Field '\(fieldName)' validation failed: \(reason)"
        case let .stringTooLong(fieldName, maxLength):
            "Field '\(fieldName)' cannot exceed \(maxLength) characters"
        case let .stringTooShort(fieldName, minLength):
            "Field '\(fieldName)' must be at least \(minLength) characters"
        case let .numberOutOfRange(fieldName, min, max):
            if let min, let max {
                "Field '\(fieldName)' must be between \(min) and \(max)"
            } else if let min {
                "Field '\(fieldName)' must be at least \(min)"
            } else if let max {
                "Field '\(fieldName)' must be at most \(max)"
            } else {
                "Field '\(fieldName)' is out of range"
            }
        case let .dateOutOfRange(fieldName, min, max):
            if let min, let max {
                "Field '\(fieldName)' must be between \(formatDate(min)) and \(formatDate(max))"
            } else if let min {
                "Field '\(fieldName)' must be on or after \(formatDate(min))"
            } else if let max {
                "Field '\(fieldName)' must be on or before \(formatDate(max))"
            } else {
                "Field '\(fieldName)' date is out of range"
            }
        // Attachment errors
        case .fileNameEmpty:
            "File name cannot be empty"
        case let .fileNameTooLong(maxLength):
            "File name cannot exceed \(maxLength) characters"
        case let .mimeTypeTooLong(maxLength):
            "MIME type cannot exceed \(maxLength) characters"
        case .invalidFileSize:
            "File size must be non-negative"
        // Schema errors
        case let .schemaNotFound(schemaId):
            "Schema '\(schemaId)' not found"
        case let .invalidSchemaId(id):
            "Invalid schema ID: '\(id)'"
        case let .duplicateFieldId(fieldId):
            "Duplicate field ID: '\(fieldId)'"
        case let .fieldNotFound(fieldId):
            "Field '\(fieldId)' not found in schema"
        }
    }

    // MARK: - Helper Methods

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
