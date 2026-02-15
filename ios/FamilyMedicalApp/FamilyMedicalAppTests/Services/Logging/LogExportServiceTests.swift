import Foundation
import Testing
@testable import FamilyMedicalApp

@MainActor
struct LogExportServiceTests {
    @Test
    func logTimeWindowAllCasesExist() {
        #expect(LogTimeWindow.allCases.count == 4)
    }

    @Test
    func logTimeWindowTimeIntervals() {
        #expect(LogTimeWindow.lastHour.timeInterval == 3_600)
        #expect(LogTimeWindow.last6Hours.timeInterval == 21_600)
        #expect(LogTimeWindow.last24Hours.timeInterval == 86_400)
        #expect(LogTimeWindow.last7Days.timeInterval == 604_800)
    }

    @Test
    func logTimeWindowDisplayNames() {
        #expect(LogTimeWindow.lastHour.rawValue == "Last hour")
        #expect(LogTimeWindow.last6Hours.rawValue == "Last 6 hours")
        #expect(LogTimeWindow.last24Hours.rawValue == "Last 24 hours")
        #expect(LogTimeWindow.last7Days.rawValue == "Last 7 days")
    }

    @Test
    func deviceMetadataContainsRequiredFields() {
        let metadata = DeviceMetadata.current()
        #expect(!metadata.appVersion.isEmpty)
        #expect(!metadata.iosVersion.isEmpty)
        #expect(!metadata.deviceModel.isEmpty)
        #expect(!metadata.locale.isEmpty)
    }

    @Test
    func formatMetadataHeaderContainsAllFields() {
        let metadata = DeviceMetadata(
            appVersion: "1.0.0",
            buildNumber: "42",
            iosVersion: "18.3.1",
            deviceModel: "iPhone17,1",
            locale: "en_US",
            diskFreeBytes: 45_000_000_000
        )

        let header = LogExportFormatter.formatHeader(
            metadata: metadata,
            timeWindow: .last24Hours,
            exportDate: Date()
        )

        #expect(header.contains("1.0.0 (42)"))
        #expect(header.contains("18.3.1"))
        #expect(header.contains("iPhone17,1"))
        #expect(header.contains("en_US"))
        #expect(header.contains("Last 24 hours"))
        #expect(header.contains("Family Medical App Diagnostic Report"))
    }

    @Test
    func formatLogEntryFormatsCorrectly() throws {
        let formatted = try LogExportFormatter.formatEntry(
            date: #require(ISO8601DateFormatter().date(from: "2026-02-15T14:30:12Z")),
            level: "error",
            category: "storage",
            message: "✗ loadSchemas (12ms) SchemaError: Failed to decrypt"
        )

        #expect(formatted.contains("[error ]"))
        #expect(formatted.contains("[storage]"))
        #expect(formatted.contains("✗ loadSchemas"))
    }

    @Test
    func formattedDiskFreeFormatsBytes() {
        let metadata = DeviceMetadata(
            appVersion: "1.0.0",
            buildNumber: "1",
            iosVersion: "18.0",
            deviceModel: "iPhone17,1",
            locale: "en_US",
            diskFreeBytes: 45_000_000_000
        )

        #expect(!metadata.formattedDiskFree.isEmpty)
    }

    // MARK: - LogExportService Init

    @Test
    func initWithDefaultLogger() {
        let service = LogExportService()
        // Verifies init completes without crash and default logger wiring works
        #expect(service is LogExportServiceProtocol)
    }

    @Test
    func initWithInjectedLogger() {
        let mock = MockCategoryLogger(category: .ui)
        let service = LogExportService(logger: mock)
        // Verifies TracingCategoryLogger wrapping doesn't reject the mock
        #expect(service is LogExportServiceProtocol)
    }

    @Test
    func initWithCustomSubsystem() {
        let service = LogExportService(subsystem: "com.test.custom")
        #expect(service is LogExportServiceProtocol)
    }

    // MARK: - Error Descriptions

    @Test
    func logExportErrorDescriptions() {
        let storeError = LogExportError.storeAccessFailed(NSError(domain: "test", code: 1))
        #expect(storeError.errorDescription?.contains("Unable to access") == true)

        let noLogs = LogExportError.noLogsFound
        #expect(noLogs.errorDescription?.contains("No log entries") == true)

        let writeError = LogExportError.fileWriteFailed(NSError(domain: "test", code: 1))
        #expect(writeError.errorDescription?.contains("Failed to create") == true)
    }
}
