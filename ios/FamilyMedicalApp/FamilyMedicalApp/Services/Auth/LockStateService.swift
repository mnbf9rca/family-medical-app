import Foundation
import Observation

/// Protocol for lock state management
protocol LockStateServiceProtocol {
    /// Whether the app is currently locked
    var isLocked: Bool { get set }

    /// Lock timeout in seconds (default 300 = 5 minutes)
    var lockTimeoutSeconds: Int { get set }

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
    private static let defaultTimeout = 300 // 5 minutes

    // MARK: - Properties

    var isLocked: Bool = false

    var lockTimeoutSeconds: Int {
        get {
            userDefaults.integer(forKey: Self.lockTimeoutKey).takeIf { $0 > 0 } ?? Self.defaultTimeout
        }
        set {
            userDefaults.set(newValue, forKey: Self.lockTimeoutKey)
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
        let now = Date().timeIntervalSince1970
        userDefaults.set(now, forKey: Self.backgroundTimeKey)
    }

    func shouldLockOnForeground() -> Bool {
        let backgroundTime = userDefaults.double(forKey: Self.backgroundTimeKey)

        // If no background time recorded, don't lock
        guard backgroundTime > 0 else {
            return false
        }

        let now = Date().timeIntervalSince1970
        let elapsed = now - backgroundTime
        let timeout = Double(lockTimeoutSeconds)

        // Clear the background time
        userDefaults.removeObject(forKey: Self.backgroundTimeKey)

        return elapsed >= timeout
    }

    func lock() {
        isLocked = true
    }

    func unlock() {
        isLocked = false
        // Clear background time when unlocking
        userDefaults.removeObject(forKey: Self.backgroundTimeKey)
    }
}

// MARK: - Helper Extension

private extension Int {
    func takeIf(_ predicate: (Int) -> Bool) -> Int? {
        predicate(self) ? self : nil
    }
}
