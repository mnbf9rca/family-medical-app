import Foundation
import Testing
@testable import FamilyMedicalApp

struct FieldDisplayFormatterTests {
    // MARK: - Test Helpers

    func makeAttachment(
        id: UUID = UUID(),
        fileName: String = "test.jpg"
    ) throws -> FamilyMedicalApp.Attachment {
        try FamilyMedicalApp.Attachment(
            id: id,
            fileName: fileName,
            mimeType: "image/jpeg",
            contentHMAC: Data(repeating: 0x42, count: 32),
            encryptedSize: 1_024,
            thumbnailData: nil,
            uploadedAt: Date()
        )
    }

    // MARK: - format() - Nil Value Tests

    @Test
    func format_nilValue_returnsEmpty() {
        let result = FieldDisplayFormatter.format(nil)

        #expect(result == .empty)
    }

    // MARK: - format() - String Tests

    @Test
    func format_nonEmptyString_returnsText() {
        let result = FieldDisplayFormatter.format(.string("Hello World"))

        #expect(result == .text("Hello World"))
    }

    @Test
    func format_emptyString_returnsEmpty() {
        let result = FieldDisplayFormatter.format(.string(""))

        #expect(result == .empty)
    }

    @Test
    func format_stringWithWhitespace_returnsText() {
        let result = FieldDisplayFormatter.format(.string("  spaces  "))

        #expect(result == .text("  spaces  "))
    }

    // MARK: - format() - Int Tests

    @Test
    func format_positiveInt_returnsText() {
        let result = FieldDisplayFormatter.format(.int(42))

        #expect(result == .text("42"))
    }

    @Test
    func format_negativeInt_returnsText() {
        let result = FieldDisplayFormatter.format(.int(-17))

        #expect(result == .text("-17"))
    }

    @Test
    func format_zeroInt_returnsText() {
        let result = FieldDisplayFormatter.format(.int(0))

        #expect(result == .text("0"))
    }

    // MARK: - format() - Double Tests

    @Test
    func format_wholeDouble_returnsTextWithoutDecimals() {
        let result = FieldDisplayFormatter.format(.double(42.0))

        #expect(result == .text("42"))
    }

    @Test
    func format_doubleWithOneDecimal_returnsText() {
        let result = FieldDisplayFormatter.format(.double(98.6))

        #expect(result == .text("98.6"))
    }

    @Test
    func format_doubleWithTwoDecimals_returnsText() {
        let result = FieldDisplayFormatter.format(.double(3.14))

        #expect(result == .text("3.14"))
    }

    @Test
    func format_doubleWithTrailingZero_trimsTrailingZero() {
        let result = FieldDisplayFormatter.format(.double(5.10))

        #expect(result == .text("5.1"))
    }

    @Test
    func format_negativeDouble_returnsText() {
        let result = FieldDisplayFormatter.format(.double(-12.5))

        #expect(result == .text("-12.5"))
    }

    // MARK: - format() - Bool Tests

    @Test
    func format_boolTrue_returnsBoolDisplayYes() {
        let result = FieldDisplayFormatter.format(.bool(true))

        #expect(result == .boolDisplay(text: "Yes", isTrue: true))
    }

    @Test
    func format_boolFalse_returnsBoolDisplayNo() {
        let result = FieldDisplayFormatter.format(.bool(false))

        #expect(result == .boolDisplay(text: "No", isTrue: false))
    }

    // MARK: - format() - Date Tests

    @Test
    func format_date_returnsDate() {
        let testDate = Date(timeIntervalSince1970: 1_700_000_000) // Nov 14, 2023
        let result = FieldDisplayFormatter.format(.date(testDate))

        #expect(result == .date(testDate))
    }

    // MARK: - format() - AttachmentIds Tests

    @Test
    func format_emptyAttachmentIds_returnsEmpty() {
        let result = FieldDisplayFormatter.format(.attachmentIds([]))

        #expect(result == .empty)
    }

    @Test
    func format_attachmentIdsWithoutLoadedAttachments_returnsCount() {
        let ids = [UUID(), UUID(), UUID()]
        let result = FieldDisplayFormatter.format(.attachmentIds(ids))

        #expect(result == .attachmentCount(3))
    }

    @Test
    func format_attachmentIdsWithLoadedAttachments_returnsGrid() throws {
        let ids = [UUID(), UUID()]
        let attachments = try [makeAttachment(), makeAttachment()]

        let result = FieldDisplayFormatter.format(.attachmentIds(ids), attachments: attachments)

        #expect(result == .attachmentGrid(count: 2))
    }

