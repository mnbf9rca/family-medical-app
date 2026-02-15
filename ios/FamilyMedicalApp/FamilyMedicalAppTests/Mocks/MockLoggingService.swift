import Foundation
@testable import FamilyMedicalApp

// MARK: - Captured Log Entry

/// Captured log entry for testing
struct CapturedLogEntry: Equatable, Sendable {
    let level: LogLevel
    let message: String
    let privacy: LogPrivacyLevel
    let category: LogCategory
    let timestamp: Date

    enum LogLevel: String, Equatable, Sendable {
        case debug, info, notice, error, fault
    }
}

// MARK: - Mock Category Logger

/// Mock logger for testing privacy and logging behavior
/// @unchecked Sendable: Safe for tests where mocks are only used from MainActor test contexts
final class MockCategoryLogger: CategoryLoggerProtocol, @unchecked Sendable {
    private(set) var capturedEntries: [CapturedLogEntry] = []
    private let category: LogCategory

    init(category: LogCategory) {
        self.category = category
    }

    // MARK: - Standard Log Levels

    func debug(_ message: String) {
        capturedEntries.append(CapturedLogEntry(
            level: .debug,
            message: message,
            privacy: .public,
            category: category,
            timestamp: Date()
        ))
    }

    func info(_ message: String) {
        capturedEntries.append(CapturedLogEntry(
            level: .info,
            message: message,
            privacy: .public,
            category: category,
            timestamp: Date()
        ))
    }

    func notice(_ message: String) {
        capturedEntries.append(CapturedLogEntry(
            level: .notice,
            message: message,
            privacy: .public,
            category: category,
            timestamp: Date()
        ))
    }

    func error(_ message: String) {
        capturedEntries.append(CapturedLogEntry(
            level: .error,
            message: message,
            privacy: .public,
            category: category,
            timestamp: Date()
        ))
    }

    func fault(_ message: String) {
        capturedEntries.append(CapturedLogEntry(
            level: .fault,
            message: message,
            privacy: .public,
            category: category,
            timestamp: Date()
        ))
    }

    // MARK: - Privacy-Aware Logging

    func debug(_ message: String, privacy: LogPrivacyLevel) {
        capturedEntries.append(CapturedLogEntry(
            level: .debug,
            message: message,
            privacy: privacy,
            category: category,
            timestamp: Date()
        ))
    }

    func info(_ message: String, privacy: LogPrivacyLevel) {
        capturedEntries.append(CapturedLogEntry(
            level: .info,
            message: message,
            privacy: privacy,
            category: category,
            timestamp: Date()
        ))
    }

    func notice(_ message: String, privacy: LogPrivacyLevel) {
        capturedEntries.append(CapturedLogEntry(
            level: .notice,
            message: message,
            privacy: privacy,
            category: category,
            timestamp: Date()
        ))
    }

    func error(_ message: String, privacy: LogPrivacyLevel) {
        capturedEntries.append(CapturedLogEntry(
            level: .error,
            message: message,
            privacy: privacy,
            category: category,
            timestamp: Date()
        ))
    }

    func fault(_ message: String, privacy: LogPrivacyLevel) {
        capturedEntries.append(CapturedLogEntry(
            level: .fault,
            message: message,
            privacy: privacy,
            category: category,
            timestamp: Date()
        ))
    }

    // MARK: - Convenience Methods

    func logOperation(_ operation: String, state: String) {
        capturedEntries.append(CapturedLogEntry(
            level: .info,
            message: "[\(category.rawValue)] \(operation): \(state)",
            privacy: .public,
            category: category,
            timestamp: Date()
        ))
    }

    func logUserID(_ userID: String) {
        capturedEntries.append(CapturedLogEntry(
            level: .debug,
            message: "userID: \(userID)",
            privacy: .public,
            category: category,
            timestamp: Date()
        ))
    }

    func logRecordCount(_ count: Int) {
        capturedEntries.append(CapturedLogEntry(
            level: .debug,
            message: "recordCount: \(count)",
            privacy: .public,
            category: category,
            timestamp: Date()
        ))
    }

    func logTimestamp(_ date: Date) {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let timestamp = isoFormatter.string(from: date)
        capturedEntries.append(CapturedLogEntry(
            level: .debug,
            message: "timestamp: \(timestamp)",
            privacy: .public,
            category: category,
            timestamp: Date()
        ))
    }

    func logError(_ error: Error, context: String) {
        let errorType = String(describing: type(of: error))
        capturedEntries.append(CapturedLogEntry(
            level: .error,
            message: "[\(context)] \(errorType): \(error.localizedDescription)",
            privacy: .public,
            category: category,
            timestamp: Date()
        ))
    }

    // MARK: - Test Helpers

    /// Clear all captured entries
    func clear() {
        capturedEntries.removeAll()
    }

    /// Get entries containing a specific substring
    func entriesContaining(_ substring: String) -> [CapturedLogEntry] {
        capturedEntries.filter { $0.message.contains(substring) }
    }

    /// Get entries with a specific privacy level
    func entriesWithPrivacy(_ privacy: LogPrivacyLevel) -> [CapturedLogEntry] {
        capturedEntries.filter { $0.privacy == privacy }
    }

    /// Get entries at a specific log level
    func entriesWithLevel(_ level: CapturedLogEntry.LogLevel) -> [CapturedLogEntry] {
        capturedEntries.filter { $0.level == level }
    }
}

// MARK: - Mock Logging Service

/// Mock logging service for dependency injection in tests
/// @unchecked Sendable: Safe for tests where mocks are only used from MainActor test contexts
final class MockLoggingService: LoggingServiceProtocol, @unchecked Sendable {
    private var loggers: [LogCategory: MockCategoryLogger] = [:]

    func logger(category: LogCategory) -> CategoryLoggerProtocol {
        if let existing = loggers[category] {
            return existing
        }

        let logger = MockCategoryLogger(category: category)
        loggers[category] = logger
        return logger
    }

    /// Get the mock logger for a specific category (test helper)
    func mockLogger(category: LogCategory) -> MockCategoryLogger {
        if let existing = loggers[category] {
            return existing
        }

        let logger = MockCategoryLogger(category: category)
        loggers[category] = logger
        return logger
    }

    /// Clear all captured logs
    func clearAll() {
        loggers.values.forEach { $0.clear() }
    }
}
