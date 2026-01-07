import Foundation
import os

// MARK: - Protocols

/// Protocol for logging service - enables dependency injection and testing
protocol LoggingServiceProtocol: Sendable {
    /// Get a logger for a specific category
    /// - Parameter category: The log category (subsystem area)
    /// - Returns: A category-specific logger
    func logger(category: LogCategory) -> CategoryLoggerProtocol
}

/// Protocol for category-specific logging operations
protocol CategoryLoggerProtocol: Sendable {
    // MARK: - Standard Log Levels (Public)

    /// Log a debug message (public, always visible)
    func debug(_ message: String)

    /// Log an informational message (public, always visible)
    func info(_ message: String)

    /// Log a notice message (public, always visible)
    func notice(_ message: String)

    /// Log an error message (public, always visible)
    func error(_ message: String)

    /// Log a fault message (public, always visible)
    func fault(_ message: String)

    // MARK: - Privacy-Aware Logging

    /// Log a debug message with explicit privacy level
    func debug(_ message: String, privacy: LogPrivacyLevel)

    /// Log an informational message with explicit privacy level
    func info(_ message: String, privacy: LogPrivacyLevel)

    /// Log a notice message with explicit privacy level
    func notice(_ message: String, privacy: LogPrivacyLevel)

    /// Log an error message with explicit privacy level
    func error(_ message: String, privacy: LogPrivacyLevel)

    /// Log a fault message with explicit privacy level
    func fault(_ message: String, privacy: LogPrivacyLevel)

    // MARK: - Convenience Methods (Safe Patterns)

    /// Log an operation with state (both public, safe to log)
    /// - Parameters:
    ///   - operation: Name of the operation (e.g., "setUp", "unlock")
    ///   - state: State of the operation (e.g., "started", "completed", "failed")
    func logOperation(_ operation: String, state: String)

    /// Log a user ID (UUID) - pseudonymous, safe to log publicly
    /// - Parameter userID: The user's UUID
    func logUserID(_ userID: String)

    /// Log a record count - safe metadata
    /// - Parameter count: Number of records
    func logRecordCount(_ count: Int)

    /// Log a timestamp - safe metadata
    /// - Parameter date: The timestamp to log
    func logTimestamp(_ date: Date)

    /// Log an error with context (error details are private)
    /// - Parameters:
    ///   - error: The error that occurred
    ///   - context: Public context (e.g., function name)
    func logError(_ error: Error, context: String)
}

// MARK: - Implementation

/// Main logging service providing structured, privacy-aware logging
final class LoggingService: LoggingServiceProtocol, @unchecked Sendable {
    /// Shared singleton instance
    static let shared = LoggingService()

    /// Bundle identifier for subsystem
    private let subsystem: String

    /// Cache of category loggers (thread-safe access)
    private var loggers: [LogCategory: CategoryLogger] = [:]
    private let lock = NSLock()

    /// Initialize logging service
    /// - Parameter subsystem: Bundle identifier (defaults to main bundle)
    init(subsystem: String = Bundle.main.bundleIdentifier ?? "com.cynexia.FamilyMedicalApp") {
        self.subsystem = subsystem
    }

    func logger(category: LogCategory) -> CategoryLoggerProtocol {
        lock.lock()
        defer { lock.unlock() }

        if let existing = loggers[category] {
            return existing
        }

        let logger = CategoryLogger(
            osLogger: Logger(subsystem: subsystem, category: category.rawValue),
            category: category
        )
        loggers[category] = logger
        return logger
    }
}

// MARK: - Category Logger

/// Category-specific logger with privacy-aware methods
final class CategoryLogger: CategoryLoggerProtocol, @unchecked Sendable {
    private let osLogger: Logger
    private let category: LogCategory

    init(osLogger: Logger, category: LogCategory) {
        self.osLogger = osLogger
        self.category = category
    }

    // MARK: - Standard Log Levels

    func debug(_ message: String) {
        osLogger.debug("\(message, privacy: .public)")
    }

    func info(_ message: String) {
        osLogger.info("\(message, privacy: .public)")
    }

    func notice(_ message: String) {
        osLogger.notice("\(message, privacy: .public)")
    }

