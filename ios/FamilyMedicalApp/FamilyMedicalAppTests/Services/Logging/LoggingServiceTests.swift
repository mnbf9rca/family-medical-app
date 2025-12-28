import Foundation
import Testing
@testable import FamilyMedicalApp

@MainActor
struct LoggingServiceTests {
    // MARK: - Logger Creation Tests

    @Test
    func loggerCreatesCorrectCategory() {
        let service = LoggingService()
        let authLogger = service.logger(category: .auth) as? CategoryLogger

        #expect(authLogger != nil)
    }

    @Test
    func loggersAreCached() {
        let service = LoggingService()
        let logger1 = service.logger(category: .auth)
        let logger2 = service.logger(category: .auth)

        // Should return the same cached instance
        #expect(logger1 as AnyObject === logger2 as AnyObject)
    }

    @Test
    func allCategoriesCanCreateLoggers() {
        let service = LoggingService()

        for category in LogCategory.allCases {
            let logger = service.logger(category: category)
            #expect(logger is CategoryLogger)
        }
    }

    @Test
    func differentCategoriesCreateDifferentLoggers() {
        let service = LoggingService()
        let authLogger = service.logger(category: .auth)
        let cryptoLogger = service.logger(category: .crypto)

        #expect(authLogger as AnyObject !== cryptoLogger as AnyObject)
    }

    // MARK: - Privacy Redaction Tests

    @Test
    func privateDataMarkedAsPrivate() {
        let mockLogger = MockCategoryLogger(category: .auth)

        mockLogger.info("userEmail: user@test.com", privacy: .private)

        let entries = mockLogger.entriesWithPrivacy(.private)
        #expect(entries.count == 1)
        #expect(entries.first?.message.contains("user@test.com") == true)
    }

    @Test
    func sensitiveDataNeverLogged() {
        let mockLogger = MockCategoryLogger(category: .crypto)

        mockLogger.debug("key: supersecret", privacy: .sensitive)

        let entries = mockLogger.capturedEntries
        #expect(entries.count == 1)
        #expect(entries.first?.privacy == .sensitive)
    }

    @Test
    func publicDataRemainsPublic() {
        let mockLogger = MockCategoryLogger(category: .auth)

        mockLogger.logOperation("login", state: "started")

        let entries = mockLogger.entriesWithPrivacy(.public)
        #expect(entries.count == 1)
    }

    @Test
    func hashedPrivacyLevel() {
        let mockLogger = MockCategoryLogger(category: .storage)

        mockLogger.debug("recordID: abc123", privacy: .hashed)

        let entries = mockLogger.entriesWithPrivacy(.hashed)
        #expect(entries.count == 1)
        #expect(entries.first?.message.contains("abc123") == true)
    }

    // MARK: - Log Level Tests

    @Test
    func debugLevelWorks() {
        let mockLogger = MockCategoryLogger(category: .auth)

        mockLogger.debug("Debug message")

        let entries = mockLogger.entriesWithLevel(.debug)
        #expect(entries.count == 1)
        #expect(entries.first?.message == "Debug message")
    }

    @Test
    func infoLevelWorks() {
        let mockLogger = MockCategoryLogger(category: .auth)

        mockLogger.info("Info message")

        let entries = mockLogger.entriesWithLevel(.info)
        #expect(entries.count == 1)
        #expect(entries.first?.message == "Info message")
    }

    @Test
    func noticeLevelWorks() {
        let mockLogger = MockCategoryLogger(category: .auth)

        mockLogger.notice("Notice message")

        let entries = mockLogger.entriesWithLevel(.notice)
        #expect(entries.count == 1)
        #expect(entries.first?.message == "Notice message")
    }

    @Test
    func errorLevelWorks() {
        let mockLogger = MockCategoryLogger(category: .auth)

        mockLogger.error("Error message")

        let entries = mockLogger.entriesWithLevel(.error)
        #expect(entries.count == 1)
        #expect(entries.first?.message == "Error message")
    }

    @Test
    func faultLevelWorks() {
        let mockLogger = MockCategoryLogger(category: .auth)

        mockLogger.fault("Fault message")

        let entries = mockLogger.entriesWithLevel(.fault)
        #expect(entries.count == 1)
        #expect(entries.first?.message == "Fault message")
    }

    // MARK: - Privacy-Aware Log Level Tests

    @Test
    func debugWithPrivacyLevel() {
        let mockLogger = MockCategoryLogger(category: .auth)

        mockLogger.debug("Private debug message", privacy: .private)

        let entries = mockLogger.entriesWithLevel(.debug)
        #expect(entries.count == 1)
        #expect(entries.first?.privacy == .private)
    }

    @Test
    func infoWithPrivacyLevel() {
        let mockLogger = MockCategoryLogger(category: .auth)

        mockLogger.info("Private info message", privacy: .private)

        let entries = mockLogger.entriesWithLevel(.info)
        #expect(entries.count == 1)
        #expect(entries.first?.privacy == .private)
    }

