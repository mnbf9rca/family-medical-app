import Foundation

// MARK: - User-Facing Error Messages

extension ModelError {
    /// User-friendly error message for display in UI
    var userFacingMessage: String {
        switch self {
        // Person errors
        case .nameEmpty:
            return "Name cannot be empty."
        case let .nameTooLong(maxLength):
            return "Name must be no more than \(maxLength) character\(maxLength == 1 ? "" : "s")."
        case .labelEmpty:
            return "Label cannot be empty."
        case let .labelTooLong(label, maxLength):
            return "Label '\(label)' must be no more than \(maxLength) character\(maxLength == 1 ? "" : "s")."
        // Record field errors
        case let .fieldRequired(fieldName):
            return "\(fieldName) is required."
        case let .fieldTypeMismatch(fieldName, expected, got):
            return "\(fieldName) has an invalid value. Expected \(expected), got \(got)."
        case let .stringTooShort(fieldName, minLength):
            return "\(fieldName) must be at least \(minLength) character\(minLength == 1 ? "" : "s")."
        case let .stringTooLong(fieldName, maxLength):
            return "\(fieldName) must be no more than \(maxLength) character\(maxLength == 1 ? "" : "s")."
        case let .numberOutOfRange(fieldName, min, max):
            if let min, let max {
                return "\(fieldName) must be between \(min) and \(max)."
            } else if let min {
                return "\(fieldName) must be at least \(min)."
            } else if let max {
                return "\(fieldName) must be at most \(max)."
            } else {
                return "\(fieldName) has an invalid value."
            }
        case let .dateOutOfRange(fieldName, min, max):
            if let min, let max {
                let minStr = min.formatted(date: .abbreviated, time: .omitted)
                let maxStr = max.formatted(date: .abbreviated, time: .omitted)
                return "\(fieldName) must be between \(minStr) and \(maxStr)."
            } else if let min {
                let minStr = min.formatted(date: .abbreviated, time: .omitted)
                return "\(fieldName) must be after \(minStr)."
            } else if let max {
                let maxStr = max.formatted(date: .abbreviated, time: .omitted)
                return "\(fieldName) must be before \(maxStr)."
            } else {
                return "\(fieldName) has an invalid date."
            }
        case let .validationFailed(fieldName, reason):
            return "\(fieldName): \(reason)"
        // Attachment errors
        case .fileNameEmpty:
            return "File name cannot be empty."
        case let .fileNameTooLong(maxLength):
            return "File name must be no more than \(maxLength) character\(maxLength == 1 ? "" : "s")."
        case let .mimeTypeTooLong(maxLength):
            return "MIME type must be no more than \(maxLength) character\(maxLength == 1 ? "" : "s")."
        case .invalidFileSize:
            return "File size is invalid."
        case let .attachmentTooLarge(maxSizeMB):
            return "File is too large. Maximum size is \(maxSizeMB) MB."
        case let .unsupportedMimeType(mimeType):
            return "File type '\(mimeType)' is not supported. Please use JPEG, PNG, or PDF."
        case let .attachmentLimitExceeded(max):
            return "Maximum of \(max) attachments per record reached."
        case .attachmentNotFound:
            return "Attachment not found."
        case .attachmentContentCorrupted:
            return "Unable to read attachment content."
        case let .attachmentStorageFailed(reason):
            return "Failed to save attachment: \(reason)"
        case let .imageProcessingFailed(reason):
            return "Failed to process image: \(reason)"
        // Schema errors
        case let .schemaNotFound(schemaId):
            return "Schema '\(schemaId)' not found."
        case let .invalidSchemaId(id):
            return "Invalid schema ID: \(id)"
        case let .duplicateFieldId(fieldId):
            return "Duplicate field: \(fieldId)"
        case let .fieldNotFound(fieldId):
            return "Field '\(fieldId)' not found."
        }
    }
}
