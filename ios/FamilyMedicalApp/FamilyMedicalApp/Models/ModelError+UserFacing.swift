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
        // Document errors
        case let .documentTooLarge(maxSizeMB):
            return "File is too large. Maximum size is \(maxSizeMB) MB."
        case let .unsupportedMimeType(mimeType):
            return "File type '\(mimeType)' is not supported. Please use JPEG, PNG, or PDF."
        case let .documentLimitExceeded(max):
            return "Maximum of \(max) attachments per record reached."
        case .documentNotFound:
            return "Document not found."
        case .documentContentCorrupted:
            return "Unable to read document content."
        case let .documentStorageFailed(reason):
            return "Failed to save document: \(reason)"
        case let .imageProcessingFailed(reason):
            return "Failed to process image: \(reason)"
        }
    }
}
