import Foundation

/// Converts field values between supported types
///
/// Only conversions between the core 3 types (string, int, double) are supported.
/// Other types (date, bool, attachmentIds, stringArray) cannot be converted.
///
/// **Supported conversions:**
/// - string ↔ int: Parse/stringify
/// - string ↔ double: Parse/stringify
/// - int ↔ double: Cast (truncate when converting to int)
enum FieldValueConverter {
    /// Convert a field value to a different type
    ///
    /// - Parameters:
    ///   - value: The value to convert
    ///   - targetType: The target type
    /// - Returns: The converted value, or nil if conversion failed or is not supported
    static func convert(_ value: FieldValue, to targetType: FieldType) -> FieldValue? {
        switch (value, targetType) {
        // Same type - no conversion needed
        case (.double, .double), (.int, .int), (.string, .string):
            value

        // String conversions
        case let (.string(str), .int):
            convertStringToInt(str)

        case let (.string(str), .double):
            convertStringToDouble(str)

        // Int conversions
        case let (.int(intValue), .string):
            .string(String(intValue))

        case let (.int(intValue), .double):
            .double(Double(intValue))

        // Double conversions
        case let (.double(doubleValue), .string):
            .string(formatDouble(doubleValue))

        case let (.double(doubleValue), .int):
            convertDoubleToInt(doubleValue)

        // Unsupported conversions
        default:
            nil
        }
    }

    /// Check if a conversion is supported
    ///
    /// - Parameters:
    ///   - fromType: The source type
    ///   - toType: The target type
    /// - Returns: True if the conversion is supported
    static func isConversionSupported(from fromType: FieldType, to toType: FieldType) -> Bool {
        let supportedTypes: Set<FieldType> = [.string, .int, .double]
        return supportedTypes.contains(fromType) && supportedTypes.contains(toType)
    }

    // MARK: - Private Helpers

    private static func convertStringToInt(_ str: String) -> FieldValue? {
        let trimmed = str.trimmingCharacters(in: .whitespaces)

        // Try direct integer parsing first
        if let intValue = Int(trimmed) {
            return .int(intValue)
        }

        // Try parsing as double and truncating
        if let doubleValue = Double(trimmed) {
            return .int(Int(doubleValue))
        }

        return nil
    }

    private static func convertStringToDouble(_ str: String) -> FieldValue? {
        let trimmed = str.trimmingCharacters(in: .whitespaces)

        if let doubleValue = Double(trimmed) {
            return .double(doubleValue)
        }

        return nil
    }

    private static func convertDoubleToInt(_ doubleValue: Double) -> FieldValue? {
        // Check for reasonable bounds to avoid overflow
        guard doubleValue >= Double(Int.min), doubleValue <= Double(Int.max) else {
            return nil
        }
        return .int(Int(doubleValue))
    }

    private static func formatDouble(_ value: Double) -> String {
        // Use a clean format that removes unnecessary trailing zeros
        // but preserves precision when needed
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            String(format: "%.0f", value)
        } else {
            // Remove trailing zeros
            String(value)
        }
    }
}

// MARK: - Merge Operations

extension FieldValueConverter {
    /// Merge multiple field values into one using the specified strategy
    ///
    /// - Parameters:
    ///   - values: The values to merge (in order)
    ///   - strategy: How to merge the values
    /// - Returns: The merged value, or nil if all values were nil/empty
    static func merge(_ values: [FieldValue?], using strategy: MergeStrategy) -> FieldValue? {
        let nonNilValues = values.compactMap(\.self)

        guard !nonNilValues.isEmpty else {
            return nil
        }

        switch strategy {
        case let .concatenate(separator):
            return concatenateValues(nonNilValues, separator: separator)
        case .preferTarget:
            return findFirstNonEmpty(nonNilValues)
        case .preferSource:
            return findLastNonEmpty(nonNilValues)
        }
    }

    private static func concatenateValues(_ values: [FieldValue], separator: String) -> FieldValue? {
        let strings = values.compactMap { valueToString($0) }.filter { !$0.isEmpty }
        guard !strings.isEmpty else { return nil }
        return .string(strings.joined(separator: separator))
    }

    private static func findFirstNonEmpty(_ values: [FieldValue]) -> FieldValue? {
        values.first { !isEmptyValue($0) }
    }

    private static func findLastNonEmpty(_ values: [FieldValue]) -> FieldValue? {
        values.last { !isEmptyValue($0) }
    }

    private static func valueToString(_ value: FieldValue) -> String? {
        switch value {
        case let .string(str):
            str
        case let .int(intValue):
            String(intValue)
        case let .double(doubleValue):
            formatDouble(doubleValue)
        case let .bool(boolValue):
            boolValue ? "true" : "false"
        case let .date(dateValue):
            ISO8601DateFormatter().string(from: dateValue)
        case let .stringArray(arr):
            arr.joined(separator: ", ")
        case .attachmentIds:
            nil // Can't convert attachments to string
        }
    }

    private static func isEmptyValue(_ value: FieldValue) -> Bool {
        switch value {
        case let .string(str):
            str.isEmpty
        case let .stringArray(arr):
            arr.isEmpty
        case let .attachmentIds(ids):
            ids.isEmpty
        default:
            false // Numbers, bools, dates are never "empty"
        }
    }
}
