import Foundation
import Testing
@testable import FamilyMedicalApp

/// Tests for FieldValueConverter
struct FieldValueConverterTests {
    // MARK: - String to Int

    @Test("String to Int converts valid integer string")
    func stringToIntValid() {
        let result = FieldValueConverter.convert(.string("42"), to: .int)
        #expect(result == .int(42))
    }

    @Test("String to Int converts negative integer string")
    func stringToIntNegative() {
        let result = FieldValueConverter.convert(.string("-123"), to: .int)
        #expect(result == .int(-123))
    }

    @Test("String to Int handles whitespace")
    func stringToIntWhitespace() {
        let result = FieldValueConverter.convert(.string("  99  "), to: .int)
        #expect(result == .int(99))
    }

    @Test("String to Int truncates decimal")
    func stringToIntTruncatesDecimal() {
        let result = FieldValueConverter.convert(.string("3.7"), to: .int)
        #expect(result == .int(3))
    }

    @Test("String to Int returns nil for invalid string")
    func stringToIntInvalid() {
        let result = FieldValueConverter.convert(.string("not a number"), to: .int)
        #expect(result == nil)
    }

    @Test("String to Int returns nil for empty string")
    func stringToIntEmpty() {
        let result = FieldValueConverter.convert(.string(""), to: .int)
        #expect(result == nil)
    }

    // MARK: - String to Double

    @Test("String to Double converts valid decimal string")
    func stringToDoubleValid() {
        let result = FieldValueConverter.convert(.string("3.14159"), to: .double)
        #expect(result == .double(3.14159))
    }

    @Test("String to Double converts integer string")
    func stringToDoubleInteger() {
        let result = FieldValueConverter.convert(.string("42"), to: .double)
        #expect(result == .double(42.0))
    }

    @Test("String to Double handles scientific notation")
    func stringToDoubleScientific() {
        let result = FieldValueConverter.convert(.string("1.5e2"), to: .double)
        #expect(result == .double(150.0))
    }

    @Test("String to Double returns nil for invalid string")
    func stringToDoubleInvalid() {
        let result = FieldValueConverter.convert(.string("not a number"), to: .double)
        #expect(result == nil)
    }

    // MARK: - Int to String

    @Test("Int to String converts positive integer")
    func intToStringPositive() {
        let result = FieldValueConverter.convert(.int(42), to: .string)
        #expect(result == .string("42"))
    }

    @Test("Int to String converts negative integer")
    func intToStringNegative() {
        let result = FieldValueConverter.convert(.int(-123), to: .string)
        #expect(result == .string("-123"))
    }

    @Test("Int to String converts zero")
    func intToStringZero() {
        let result = FieldValueConverter.convert(.int(0), to: .string)
        #expect(result == .string("0"))
    }

    // MARK: - Int to Double

    @Test("Int to Double converts correctly")
    func intToDouble() {
        let result = FieldValueConverter.convert(.int(42), to: .double)
        #expect(result == .double(42.0))
    }

    @Test("Int to Double converts negative")
    func intToDoubleNegative() {
        let result = FieldValueConverter.convert(.int(-100), to: .double)
        #expect(result == .double(-100.0))
    }

    // MARK: - Double to String

    @Test("Double to String converts without unnecessary decimals")
    func doubleToStringClean() {
        let result = FieldValueConverter.convert(.double(42.0), to: .string)
        #expect(result == .string("42"))
    }

    @Test("Double to String preserves decimals when needed")
    func doubleToStringWithDecimals() {
        let result = FieldValueConverter.convert(.double(3.14), to: .string)
        if case let .string(str) = result {
            #expect(str.starts(with: "3.14"))
        } else {
            Issue.record("Expected string result")
        }
    }

    // MARK: - Double to Int

    @Test("Double to Int truncates decimal")
    func doubleToIntTruncates() {
        let result = FieldValueConverter.convert(.double(3.9), to: .int)
        #expect(result == .int(3))
    }

    @Test("Double to Int handles negative")
    func doubleToIntNegative() {
        let result = FieldValueConverter.convert(.double(-3.9), to: .int)
        #expect(result == .int(-3))
    }

    @Test("Double to Int handles large values within range")
    func doubleToIntLargeValue() {
        let result = FieldValueConverter.convert(.double(1_000_000.5), to: .int)
        #expect(result == .int(1_000_000))
    }

    // MARK: - Same Type Returns Original

    @Test("String to String returns same value")
    func stringToStringSame() {
        let original = FieldValue.string("hello")
        let result = FieldValueConverter.convert(original, to: .string)
        #expect(result == original)
    }

    @Test("Int to Int returns same value")
    func intToIntSame() {
        let original = FieldValue.int(42)
        let result = FieldValueConverter.convert(original, to: .int)
        #expect(result == original)
    }

    @Test("Double to Double returns same value")
    func doubleToDoubleSame() {
        let original = FieldValue.double(3.14)
        let result = FieldValueConverter.convert(original, to: .double)
        #expect(result == original)
    }

    // MARK: - Unsupported Conversions

