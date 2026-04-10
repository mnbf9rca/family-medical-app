import Foundation
import Testing
@testable import FamilyMedicalApp

@Suite("DocumentReferenceRecord title length limit")
struct DocumentReferenceRecordTitleLengthTests {
    // MARK: - normalizedTitle helper

    @Test
    func normalizedTitle_shortInput_returnsUnchanged() {
        let input = "Lab Results 2026-01-15.pdf"
        let result = DocumentReferenceRecord.normalizedTitle(input)
        #expect(result == input)
    }

    @Test
    func normalizedTitle_exactlyMaxLength_returnsUnchanged() {
        let input = String(repeating: "a", count: DocumentReferenceRecord.titleMaxLength)
        let result = DocumentReferenceRecord.normalizedTitle(input)
        #expect(result.count == DocumentReferenceRecord.titleMaxLength)
        #expect(result == input)
    }

    @Test
    func normalizedTitle_oneOverMaxLength_truncatesToMax() {
        let input = String(repeating: "a", count: DocumentReferenceRecord.titleMaxLength + 1)
        let result = DocumentReferenceRecord.normalizedTitle(input)
        #expect(result.count == DocumentReferenceRecord.titleMaxLength)
    }

    @Test
    func normalizedTitle_wildlyOverMax_truncatesToMax() {
        let input = String(repeating: "x", count: 10_000)
        let result = DocumentReferenceRecord.normalizedTitle(input)
        #expect(result.count == DocumentReferenceRecord.titleMaxLength)
    }

    @Test
    func normalizedTitle_empty_returnsEmpty() {
        #expect(DocumentReferenceRecord.normalizedTitle("").isEmpty)
    }

    // MARK: - init(title:) normalizes

    @Test
    func init_titleOverMaxLength_truncatesToMax() {
        let overLong = String(repeating: "b", count: DocumentReferenceRecord.titleMaxLength + 100)
        let record = DocumentReferenceRecord(
            title: overLong,
            mimeType: "application/pdf",
            fileSize: 1_024,
            contentHMAC: Data(repeating: 0x01, count: 32)
        )
        #expect(record.title.count == DocumentReferenceRecord.titleMaxLength)
    }

    @Test
    func init_titleUnderMaxLength_keepsTitleUnchanged() {
        let record = DocumentReferenceRecord(
            title: "short.pdf",
            mimeType: "application/pdf",
            fileSize: 1_024,
            contentHMAC: Data(repeating: 0x01, count: 32)
        )
        #expect(record.title == "short.pdf")
    }

    // MARK: - init(from: Decoder) normalizes

    @Test
    func decode_titleOverMaxLength_truncatesToMax() throws {
        let overLong = String(repeating: "c", count: DocumentReferenceRecord.titleMaxLength + 50)
        let json = """
        {
          "title": "\(overLong)",
          "mimeType": "application/pdf",
          "fileSize": 1024,
          "contentHMAC": "\(Data(repeating: 0x01, count: 32).base64EncodedString())",
          "tags": []
        }
        """
        let decoded = try JSONDecoder().decode(
            DocumentReferenceRecord.self,
            from: Data(json.utf8)
        )
        #expect(decoded.title.count == DocumentReferenceRecord.titleMaxLength)
    }

    @Test
    func decode_titleUnderMaxLength_keepsTitleUnchanged() throws {
        let json = """
        {
          "title": "normal.pdf",
          "mimeType": "application/pdf",
          "fileSize": 1024,
          "contentHMAC": "\(Data(repeating: 0x01, count: 32).base64EncodedString())",
          "tags": []
        }
        """
        let decoded = try JSONDecoder().decode(
            DocumentReferenceRecord.self,
            from: Data(json.utf8)
        )
        #expect(decoded.title == "normal.pdf")
    }
}
