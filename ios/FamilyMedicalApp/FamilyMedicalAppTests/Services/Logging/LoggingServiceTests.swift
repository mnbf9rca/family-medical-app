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
}