    @Test("Bool to String returns nil")
    func boolToStringUnsupported() {
        let result = FieldValueConverter.convert(.bool(true), to: .string)
        #expect(result == nil)
    }

    @Test("Date to Int returns nil")
    func dateToIntUnsupported() {
        let result = FieldValueConverter.convert(.date(Date()), to: .int)
        #expect(result == nil)
    }

    @Test("String to Bool returns nil")
    func stringToBoolUnsupported() {
        let result = FieldValueConverter.convert(.string("true"), to: .bool)
        #expect(result == nil)
    }

    @Test("AttachmentIds to String returns nil")
    func attachmentIdsToStringUnsupported() {
        let result = FieldValueConverter.convert(.attachmentIds([UUID()]), to: .string)
        #expect(result == nil)
    }

    // MARK: - isConversionSupported

    @Test("isConversionSupported returns true for supported types")
    func isConversionSupportedTrue() {
        #expect(FieldValueConverter.isConversionSupported(from: .string, to: .int))
        #expect(FieldValueConverter.isConversionSupported(from: .string, to: .double))
        #expect(FieldValueConverter.isConversionSupported(from: .int, to: .string))
        #expect(FieldValueConverter.isConversionSupported(from: .int, to: .double))
        #expect(FieldValueConverter.isConversionSupported(from: .double, to: .string))
        #expect(FieldValueConverter.isConversionSupported(from: .double, to: .int))
    }

    @Test("isConversionSupported returns false for unsupported types")
    func isConversionSupportedFalse() {
        #expect(!FieldValueConverter.isConversionSupported(from: .bool, to: .string))
        #expect(!FieldValueConverter.isConversionSupported(from: .date, to: .int))
        #expect(!FieldValueConverter.isConversionSupported(from: .string, to: .bool))
        #expect(!FieldValueConverter.isConversionSupported(from: .attachmentIds, to: .string))
    }

    // MARK: - Merge Operations

    @Test("Merge concatenates string values")
    func mergeConcatenate() {
        let values: [FieldValue?] = [.string("Hello"), .string("World")]
        let result = FieldValueConverter.merge(values, using: .concatenate(separator: " "))
        #expect(result == .string("Hello World"))
    }

    @Test("Merge concatenates with custom separator")
    func mergeConcatenateCustomSeparator() {
        let values: [FieldValue?] = [.string("A"), .string("B"), .string("C")]
        let result = FieldValueConverter.merge(values, using: .concatenate(separator: ", "))
        #expect(result == .string("A, B, C"))
    }

    @Test("Merge preferTarget returns last non-empty value (target is last in array)")
    func mergePreferTarget() {
        // In [source, target] array order, target is last
        let values: [FieldValue?] = [.string("Source"), .string("Target")]
        let result = FieldValueConverter.merge(values, using: .preferTarget)
        #expect(result == .string("Target"))
    }

    @Test("Merge preferTarget with nil target uses source")
    func mergePreferTargetWithNilTarget() {
        let values: [FieldValue?] = [.string("Source"), nil]
        let result = FieldValueConverter.merge(values, using: .preferTarget)
        #expect(result == .string("Source"))
    }

    @Test("Merge preferSource returns first non-empty value (source is first in array)")
    func mergePreferSource() {
        // In [source, target] array order, source is first
        let values: [FieldValue?] = [.string("Source"), .string("Target")]
        let result = FieldValueConverter.merge(values, using: .preferSource)
        #expect(result == .string("Source"))
    }

    @Test("Merge preferSource with nil source uses target")
    func mergePreferSourceWithNilSource() {
        let values: [FieldValue?] = [nil, .string("Target")]
        let result = FieldValueConverter.merge(values, using: .preferSource)
        #expect(result == .string("Target"))
    }

    @Test("Merge skips nil values")
    func mergeSkipsNil() {
        let values: [FieldValue?] = [.string("A"), nil, .string("B")]
        let result = FieldValueConverter.merge(values, using: .concatenate(separator: "-"))
        #expect(result == .string("A-B"))
    }

    @Test("Merge returns nil for all nil values")
    func mergeReturnsNilForAllNil() {
        let values: [FieldValue?] = [nil, nil, nil]
        let result = FieldValueConverter.merge(values, using: .preferTarget)
        #expect(result == nil)
    }

    @Test("Merge converts numbers to strings for concatenation")
    func mergeConvertsNumbers() {
        let values: [FieldValue?] = [.int(42), .double(3.14)]
        let result = FieldValueConverter.merge(values, using: .concatenate(separator: " "))
        if case let .string(str) = result {
            #expect(str.contains("42"))
            #expect(str.contains("3.14"))
        } else {
            Issue.record("Expected string result")
        }
    }

    @Test("Merge skips empty strings")
    func mergeSkipsEmptyStrings() {
        let values: [FieldValue?] = [.string(""), .string("A"), .string("")]
        let result = FieldValueConverter.merge(values, using: .concatenate(separator: "-"))
        #expect(result == .string("A"))
    }
}
