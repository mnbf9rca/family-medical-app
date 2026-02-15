import Foundation
import Testing
@testable import FamilyMedicalApp

@MainActor
struct LoggingConvenienceMethodsTests {
    // MARK: - Convenience Method Tests

    @Test
    func logOperationCreatesCorrectEntry() {
        let mockLogger = MockCategoryLogger(category: .auth)

        mockLogger.logOperation("login", state: "started")

        let entries = mockLogger.entriesContaining("login")
        #expect(entries.count == 1)
        #expect(entries.first?.message.contains("started") == true)
        #expect(entries.first?.privacy == .public)
        #expect(entries.first?.level == .info)
    }

    @Test
    func logUserIDIsPublic() {
        let mockLogger = MockCategoryLogger(category: .auth)
        let uuid = "550e8400-e29b-41d4-a716-446655440000"

        mockLogger.logUserID(uuid)

        let entries = mockLogger.entriesContaining(uuid)
        #expect(entries.count == 1)
        #expect(entries.first?.privacy == .public)
        #expect(entries.first?.level == .debug)
    }

    @Test
    func logRecordCountIsPublic() {
        let mockLogger = MockCategoryLogger(category: .storage)

        mockLogger.logRecordCount(42)

        let entries = mockLogger.entriesContaining("42")
        #expect(entries.count == 1)
        #expect(entries.first?.privacy == .public)
        #expect(entries.first?.level == .debug)
    }

    @Test
    func logTimestampIsPublic() {
        let mockLogger = MockCategoryLogger(category: .storage)
        let date = Date()

        mockLogger.logTimestamp(date)

        let entries = mockLogger.entriesContaining("timestamp")
        #expect(entries.count == 1)
        #expect(entries.first?.privacy == .public)
        #expect(entries.first?.level == .debug)
    }

    @Test
    func logTimestampUsesISO8601Format() {
        let mockLogger = MockCategoryLogger(category: .storage)
        let date = Date(timeIntervalSince1970: 1_640_000_000.123) // 2021-12-20T09:46:40.123Z

        mockLogger.logTimestamp(date)

        let entries = mockLogger.entriesContaining("timestamp")
        #expect(entries.count == 1)
        // Should contain ISO 8601 format with fractional seconds
        #expect(entries.first?.message.contains("T") == true) // ISO 8601 has 'T' separator
        #expect(entries.first?.message.contains("Z") == true) // ISO 8601 UTC indicator
    }

    @Test
    func logErrorRedactsDetails() {
        let mockLogger = MockCategoryLogger(category: .auth)
        let error = NSError(domain: "test", code: 42, userInfo: [NSLocalizedDescriptionKey: "Test error"])

        mockLogger.logError(error, context: "testFunction")

        let entries = mockLogger.entriesContaining("testFunction")
        #expect(entries.count == 1)
        #expect(entries.first?.privacy == .public) // Error details are now public
        #expect(entries.first?.level == .error)
    }
}
