import Foundation
import Testing
@testable import FamilyMedicalApp

/// Unit tests for `Optional<String>.trimmedNonEmpty()`.
///
/// Backup decoders use this helper to normalise `nil` / `""` / whitespace-only
/// strings to `nil` before constructing model types that distinguish between
/// "empty" and "absent" values.
struct OptionalStringTrimmingTests {
    @Test
    func trimmedNonEmpty_nilInput_returnsNil() {
        let value: String? = nil
        #expect(value.trimmedNonEmpty() == nil)
    }

    @Test
    func trimmedNonEmpty_emptyString_returnsNil() {
        let value: String? = ""
        #expect(value.trimmedNonEmpty() == nil)
    }

    @Test
    func trimmedNonEmpty_whitespaceAndNewlinesOnly_returnsNil() {
        let value: String? = "  \n\t  \r\n "
        #expect(value.trimmedNonEmpty() == nil)
    }

    @Test
    func trimmedNonEmpty_surroundingWhitespace_returnsTrimmedValue() {
        let value: String? = "  hello world \n"
        #expect(value.trimmedNonEmpty() == "hello world")
    }

    @Test
    func trimmedNonEmpty_alreadyTrimmed_returnsUnchanged() {
        let value: String? = "clean"
        #expect(value.trimmedNonEmpty() == "clean")
    }
}
