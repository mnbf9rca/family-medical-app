import Foundation
import OSLog

// MARK: - Types

/// Time window for log export
enum LogTimeWindow: String, CaseIterable, Sendable {
    case lastHour = "Last hour"
    case last6Hours = "Last 6 hours"
    case last24Hours = "Last 24 hours"
    case last7Days = "Last 7 days"

    var timeInterval: TimeInterval {
        switch self {
        case .lastHour: 3_600
        case .last6Hours: 21_600
        case .last24Hours: 86_400
        case .last7Days: 604_800
        }
    }
}

/// Device and app metadata for export header
struct DeviceMetadata: Sendable {
    let appVersion: String
    let buildNumber: String
    let iosVersion: String
    let deviceModel: String
    let locale: String
    let diskFreeBytes: Int64

    static func current() -> DeviceMetadata {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"

        var diskSpace: Int64 = 0
        if let attrs = try? FileManager.default.attributesOfFileSystem(
            forPath: NSHomeDirectory()
        ), let freeSize = attrs[.systemFreeSize] as? Int64 {
            diskSpace = freeSize
        }

        var systemInfo = utsname()
        uname(&systemInfo)
        let model = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingCString: $0) ?? "unknown"
            }
        }

        return DeviceMetadata(
            appVersion: appVersion,
            buildNumber: buildNumber,
            iosVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            deviceModel: model,
            locale: Locale.current.identifier,
            diskFreeBytes: diskSpace
        )
    }

    var formattedDiskFree: String {
        ByteCountFormatter.string(fromByteCount: diskFreeBytes, countStyle: .file)
    }
}

// MARK: - Formatter

/// Formats log entries and metadata for export
enum LogExportFormatter {
    static func formatHeader(
        metadata: DeviceMetadata,
        timeWindow: LogTimeWindow,
        exportDate: Date
    ) -> String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]
        let dateString = isoFormatter.string(from: exportDate)

        return """
        === Family Medical App Diagnostic Report ===
        App Version: \(metadata.appVersion) (\(metadata.buildNumber))
        iOS Version: \(metadata.iosVersion)
        Device: \(metadata.deviceModel)
        Locale: \(metadata.locale)
        Disk Free: \(metadata.formattedDiskFree)
        Export Time: \(dateString)
        Window: \(timeWindow.rawValue)

        Note: Hashed values (shown as <mask.hash:...>) use a per-boot
        salt. Hashes correlate within a single session but change after
        reboot.
        =============================================

        """
    }

    static func formatEntry(
        date: Date,
        level: String,
        category: String,
        message: String
    ) -> String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let dateString = isoFormatter.string(from: date)
        let paddedLevel = level.padding(toLength: 6, withPad: " ", startingAt: 0)
        return "\(dateString) [\(paddedLevel)] [\(category)] \(message)"
    }
}

// MARK: - Protocol

/// Protocol for log export operations
protocol LogExportServiceProtocol: Sendable {
    /// Export logs for the given time window
    /// - Parameter timeWindow: How far back to collect logs
    /// - Returns: URL of the temporary file containing the exported logs
    func exportLogs(timeWindow: LogTimeWindow) async throws -> URL
}

// MARK: - Errors

enum LogExportError: Error, LocalizedError {
    case storeAccessFailed(Error)
    case noLogsFound
    case fileWriteFailed(Error)

    var errorDescription: String? {
        switch self {
        case .storeAccessFailed:
            "Unable to access system logs. Please try again."
        case .noLogsFound:
            "No log entries found for the selected time window."
        case .fileWriteFailed:
            "Failed to create the diagnostic report file."
        }
    }
}

// MARK: - Implementation

/// Service for exporting app logs from OSLogStore
final class LogExportService: LogExportServiceProtocol, @unchecked Sendable {
    private let subsystem: String
    private let logger: TracingCategoryLogger

    init(
        subsystem: String = Bundle.main.bundleIdentifier ?? "com.cynexia.FamilyMedicalApp",
        logger: CategoryLoggerProtocol? = nil
    ) {
        self.subsystem = subsystem
        self.logger = TracingCategoryLogger(
            wrapping: logger ?? LoggingService.shared.logger(category: .ui)
        )
    }

    func exportLogs(timeWindow: LogTimeWindow) async throws -> URL {
        let start = ContinuousClock.now
        logger.entry("exportLogs", "window=\(timeWindow.rawValue)")
        do {
            let fileURL = try await Task.detached(priority: .userInitiated) { [self] in
                let exportDate = Date()
                let entries = try queryLogEntries(timeWindow: timeWindow, exportDate: exportDate)
                let metadata = DeviceMetadata.current()
                logger.debug("Found \(entries.count) log entries")
                let output = formatExportOutput(
                    entries: entries,
                    metadata: metadata,
                    timeWindow: timeWindow,
                    exportDate: exportDate
                )
                return try writeExportFile(output: output, exportDate: exportDate)
            }.value
            logger.exit("exportLogs", duration: ContinuousClock.now - start)
            return fileURL
        } catch {
            logger.exitWithError("exportLogs", error: error, duration: ContinuousClock.now - start)
            throw error
        }
    }

    // MARK: - Private

    private func formatExportOutput(
        entries: [OSLogEntryLog],
        metadata: DeviceMetadata,
        timeWindow: LogTimeWindow,
        exportDate: Date
    ) -> String {
        var output = LogExportFormatter.formatHeader(
            metadata: metadata,
            timeWindow: timeWindow,
            exportDate: exportDate
        )
        for entry in entries {
            let line = LogExportFormatter.formatEntry(
                date: entry.date,
                level: logLevelString(entry.level),
                category: entry.category,
                message: entry.composedMessage
            )
            output += line + "\n"
        }
        return output
    }

    private func queryLogEntries(
        timeWindow: LogTimeWindow,
        exportDate: Date
    ) throws -> [OSLogEntryLog] {
        let store: OSLogStore
        do {
            store = try OSLogStore(scope: .currentProcessIdentifier)
        } catch {
            throw LogExportError.storeAccessFailed(error)
        }

        let startDate = exportDate.addingTimeInterval(-timeWindow.timeInterval)
        let position = store.position(date: startDate)
        let predicate = NSPredicate(format: "subsystem == %@", subsystem)

        let entries: [OSLogEntryLog]
        do {
            entries = try store.getEntries(at: position, matching: predicate)
                .compactMap { $0 as? OSLogEntryLog }
        } catch {
            throw LogExportError.storeAccessFailed(error)
        }

        guard !entries.isEmpty else {
            throw LogExportError.noLogsFound
        }

        return entries
    }

    private func writeExportFile(output: String, exportDate: Date) throws -> URL {
        let fileName = "FamilyMedical-Diagnostics-\(formatDateForFilename(exportDate)).txt"
        let dirURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("FamilyMedicalAppDiagnostics", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
            let fileURL = dirURL.appendingPathComponent(fileName)
            try output.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            throw LogExportError.fileWriteFailed(error)
        }
    }

    private func logLevelString(_ level: OSLogEntryLog.Level) -> String {
        switch level {
        case .debug: "debug"
        case .info: "info"
        case .notice: "notice"
        case .error: "error"
        case .fault: "fault"
        default: "other"
        }
    }

    private func formatDateForFilename(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter.string(from: date)
    }
}
