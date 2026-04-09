import Foundation
import Testing
@testable import FamilyMedicalApp

/// DoS-protection tests for BackupSchemaValidator: nesting depth, array size, and edge cases.
/// Split from BackupSchemaValidatorTests to keep individual suite bodies under the 300-line limit.
@Suite("BackupSchemaValidator DoS Protection Tests")
struct BackupSchemaValidatorDoSTests {
    // MARK: - DoS Limits

    @Test("Exceeding max nesting depth fails validation")
    func exceedingMaxNestingDepthFailsValidation() {
        let validator = BackupSchemaValidator.forTesting(maxNestingDepth: 5)

        // Create deeply nested JSON (deeper than 5 levels)
        let deeplyNested = Data("""
        {"a":{"b":{"c":{"d":{"e":{"f":{"g":"too deep"}}}}}}}
        """.utf8)

        let result = validator.validate(jsonData: deeplyNested)
        #expect(!result.isValid)
        #expect(result.errors.contains {
            if case .nestingDepthExceeded = $0 { true } else { false }
        })
    }

    @Test("Exceeding max array size fails validation")
    func exceedingMaxArraySizeFailsValidation() throws {
        let validator = BackupSchemaValidator.forTesting(maxArraySize: 10)

        // Create JSON with array larger than 10 items
        let largeArray = Array(repeating: "item", count: 20)
        let json = try JSONSerialization.data(withJSONObject: ["items": largeArray])

        let result = validator.validate(jsonData: json)
        #expect(!result.isValid)
        #expect(result.errors.contains {
            if case .arraySizeExceeded = $0 { true } else { false }
        })
    }

    // MARK: - Edge Cases for DoS Limits

    @Test("Empty arrays pass DoS validation")
    func emptyArraysPassDoSValidation() {
        let validator = BackupSchemaValidator.forTesting(maxArraySize: 10)
        let json = Data("""
        {"items": [], "nested": {"more": []}}
        """.utf8)

        let result = validator.validate(jsonData: json)
        // Will fail schema validation but should pass DoS checks
        #expect(!result.errors.contains {
            if case .arraySizeExceeded = $0 { true } else { false }
        })
    }

    @Test("Empty dictionaries pass DoS validation")
    func emptyDictionariesPassDoSValidation() {
        let validator = BackupSchemaValidator.forTesting(maxNestingDepth: 3)
        let json = Data("""
        {"a": {}, "b": {"c": {}}}
        """.utf8)

        let result = validator.validate(jsonData: json)
        // Will fail schema validation but should pass DoS checks
        #expect(!result.errors.contains {
            if case .nestingDepthExceeded = $0 { true } else { false }
        })
    }

    @Test("Primitive root value passes depth check")
    func primitiveRootValuePassesDepthCheck() {
        let validator = BackupSchemaValidator.forTesting(maxNestingDepth: 1)
        let json = Data("\"just a string\"".utf8)

        let result = validator.validate(jsonData: json)
        // Will fail schema validation but should pass DoS checks
        #expect(!result.errors.contains {
            if case .nestingDepthExceeded = $0 { true } else { false }
        })
    }

    @Test("Deeply nested arrays trigger depth limit")
    func deeplyNestedArraysTriggerDepthLimit() {
        let validator = BackupSchemaValidator.forTesting(maxNestingDepth: 3)
        let json = Data("""
        [[[[["too deep"]]]]]
        """.utf8)

        let result = validator.validate(jsonData: json)
        #expect(!result.isValid)
        #expect(result.errors.contains {
            if case .nestingDepthExceeded = $0 { true } else { false }
        })
    }

    @Test("Nested array sizes are checked")
    func nestedArraySizesAreChecked() {
        let validator = BackupSchemaValidator.forTesting(maxArraySize: 5)
        let json = Data("""
        {"outer": [{"inner": [1, 2, 3, 4, 5, 6, 7]}]}
        """.utf8)

        let result = validator.validate(jsonData: json)
        #expect(!result.isValid)
        #expect(result.errors.contains {
            if case .arraySizeExceeded = $0 { true } else { false }
        })
    }

    @Test("Within limits passes DoS checks")
    func withinLimitsPassesDoSChecks() {
        let validator = BackupSchemaValidator.forTesting(maxNestingDepth: 10, maxArraySize: 100)
        let json = Data("""
        {"a": {"b": {"c": [1, 2, 3]}}}
        """.utf8)

        let result = validator.validate(jsonData: json)
        // Will fail schema validation but should pass DoS checks
        #expect(!result.errors.contains {
            if case .nestingDepthExceeded = $0 { true } else { false }
        })
        #expect(!result.errors.contains {
            if case .arraySizeExceeded = $0 { true } else { false }
        })
    }

    // MARK: - Associated Value Tests

    @Test("Nesting depth error carries actual and max values")
    func nestingDepthErrorCarriesValues() {
        let validator = BackupSchemaValidator.forTesting(maxNestingDepth: 5)
        let deeplyNested = Data("""
        {"a":{"b":{"c":{"d":{"e":{"f":{"g":"too deep"}}}}}}}
        """.utf8)

        let result = validator.validate(jsonData: deeplyNested)
        #expect(!result.isValid)
        let hasTypedError = result.errors.contains {
            if case let .nestingDepthExceeded(actual, max) = $0 {
                return actual == 6 && max == 5
            }
            return false
        }
        #expect(hasTypedError)
    }

    @Test("Array size error carries actual and max values")
    func arraySizeErrorCarriesValues() throws {
        let validator = BackupSchemaValidator.forTesting(maxArraySize: 10)
        let largeArray = Array(repeating: "item", count: 20)
        let json = try JSONSerialization.data(withJSONObject: ["items": largeArray])

        let result = validator.validate(jsonData: json)
        #expect(!result.isValid)
        let hasTypedError = result.errors.contains {
            if case let .arraySizeExceeded(actual, max) = $0 {
                return actual == 20 && max == 10
            }
            return false
        }
        #expect(hasTypedError)
    }
}
