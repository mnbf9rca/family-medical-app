import Foundation
import Testing
@testable import FamilyMedicalApp

@MainActor
struct TracingCategoryLoggerTests {
    @Test
    func entryLogsMethodName() {
        let mock = MockCategoryLogger(category: .storage)
        let tracer = TracingCategoryLogger(wrapping: mock)

        tracer.entry("loadSchemas")

        let entries = mock.entriesWithLevel(.debug)
        #expect(entries.count == 1)
        #expect(entries.first?.message.contains("→ loadSchemas") == true)
    }

    @Test
    func entryLogsOptionalDetails() {
        let mock = MockCategoryLogger(category: .storage)
        let tracer = TracingCategoryLogger(wrapping: mock)

        tracer.entry("loadSchemas", "personId=ABC")

        let entries = mock.entriesWithLevel(.debug)
        #expect(entries.count == 1)
        #expect(entries.first?.message.contains("personId=ABC") == true)
    }

    @Test
    func exitLogsMethodAndDuration() {
        let mock = MockCategoryLogger(category: .storage)
        let tracer = TracingCategoryLogger(wrapping: mock)

        tracer.exit("loadSchemas", duration: .milliseconds(42))

        let entries = mock.entriesWithLevel(.debug)
        #expect(entries.count == 1)
        #expect(entries.first?.message.contains("← loadSchemas") == true)
        #expect(entries.first?.message.contains("42") == true)
    }

    @Test
    func exitWithErrorLogsErrorDetails() {
        let mock = MockCategoryLogger(category: .storage)
        let tracer = TracingCategoryLogger(wrapping: mock)

        let error = NSError(domain: "test", code: 42, userInfo: [
            NSLocalizedDescriptionKey: "Schema decrypt failed"
        ])
        tracer.exitWithError("loadSchemas", error: error, duration: .milliseconds(12))

        let entries = mock.entriesWithLevel(.error)
        #expect(entries.count == 1)
        #expect(entries.first?.message.contains("✗ loadSchemas") == true)
        #expect(entries.first?.message.contains("12") == true)
        #expect(entries.first?.message.contains("Schema decrypt failed") == true)
    }

    @Test
    func delegatesStandardLogMethods() {
        let mock = MockCategoryLogger(category: .auth)
        let tracer = TracingCategoryLogger(wrapping: mock)

        tracer.debug("debug msg")
        tracer.info("info msg")
        tracer.notice("notice msg")
        tracer.error("error msg")
        tracer.fault("fault msg")

        #expect(mock.entriesWithLevel(.debug).count == 1)
        #expect(mock.entriesWithLevel(.info).count == 1)
        #expect(mock.entriesWithLevel(.notice).count == 1)
        #expect(mock.entriesWithLevel(.error).count == 1)
        #expect(mock.entriesWithLevel(.fault).count == 1)
    }

    @Test
    func delegatesPrivacyAwareMethods() {
        let mock = MockCategoryLogger(category: .auth)
        let tracer = TracingCategoryLogger(wrapping: mock)

        tracer.debug("msg", privacy: .hashed)
        tracer.info("msg", privacy: .sensitive)
        tracer.notice("msg", privacy: .public)
        tracer.error("msg", privacy: .hashed)
        tracer.fault("msg", privacy: .sensitive)

        #expect(mock.entriesWithPrivacy(.hashed).count == 2)
        #expect(mock.entriesWithPrivacy(.sensitive).count == 2)
        #expect(mock.entriesWithPrivacy(.public).count == 1)
    }

    @Test
    func delegatesConvenienceMethods() {
        let mock = MockCategoryLogger(category: .storage)
        let tracer = TracingCategoryLogger(wrapping: mock)

        tracer.logOperation("save", state: "started")
        tracer.logUserID("user-123")
        tracer.logRecordCount(5)
        tracer.logTimestamp(Date())
        tracer.logError(NSError(domain: "test", code: 1), context: "TestContext")

        #expect(mock.capturedEntries.count == 5)
    }

    @Test
    func delegatesLogSensitiveError() {
        let mock = MockCategoryLogger(category: .auth)
        let tracer = TracingCategoryLogger(wrapping: mock)

        let error = NSError(domain: "test", code: 42, userInfo: [
            NSLocalizedDescriptionKey: "Sensitive data in error"
        ])
        tracer.logSensitiveError(error, context: "TestContext")

        #expect(mock.capturedEntries.count == 1)
    }
}