    func error(_ message: String) {
        osLogger.error("\(message, privacy: .public)")
    }

    func fault(_ message: String) {
        osLogger.fault("\(message, privacy: .public)")
    }

    // MARK: - Privacy-Aware Logging

    func debug(_ message: String, privacy: LogPrivacyLevel) {
        logWithPrivacy(level: .debug, message: message, privacy: privacy)
    }

    func info(_ message: String, privacy: LogPrivacyLevel) {
        logWithPrivacy(level: .info, message: message, privacy: privacy)
    }

    func notice(_ message: String, privacy: LogPrivacyLevel) {
        logWithPrivacy(level: .notice, message: message, privacy: privacy)
    }

    func error(_ message: String, privacy: LogPrivacyLevel) {
        logWithPrivacy(level: .error, message: message, privacy: privacy)
    }

    func fault(_ message: String, privacy: LogPrivacyLevel) {
        logWithPrivacy(level: .fault, message: message, privacy: privacy)
    }

    // MARK: - Private Helpers

    private enum LogLevel {
        case debug, info, notice, error, fault
    }

    private func logWithPrivacy(level: LogLevel, message: String, privacy: LogPrivacyLevel) {
        switch (level, privacy) {
        // Debug level
        case (.debug, .public):
            osLogger.debug("\(message, privacy: .public)")
        case (.debug, .private):
            osLogger.debug("\(message, privacy: .private)")
        case (.debug, .hashed):
            osLogger.debug("\(message, privacy: .private(mask: .hash))")
        case (.debug, .sensitive):
            osLogger.debug("[REDACTED - sensitive data]")
        // Info level
        case (.info, .public):
            osLogger.info("\(message, privacy: .public)")
        case (.info, .private):
            osLogger.info("\(message, privacy: .private)")
        case (.info, .hashed):
            osLogger.info("\(message, privacy: .private(mask: .hash))")
        case (.info, .sensitive):
            osLogger.info("[REDACTED - sensitive data]")
        // Notice level
        case (.notice, .public):
            osLogger.notice("\(message, privacy: .public)")
        case (.notice, .private):
            osLogger.notice("\(message, privacy: .private)")
        case (.notice, .hashed):
            osLogger.notice("\(message, privacy: .private(mask: .hash))")
        case (.notice, .sensitive):
            osLogger.notice("[REDACTED - sensitive data]")
        // Error level
        case (.error, .public):
            osLogger.error("\(message, privacy: .public)")
        case (.error, .private):
            osLogger.error("\(message, privacy: .private)")
        case (.error, .hashed):
            osLogger.error("\(message, privacy: .private(mask: .hash))")
        case (.error, .sensitive):
            osLogger.error("[REDACTED - sensitive data]")
        // Fault level
        case (.fault, .public):
            osLogger.fault("\(message, privacy: .public)")
        case (.fault, .private):
            osLogger.fault("\(message, privacy: .private)")
        case (.fault, .hashed):
            osLogger.fault("\(message, privacy: .private(mask: .hash))")
        case (.fault, .sensitive):
            osLogger.fault("[REDACTED - sensitive data]")
        }
    }

    // MARK: - Convenience Methods

    func logOperation(_ operation: String, state: String) {
        let category = self.category.rawValue
        osLogger
            .info("[\(category, privacy: .public)] \(operation, privacy: .public): \(state, privacy: .public)")
    }

    func logUserID(_ userID: String) {
        osLogger.debug("userID: \(userID, privacy: .public)")
    }

    func logRecordCount(_ count: Int) {
        osLogger.debug("recordCount: \(count, privacy: .public)")
    }

    func logTimestamp(_ date: Date) {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let timestamp = isoFormatter.string(from: date)
        osLogger.debug("timestamp: \(timestamp, privacy: .public)")
    }

    func logError(_ error: Error, context: String) {
        // Log context publicly, error type publicly, but details are private
        let errorType = String(describing: type(of: error))
        let errorDesc = error.localizedDescription
        osLogger
            .error("[\(context, privacy: .public)] \(errorType, privacy: .public): \(errorDesc, privacy: .private)")
    }
}
