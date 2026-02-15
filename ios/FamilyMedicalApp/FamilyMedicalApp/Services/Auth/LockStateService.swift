import Foundation
import Observation

/// Protocol for lock state management
protocol LockStateServiceProtocol {
    /// Whether the app is currently locked
    var isLocked: Bool { get set }

    /// Lock timeout in seconds (default 300 = 5 minutes)
    var lockTimeoutSeconds: Int { get set }

    /// Whether the app is in demo mode
    var isDemoMode: Bool { get set }

    /// Record the time when app goes to background
    func recordBackgroundTime()

    /// Check if app should lock based on background duration
    /// - Returns: True if app has been in background longer than timeout
    func shouldLockOnForeground() -> Bool

    /// Manually lock the app
    func lock()

    /// Unlock the app
    func unlock()
}

/// Service for tracking app lock state and timeout
@Observable
final class LockStateService: LockStateServiceProtocol {
    // MARK: - Constants

    private static let backgroundTimeKey = "com.family-medical-app.background-time"
    private static let lockTimeoutKey = "com.family-medical-app.lock-timeout"
    private static let demoModeKey = "com.family-medical-app.demo-mode"
    private static let defaultTimeout = 300 // 5 minutes

    // MARK: - Properties

    private let logger = TracingCategoryLogger(
        wrapping: LoggingService.shared.logger(category: .auth)
    )

    var isLocked: Bool = false

    var lockTimeoutSeconds: Int {
        get {
            userDefaults.integer(forKey: Self.lockTimeoutKey).takeIf { $0 > 0 } ?? Self.defaultTimeout
        }
        set {
            userDefaults.set(newValue, forKey: Self.lockTimeoutKey)
        }
    }

    var isDemoMode: Bool {
        get {
            userDefaults.bool(forKey: Self.demoModeKey)
        }
        set {
            userDefaults.set(newValue, forKey: Self.demoModeKey)
        }
    }

    private let userDefaults: UserDefaults

    // MARK: - Initialization

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults

        // Initialize timeout if not set
        if userDefaults.integer(forKey: Self.lockTimeoutKey) == 0 {
            userDefaults.set(Self.defaultTimeout, forKey: Self.lockTimeoutKey)
        }
    }

    // MARK: - LockStateServiceProtocol

    func recordBackgroundTime() {
        let start = ContinuousClock.now
        logger.entry("recordBackgroundTime")
        let now = Date().timeIntervalSince1970
        userDefaults.set(now, forKey: Self.backgroundTimeKey)
        logger.exit("recordBackgroundTime", duration: ContinuousClock.now - start)
    }

    func shouldLockOnForeground() -> Bool {
        let start = ContinuousClock.now
        logger.entry("shouldLockOnForeground")
        let backgroundTime = userDefaults.double(forKey: Self.backgroundTimeKey)

        // If no background time recorded, don't lock
        guard backgroundTime > 0 else {
            logger.exit("shouldLockOnForeground", duration: ContinuousClock.now - start)
            return false
        }

        let now = Date().timeIntervalSince1970
        let elapsed = now - backgroundTime
        let timeout = Double(lockTimeoutSeconds)

        // Clear the background time
        userDefaults.removeObject(forKey: Self.backgroundTimeKey)

        let shouldLock = elapsed >= timeout
        logger.exit("shouldLockOnForeground", duration: ContinuousClock.now - start)
        return shouldLock
    }

    func lock() {
        let start = ContinuousClock.now
        logger.entry("lock")
        isLocked = true
        logger.exit("lock", duration: ContinuousClock.now - start)
    }

    func unlock() {
        let start = ContinuousClock.now
        logger.entry("unlock")
        isLocked = false
        // Clear background time when unlocking
        userDefaults.removeObject(forKey: Self.backgroundTimeKey)
        logger.exit("unlock", duration: ContinuousClock.now - start)
    }
}

// MARK: - Helper Extension

private extension Int {
    /// Returns this Int if it satisfies the given predicate, otherwise returns nil.
    /// Kotlin-inspired utility for conditional value selection.
    func takeIf(_ predicate: (Int) -> Bool) -> Int? {
        predicate(self) ? self : nil
    }
}
