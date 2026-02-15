import Foundation

/// Decorator that wraps a CategoryLoggerProtocol and adds structured
/// entry/exit logging with timing.
///
/// Usage:
/// ```swift
/// let logger = TracingCategoryLogger(
///     wrapping: LoggingService.shared.logger(category: .storage)
/// )
/// let start = ContinuousClock.now
/// logger.entry("loadSchemas")
/// // ... work ...
/// logger.exit("loadSchemas", duration: ContinuousClock.now - start)
/// ```
///
/// Provides a migration path to Swift macros — call sites use the same
/// `entry`/`exit` pattern that a `@Traced` macro would generate.
final class TracingCategoryLogger: CategoryLoggerProtocol, @unchecked Sendable {
    private let inner: CategoryLoggerProtocol

    init(wrapping inner: CategoryLoggerProtocol) {
        self.inner = inner
    }

    // MARK: - Tracing Methods

    /// Log method entry
    /// - Parameters:
    ///   - method: Method name (e.g., "loadSchemas")
    ///   - details: Optional context (e.g., "personId=ABC")
    func entry(_ method: String, _ details: String? = nil) {
        if let details {
            inner.debug("→ \(method) (\(details))")
        } else {
            inner.debug("→ \(method)")
        }
    }

    /// Log successful method exit with timing
    /// - Parameters:
    ///   - method: Method name
    ///   - duration: Elapsed time
    func exit(_ method: String, duration: Duration) {
        inner.debug("← \(method) (\(formatDuration(duration)))")
    }

    /// Log method exit on error path with timing
    /// - Parameters:
    ///   - method: Method name
    ///   - error: The error that occurred
    ///   - duration: Elapsed time
    func exitWithError(_ method: String, error: Error, duration: Duration) {
        let errorType = String(describing: type(of: error))
        let errorDesc = error.localizedDescription
        inner.error("✗ \(method) (\(formatDuration(duration))) \(errorType): \(errorDesc)")
    }

    // MARK: - Standard Log Levels (delegate to inner)

    func debug(_ message: String) {
        inner.debug(message)
    }

    func info(_ message: String) {
        inner.info(message)
    }

    func notice(_ message: String) {
        inner.notice(message)
    }

    func error(_ message: String) {
        inner.error(message)
    }

    func fault(_ message: String) {
        inner.fault(message)
    }

    // MARK: - Privacy-Aware Logging (delegate to inner)

    func debug(_ message: String, privacy: LogPrivacyLevel) {
        inner.debug(message, privacy: privacy)
    }

    func info(_ message: String, privacy: LogPrivacyLevel) {
        inner.info(message, privacy: privacy)
    }

    func notice(_ message: String, privacy: LogPrivacyLevel) {
        inner.notice(message, privacy: privacy)
    }

    func error(_ message: String, privacy: LogPrivacyLevel) {
        inner.error(message, privacy: privacy)
    }

    func fault(_ message: String, privacy: LogPrivacyLevel) {
        inner.fault(message, privacy: privacy)
    }

    // MARK: - Convenience Methods (delegate to inner)

    func logOperation(_ operation: String, state: String) {
        inner.logOperation(operation, state: state)
    }

    func logUserID(_ userID: String) {
        inner.logUserID(userID)
    }

    func logRecordCount(_ count: Int) {
        inner.logRecordCount(count)
    }

    func logTimestamp(_ date: Date) {
        inner.logTimestamp(date)
    }

    func logError(_ error: Error, context: String) {
        inner.logError(error, context: context)
    }

    // MARK: - Private

    private func formatDuration(_ duration: Duration) -> String {
        let ms = duration.components.seconds * 1_000
            + duration.components.attoseconds / 1_000_000_000_000_000
        return "\(ms)ms"
    }
}
