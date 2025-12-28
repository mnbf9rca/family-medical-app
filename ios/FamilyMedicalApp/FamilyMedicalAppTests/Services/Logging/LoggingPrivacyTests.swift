import Foundation
import Testing
@testable import FamilyMedicalApp

@MainActor
struct LoggingPrivacyTests {
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

    @Test
    func faultWithPrivacyLevel() {
        let mockLogger = MockCategoryLogger(category: .auth)

        mockLogger.fault("Private fault message", privacy: .private)

        let entries = mockLogger.entriesWithLevel(.fault)
        #expect(entries.count == 1)
        #expect(entries.first?.privacy == .private)
    }

    @Test
    func faultWithPublicPrivacy() {
        let mockLogger = MockCategoryLogger(category: .auth)

        mockLogger.fault("Public fault message", privacy: .public)

        let entries = mockLogger.entriesWithLevel(.fault)
        #expect(entries.count == 1)
        #expect(entries.first?.privacy == .public)
    }

    @Test
    func faultWithHashedPrivacy() {
        let mockLogger = MockCategoryLogger(category: .auth)

        mockLogger.fault("Hashed fault message", privacy: .hashed)

        let entries = mockLogger.entriesWithLevel(.fault)
        #expect(entries.count == 1)
        #expect(entries.first?.privacy == .hashed)
    }

    @Test
    func faultWithSensitivePrivacy() {
        let mockLogger = MockCategoryLogger(category: .auth)

        mockLogger.fault("Sensitive fault message", privacy: .sensitive)

        let entries = mockLogger.entriesWithLevel(.fault)
        #expect(entries.count == 1)
        #expect(entries.first?.privacy == .sensitive)
    }
}
