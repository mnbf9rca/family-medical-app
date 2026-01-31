// swiftlint:disable force_unwrapping
import Foundation
import Testing
@testable import FamilyMedicalApp

struct LockStateServiceTests {
    // MARK: - Initialization Tests

    @Test
    func defaultTimeoutIsFiveMinutes() throws {
        let userDefaults = try #require(UserDefaults(suiteName: "test-\(UUID().uuidString)"))
        let service = LockStateService(userDefaults: userDefaults)

        #expect(service.lockTimeoutSeconds == 300)
    }

    @Test
    func initiallyNotLocked() throws {
        let userDefaults = try #require(UserDefaults(suiteName: "test-\(UUID().uuidString)"))
        let service = LockStateService(userDefaults: userDefaults)

        #expect(service.isLocked == false)
    }

    // MARK: - Lock/Unlock Tests

    @Test
    func lockSetsIsLockedToTrue() throws {
        let userDefaults = try #require(UserDefaults(suiteName: "test-\(UUID().uuidString)"))
        let service = LockStateService(userDefaults: userDefaults)

        service.lock()
        #expect(service.isLocked == true)
    }

    @Test
    func unlockSetsIsLockedToFalse() throws {
        let userDefaults = try #require(UserDefaults(suiteName: "test-\(UUID().uuidString)"))
        let service = LockStateService(userDefaults: userDefaults)

        service.lock()
        service.unlock()
        #expect(service.isLocked == false)
    }

    // MARK: - Timeout Configuration Tests

    @Test
    func timeoutCanBeCustomized() throws {
        let userDefaults = try #require(UserDefaults(suiteName: "test-\(UUID().uuidString)"))
        let service = LockStateService(userDefaults: userDefaults)

        service.lockTimeoutSeconds = 600 // 10 minutes
        #expect(service.lockTimeoutSeconds == 600)
    }

    @Test
    func timeoutPersistsAcrossInstances() throws {
        let suiteName = "test-\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))

        let service1 = LockStateService(userDefaults: userDefaults)
        service1.lockTimeoutSeconds = 900 // 15 minutes

        let service2 = LockStateService(userDefaults: userDefaults)
        #expect(service2.lockTimeoutSeconds == 900)
    }

    // MARK: - Background Tracking Tests

    @Test
    func shouldNotLockWhenNoBackgroundTimeRecorded() throws {
        let userDefaults = try #require(UserDefaults(suiteName: "test-\(UUID().uuidString)"))
        let service = LockStateService(userDefaults: userDefaults)

        let shouldLock = service.shouldLockOnForeground()
        #expect(shouldLock == false)
    }

    @Test
    func shouldNotLockWhenBackgroundTimeIsShort() throws {
        let userDefaults = try #require(UserDefaults(suiteName: "test-\(UUID().uuidString)"))
        let service = LockStateService(userDefaults: userDefaults)

        // Record background time just now
        service.recordBackgroundTime()

        // Immediately check if should lock
        let shouldLock = service.shouldLockOnForeground()
        #expect(shouldLock == false)
    }

    @Test
    func shouldLockWhenBackgroundTimeExceedsTimeout() throws {
        let userDefaults = try #require(UserDefaults(suiteName: "test-\(UUID().uuidString)"))
        let service = LockStateService(userDefaults: userDefaults)

        // Set a short timeout for testing
        service.lockTimeoutSeconds = 1 // 1 second

        // Set background time far enough in the past (10 seconds) to always exceed
        // the 1-second timeout, regardless of minor timing variations
        let tenSecondsAgo = Date().timeIntervalSince1970 - 10
        userDefaults.set(tenSecondsAgo, forKey: "com.family-medical-app.background-time")

        let shouldLock = service.shouldLockOnForeground()
        #expect(shouldLock == true)
    }

    @Test
    func shouldLockClearsBackgroundTime() throws {
        let userDefaults = try #require(UserDefaults(suiteName: "test-\(UUID().uuidString)"))
        let service = LockStateService(userDefaults: userDefaults)

        service.recordBackgroundTime()
        _ = service.shouldLockOnForeground()

        // Background time should be cleared
        let backgroundTime = userDefaults.double(forKey: "com.family-medical-app.background-time")
        #expect(backgroundTime == 0)
    }

    @Test
    func unlockClearsBackgroundTime() throws {
        let userDefaults = try #require(UserDefaults(suiteName: "test-\(UUID().uuidString)"))
        let service = LockStateService(userDefaults: userDefaults)

        service.recordBackgroundTime()
        service.unlock()

        let backgroundTime = userDefaults.double(forKey: "com.family-medical-app.background-time")
        #expect(backgroundTime == 0)
    }

    // MARK: - Edge Cases

    @Test
    func multipleBackgroundRecordingsUseLatest() throws {
        let userDefaults = try #require(UserDefaults(suiteName: "test-\(UUID().uuidString)"))
        let service = LockStateService(userDefaults: userDefaults)

        let firstTime = Date().timeIntervalSince1970 - 10
        userDefaults.set(firstTime, forKey: "com.family-medical-app.background-time")

        // Record again (should overwrite)
        service.recordBackgroundTime()

        let recordedTime = userDefaults.double(forKey: "com.family-medical-app.background-time")
        #expect(recordedTime > firstTime)
    }
}

// swiftlint:enable force_unwrapping