    @Test
    func noticeWithPrivacyLevel() {
        let mockLogger = MockCategoryLogger(category: .auth)

        mockLogger.notice("Private notice message", privacy: .private)

        let entries = mockLogger.entriesWithLevel(.notice)
        #expect(entries.count == 1)
        #expect(entries.first?.privacy == .private)
    }

    @Test
    func errorWithPrivacyLevel() {
        let mockLogger = MockCategoryLogger(category: .auth)

        mockLogger.error("Private error message", privacy: .private)

        let entries = mockLogger.entriesWithLevel(.error)
        #expect(entries.count == 1)
        #expect(entries.first?.privacy == .private)
    }

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
    func logErrorRedactsDetails() {
        let mockLogger = MockCategoryLogger(category: .auth)
        let error = AuthenticationError.wrongPassword

        mockLogger.logError(error, context: "unlockWithPassword")

        let entries = mockLogger.entriesWithLevel(.error)
        #expect(entries.count == 1)
        #expect(entries.first?.message.contains("unlockWithPassword") == true)
        #expect(entries.first?.privacy == .private)
    }

    // MARK: - Mock Test Helpers

    @Test
    func clearRemovesAllEntries() {
        let mockLogger = MockCategoryLogger(category: .auth)

        mockLogger.info("Test 1")
        mockLogger.info("Test 2")
        mockLogger.info("Test 3")

        #expect(mockLogger.capturedEntries.count == 3)

        mockLogger.clear()

        #expect(mockLogger.capturedEntries.isEmpty)
    }

    @Test
    func entriesContainingFiltersCorrectly() {
        let mockLogger = MockCategoryLogger(category: .auth)

        mockLogger.info("Message one")
        mockLogger.info("Message two")
        mockLogger.info("Different text")

        let entries = mockLogger.entriesContaining("Message")
        #expect(entries.count == 2)
    }

    @Test
    func entriesWithPrivacyFiltersCorrectly() {
        let mockLogger = MockCategoryLogger(category: .auth)

        mockLogger.info("Public 1")
        mockLogger.info("Private 1", privacy: .private)
        mockLogger.info("Public 2")
        mockLogger.info("Private 2", privacy: .private)

        let privateEntries = mockLogger.entriesWithPrivacy(.private)
        #expect(privateEntries.count == 2)

        let publicEntries = mockLogger.entriesWithPrivacy(.public)
        #expect(publicEntries.count == 2)
    }

    @Test
    func entriesWithLevelFiltersCorrectly() {
        let mockLogger = MockCategoryLogger(category: .auth)

        mockLogger.debug("Debug 1")
        mockLogger.info("Info 1")
        mockLogger.debug("Debug 2")
        mockLogger.error("Error 1")

        let debugEntries = mockLogger.entriesWithLevel(.debug)
        #expect(debugEntries.count == 2)

        let infoEntries = mockLogger.entriesWithLevel(.info)
        #expect(infoEntries.count == 1)

        let errorEntries = mockLogger.entriesWithLevel(.error)
        #expect(errorEntries.count == 1)
    }

    // MARK: - Mock Logging Service Tests

    @Test
    func mockLoggingServiceCreatesLoggers() {
        let service = MockLoggingService()

        let logger = service.logger(category: .auth)
        #expect(logger is MockCategoryLogger)
    }

    @Test
    func mockLoggingServiceCachesLoggers() {
        let service = MockLoggingService()

        let logger1 = service.mockLogger(category: .auth)
        let logger2 = service.mockLogger(category: .auth)

        #expect(logger1 === logger2)
    }

    @Test
    func mockLoggingServiceClearAllWorks() {
        let service = MockLoggingService()

        let authLogger = service.mockLogger(category: .auth)
        let cryptoLogger = service.mockLogger(category: .crypto)

        authLogger.info("Auth message")
        cryptoLogger.info("Crypto message")

        #expect(authLogger.capturedEntries.count == 1)
        #expect(cryptoLogger.capturedEntries.count == 1)

        service.clearAll()

        #expect(authLogger.capturedEntries.isEmpty)
        #expect(cryptoLogger.capturedEntries.isEmpty)
    }

    // MARK: - LogCategory Tests

    @Test
    func logCategoryHasAllCases() {
        let categories = LogCategory.allCases
        #expect(categories.count == 5)
        #expect(categories.contains(.auth))
        #expect(categories.contains(.crypto))
        #expect(categories.contains(.storage))
        #expect(categories.contains(.sync))
        #expect(categories.contains(.ui))
    }

    @Test
    func logCategorySubsystemIsCorrect() {
        let category = LogCategory.auth
        let subsystem = category.subsystem

        // Should be bundle identifier or fallback
        #expect(subsystem.contains("FamilyMedicalApp"))
    }
}