    @Test
    func format_singleAttachmentId_returnsCountOne() {
        let ids = [UUID()]
        let result = FieldDisplayFormatter.format(.attachmentIds(ids))

        #expect(result == .attachmentCount(1))
    }

    // MARK: - format() - StringArray Tests

    @Test
    func format_emptyStringArray_returnsEmpty() {
        let result = FieldDisplayFormatter.format(.stringArray([]))

        #expect(result == .empty)
    }

    @Test
    func format_singleStringArray_returnsText() {
        let result = FieldDisplayFormatter.format(.stringArray(["one"]))

        #expect(result == .text("one"))
    }

    @Test
    func format_multipleStringArray_returnsCommaSeparatedText() {
        let result = FieldDisplayFormatter.format(.stringArray(["one", "two", "three"]))

        #expect(result == .text("one, two, three"))
    }

    // MARK: - formatDouble() Tests

    @Test
    func formatDouble_wholNumber_noDecimalPoint() {
        let result = FieldDisplayFormatter.formatDouble(100.0)

        #expect(result == "100")
    }

    @Test
    func formatDouble_oneDecimalPlace_preservesDecimal() {
        let result = FieldDisplayFormatter.formatDouble(98.6)

        #expect(result == "98.6")
    }

    @Test
    func formatDouble_twoDecimalPlaces_preservesBoth() {
        let result = FieldDisplayFormatter.formatDouble(3.14)

        #expect(result == "3.14")
    }

    @Test
    func formatDouble_moreDecimalPlaces_truncatesToTwo() {
        let result = FieldDisplayFormatter.formatDouble(3.14159)

        #expect(result == "3.14")
    }

    @Test
    func formatDouble_trailingZeros_trimsTrailingZeros() {
        let result = FieldDisplayFormatter.formatDouble(5.00)

        #expect(result == "5")
    }

    @Test
    func formatDouble_oneTrailingZero_trimsIt() {
        let result = FieldDisplayFormatter.formatDouble(5.10)

        #expect(result == "5.1")
    }

    // MARK: - attachmentCountText() Tests

    @Test
    func attachmentCountText_zero_returnsPlural() {
        let result = FieldDisplayFormatter.attachmentCountText(0)

        #expect(result == "0 attachments")
    }

    @Test
    func attachmentCountText_one_returnsSingular() {
        let result = FieldDisplayFormatter.attachmentCountText(1)

        #expect(result == "1 attachment")
    }

    @Test
    func attachmentCountText_multiple_returnsPlural() {
        let result = FieldDisplayFormatter.attachmentCountText(5)

        #expect(result == "5 attachments")
    }

    // MARK: - FormattedFieldValue Equatable Tests

    @Test
    func formattedFieldValue_textEquality() {
        #expect(FormattedFieldValue.text("a") == FormattedFieldValue.text("a"))
        #expect(FormattedFieldValue.text("a") != FormattedFieldValue.text("b"))
    }

    @Test
    func formattedFieldValue_boolDisplayEquality() {
        #expect(FormattedFieldValue.boolDisplay(text: "Yes", isTrue: true)
            == FormattedFieldValue.boolDisplay(text: "Yes", isTrue: true))
        #expect(FormattedFieldValue.boolDisplay(text: "Yes", isTrue: true)
            != FormattedFieldValue.boolDisplay(text: "No", isTrue: false))
    }

    @Test
    func formattedFieldValue_dateEquality() {
        let date = Date()
        #expect(FormattedFieldValue.date(date) == FormattedFieldValue.date(date))
    }

    @Test
    func formattedFieldValue_attachmentCountEquality() {
        #expect(FormattedFieldValue.attachmentCount(3) == FormattedFieldValue.attachmentCount(3))
        #expect(FormattedFieldValue.attachmentCount(3) != FormattedFieldValue.attachmentCount(5))
    }

    @Test
    func formattedFieldValue_attachmentGridEquality() {
        #expect(FormattedFieldValue.attachmentGrid(count: 2) == FormattedFieldValue.attachmentGrid(count: 2))
        #expect(FormattedFieldValue.attachmentGrid(count: 2) != FormattedFieldValue.attachmentGrid(count: 3))
    }

    @Test
    func formattedFieldValue_emptyEquality() {
        #expect(FormattedFieldValue.empty == FormattedFieldValue.empty)
    }

    @Test
    func formattedFieldValue_differentTypesNotEqual() {
        #expect(FormattedFieldValue.text("0") != FormattedFieldValue.attachmentCount(0))
        #expect(FormattedFieldValue.empty != FormattedFieldValue.text(""))
    }
}
