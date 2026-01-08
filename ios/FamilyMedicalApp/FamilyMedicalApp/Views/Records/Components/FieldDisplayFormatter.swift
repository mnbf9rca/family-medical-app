import Foundation

/// Formatted output types for field values
///
/// This enum extracts the formatting logic from FieldDisplayView into a testable component.
enum FormattedFieldValue: Equatable {
    /// Plain text value
    case text(String)

    /// Boolean with display text and state
    case boolDisplay(text: String, isTrue: Bool)

    /// Date value for formatting
    case date(Date)

    /// Attachment count when attachments aren't loaded
    case attachmentCount(Int)

    /// Attachments ready for grid display
    case attachmentGrid(count: Int)

    /// Empty/nil value
    case empty
}

/// Formats FieldValue for display
///
/// Extracts formatting logic from FieldDisplayView so it can be unit tested.
enum FieldDisplayFormatter {
    /// Format a field value for display
    ///
    /// - Parameters:
    ///   - value: The field value to format
    ///   - attachments: Pre-loaded attachments (for attachmentIds fields)
    /// - Returns: Formatted value ready for display
    static func format(_ value: FieldValue?, attachments: [Attachment] = []) -> FormattedFieldValue {
        guard let value else { return .empty }

        switch value {
        case let .string(str):
            return str.isEmpty ? .empty : .text(str)

        case let .int(num):
            return .text("\(num)")

        case let .double(num):
            return .text(formatDouble(num))

        case let .bool(flag):
            return .boolDisplay(text: flag ? "Yes" : "No", isTrue: flag)

        case let .date(date):
            return .date(date)

        case let .attachmentIds(ids):
            if ids.isEmpty {
                return .empty
            } else if !attachments.isEmpty {
                return .attachmentGrid(count: attachments.count)
            } else {
                return .attachmentCount(ids.count)
            }

        case let .stringArray(array):
            if array.isEmpty {
                return .empty
            }
            return .text(array.joined(separator: ", "))
        }
    }

    /// Format a double with appropriate precision
    ///
    /// - Parameter value: The double to format
    /// - Returns: Formatted string
    static func formatDouble(_ value: Double) -> String {
        // Use up to 2 decimal places, trimming trailing zeros
        let formatted = String(format: "%.2f", value)
        // Remove trailing zeros after decimal point
        if formatted.contains(".") {
            var result = formatted
            while result.hasSuffix("0") {
                result.removeLast()
            }
            if result.hasSuffix(".") {
                result.removeLast()
            }
            return result
        }
        return formatted
    }

    /// Format attachment count text
    ///
    /// - Parameter count: Number of attachments
    /// - Returns: Formatted count string (e.g., "3 attachments")
    static func attachmentCountText(_ count: Int) -> String {
        "\(count) attachment\(count == 1 ? "" : "s")"
    }
}
