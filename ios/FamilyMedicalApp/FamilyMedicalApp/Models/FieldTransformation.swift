import Foundation

/// Transformation operations for field migrations
///
/// Defines the types of transformations that can be applied to fields
/// when migrating records from one schema version to another.
///
/// **Supported transformations:**
/// - `remove`: Delete a field from all records
/// - `typeConvert`: Convert field values between string ↔ int ↔ double
/// - `merge`: Combine two fields into one (source merges into target)
enum FieldTransformation: Codable, Equatable, Hashable {
    /// Remove a field from all records
    ///
    /// - Parameter fieldId: The ID of the field to remove
    case remove(fieldId: String)

    /// Convert a field's type to a different type
    ///
    /// Only conversions between string, int, and double are supported.
    /// Other types (date, bool, attachmentIds, stringArray) cannot be converted.
    ///
    /// - Parameters:
    ///   - fieldId: The ID of the field to convert
    ///   - toType: The target field type
    case typeConvert(fieldId: String, toType: FieldType)

    /// Merge a source field into a target field
    ///
    /// The source field's value is combined with the target field's value
    /// using the merge strategy (concatenate, prefer source, prefer target).
    /// After merging, the source field is removed.
    ///
    /// - Parameters:
    ///   - fieldId: The source field to merge (will be removed after merge)
    ///   - into: The target field (will receive the merged value)
    case merge(fieldId: String, into: String)

    // MARK: - Computed Properties

    /// Returns the field IDs affected by this transformation
    var affectedFieldIds: [String] {
        switch self {
        case let .remove(fieldId):
            [fieldId]
        case let .typeConvert(fieldId, _):
            [fieldId]
        case let .merge(fieldId, into):
            [fieldId, into]
        }
    }

    /// Returns true if this is a type conversion transformation
    var isTypeConversion: Bool {
        if case .typeConvert = self {
            return true
        }
        return false
    }

    /// Returns true if this is a merge transformation
    var isMerge: Bool {
        if case .merge = self {
            return true
        }
        return false
    }
}

// MARK: - Validation

extension FieldTransformation {
    /// Validate that this transformation is valid
    ///
    /// - Throws: ModelError if the transformation is invalid
    func validate() throws {
        switch self {
        case let .remove(fieldId):
            guard !fieldId.isEmpty else {
                throw ModelError.validationFailed(
                    fieldName: "fieldId",
                    reason: "Field ID cannot be empty for remove transformation"
                )
            }

        case let .typeConvert(fieldId, toType):
            guard !fieldId.isEmpty else {
                throw ModelError.validationFailed(
                    fieldName: "fieldId",
                    reason: "Field ID cannot be empty for typeConvert transformation"
                )
            }
            // Only string, int, double conversions are supported
            guard toType == .string || toType == .int || toType == .double else {
                throw ModelError.validationFailed(
                    fieldName: "toType",
                    reason: "Type conversion to \(toType.displayName) is not supported. " +
                        "Only string, int, and double conversions are allowed."
                )
            }

        case let .merge(fieldId, into):
            guard !fieldId.isEmpty else {
                throw ModelError.validationFailed(
                    fieldName: "fieldId",
                    reason: "Source field ID cannot be empty for merge transformation"
                )
            }
            guard !into.isEmpty else {
                throw ModelError.validationFailed(
                    fieldName: "into",
                    reason: "Target field ID cannot be empty for merge transformation"
                )
            }
            guard fieldId != into else {
                throw ModelError.validationFailed(
                    fieldName: "fieldId",
                    reason: "Source and target fields must be different for merge transformation"
                )
            }
        }
    }
}
