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

    // MARK: - Mock Test Helpers

    @Test
    func mockLoggerCapturesEntries() {
        let mockLogger = MockCategoryLogger(category: .auth)

        mockLogger.info("Test message")

        #expect(mockLogger.capturedEntries.count == 1)
        #expect(mockLogger.capturedEntries.first?.message == "Test message")
    }

    @Test
    func mockLoggerCanFilterByMessage() {
        let mockLogger = MockCategoryLogger(category: .auth)

        mockLogger.info("First message")
        mockLogger.info("Second message")
        mockLogger.info("First again")

        let filtered = mockLogger.entriesContaining("First")
        #expect(filtered.count == 2)
    }

    @Test
    func mockLoggerCanFilterByPrivacy() {
        let mockLogger = MockCategoryLogger(category: .auth)

        mockLogger.info("Public message")
        mockLogger.info("Private message", privacy: .private)

        let privateEntries = mockLogger.entriesWithPrivacy(.private)
        #expect(privateEntries.count == 1)
    }

    @Test
    func mockLoggerCanFilterByLevel() {
        let mockLogger = MockCategoryLogger(category: .auth)

        mockLogger.debug("Debug")
        mockLogger.info("Info")
        mockLogger.error("Error")

        let debugEntries = mockLogger.entriesWithLevel(.debug)
        #expect(debugEntries.count == 1)
    }

    @Test
    func mockLoggerCanClear() {
        let mockLogger = MockCategoryLogger(category: .auth)

        mockLogger.info("Test")
        #expect(mockLogger.capturedEntries.count == 1)

        mockLogger.clear()
        #expect(mockLogger.capturedEntries.isEmpty)
    }

    // MARK: - Mock Logging Service Tests

    @Test
    func mockServiceCreatesLoggers() {
        let mockService = MockLoggingService()
        let logger = mockService.logger(category: .auth)

        #expect(logger is MockCategoryLogger)
    }

    @Test
    func mockServiceCachesLoggers() {
        let mockService = MockLoggingService()
        let logger1 = mockService.logger(category: .auth)
        let logger2 = mockService.logger(category: .auth)

        #expect(logger1 as AnyObject === logger2 as AnyObject)
    }

    @Test
    func mockServiceProvidesTypedAccess() {
        let mockService = MockLoggingService()
        let mockLogger = mockService.mockLogger(category: .auth)

        mockLogger.info("Test")
        #expect(mockLogger.capturedEntries.count == 1)
    }

    @Test
    func mockServiceCanClearAll() {
        let mockService = MockLoggingService()

        mockService.logger(category: .auth).info("Test 1")
        mockService.logger(category: .crypto).info("Test 2")

        mockService.clearAll()

        #expect(mockService.mockLogger(category: .auth).capturedEntries.isEmpty)
        #expect(mockService.mockLogger(category: .crypto).capturedEntries.isEmpty)
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

    // MARK: - Real CategoryLogger Tests

    @Test
    func realLoggerFaultWithPrivacy() {
        let service = LoggingService()
        let logger = service.logger(category: .auth)

        // Exercise the real implementation - just ensure it doesn't crash
        logger.fault("Test fault", privacy: .private)
        logger.fault("Test fault", privacy: .public)
        logger.fault("Test fault", privacy: .hashed)
        logger.fault("Test fault", privacy: .sensitive)
    }

    @Test
    func realLoggerTimestamp() {
        let service = LoggingService()
        let logger = service.logger(category: .storage)

        // Exercise the real implementation - just ensure it doesn't crash
        logger.logTimestamp(Date())
    }

    // MARK: - Real CategoryLogger Standard Log Levels

    @Test
    func realLoggerDebug() {
        let service = LoggingService()
        let logger = service.logger(category: .auth)

        // Exercise the real implementation - just ensure it doesn't crash
        logger.debug("Test debug message")
    }

    @Test
    func realLoggerInfo() {
        let service = LoggingService()
        let logger = service.logger(category: .crypto)

        // Exercise the real implementation - just ensure it doesn't crash
        logger.info("Test info message")
    }

    @Test
    func realLoggerNotice() {
        let service = LoggingService()
        let logger = service.logger(category: .storage)

        // Exercise the real implementation - just ensure it doesn't crash
        logger.notice("Test notice message")
    }

    @Test
    func realLoggerError() {
        let service = LoggingService()
        let logger = service.logger(category: .sync)

        // Exercise the real implementation - just ensure it doesn't crash
        logger.error("Test error message")
    }

    // MARK: - Real CategoryLogger Privacy-Aware Methods

    @Test
    func realLoggerDebugWithPrivacy() {
        let service = LoggingService()
        let logger = service.logger(category: .auth)

        // Exercise all privacy levels
        logger.debug("Public debug", privacy: .public)
        logger.debug("Private debug", privacy: .private)
        logger.debug("Sensitive debug", privacy: .sensitive)
        logger.debug("Hashed debug", privacy: .hashed)
    }

    @Test
    func realLoggerInfoWithPrivacy() {
        let service = LoggingService()
        let logger = service.logger(category: .crypto)

        // Exercise all privacy levels
        logger.info("Public info", privacy: .public)
        logger.info("Private info", privacy: .private)
        logger.info("Sensitive info", privacy: .sensitive)
        logger.info("Hashed info", privacy: .hashed)
    }

    @Test
    func realLoggerNoticeWithPrivacy() {
        let service = LoggingService()
        let logger = service.logger(category: .storage)

        // Exercise all privacy levels
        logger.notice("Public notice", privacy: .public)
        logger.notice("Private notice", privacy: .private)
        logger.notice("Sensitive notice", privacy: .sensitive)
        logger.notice("Hashed notice", privacy: .hashed)
    }

    @Test
    func realLoggerErrorWithPrivacy() {
        let service = LoggingService()
        let logger = service.logger(category: .sync)

        // Exercise all privacy levels
        logger.error("Public error", privacy: .public)
        logger.error("Private error", privacy: .private)
        logger.error("Sensitive error", privacy: .sensitive)
        logger.error("Hashed error", privacy: .hashed)
    }

    // MARK: - Real CategoryLogger Convenience Methods

    @Test
    func realLoggerLogOperation() {
        let service = LoggingService()
        let logger = service.logger(category: .auth)

        // Exercise the real implementation
        logger.logOperation("testOperation", state: "started")
        logger.logOperation("testOperation", state: "completed")
    }

    @Test
    func realLoggerLogUserID() {
        let service = LoggingService()
        let logger = service.logger(category: .storage)

        // Exercise the real implementation
        logger.logUserID("user-123")
    }

    @Test
    func realLoggerLogRecordCount() {
        let service = LoggingService()
        let logger = service.logger(category: .sync)

        // Exercise the real implementation
        logger.logRecordCount(42)
    }

    @Test
    func realLoggerLogError() {
        let service = LoggingService()
        let logger = service.logger(category: .crypto)

        // Exercise the real implementation
        let testError = NSError(domain: "TestDomain", code: 123, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        logger.logError(testError, context: "Testing error logging")
    }
}
