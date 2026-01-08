// swiftlint:disable force_unwrapping
import Foundation
import Testing
@testable import FamilyMedicalApp

struct LockStateServiceTests {
    // MARK: - Initialization Tests

    @Test
    func defaultTimeoutIsFiveMinutes() {
        let userDefaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let service = LockStateService(userDefaults: userDefaults)

        #expect(service.lockTimeoutSeconds == 300)
    }

    @Test
    func initiallyNotLocked() {
        let userDefaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let service = LockStateService(userDefaults: userDefaults)

        #expect(service.isLocked == false)
    }

    // MARK: - Lock/Unlock Tests

    @Test
    func lockSetsIsLockedToTrue() {
        let userDefaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let service = LockStateService(userDefaults: userDefaults)

        service.lock()
        #expect(service.isLocked == true)
    }

    @Test
    func unlockSetsIsLockedToFalse() {
        let userDefaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let service = LockStateService(userDefaults: userDefaults)

        service.lock()
        service.unlock()
        #expect(service.isLocked == false)
    }

    // MARK: - Timeout Configuration Tests

    @Test
    func timeoutCanBeCustomized() {
        let userDefaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let service = LockStateService(userDefaults: userDefaults)

        service.lockTimeoutSeconds = 600 // 10 minutes
        #expect(service.lockTimeoutSeconds == 600)
    }

    @Test
    func timeoutPersistsAcrossInstances() {
        let suiteName = "test-\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!

        let service1 = LockStateService(userDefaults: userDefaults)
        service1.lockTimeoutSeconds = 900 // 15 minutes

        let service2 = LockStateService(userDefaults: userDefaults)
        #expect(service2.lockTimeoutSeconds == 900)
    }

    // MARK: - Background Tracking Tests

    @Test
    func shouldNotLockWhenNoBackgroundTimeRecorded() {
        let userDefaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let service = LockStateService(userDefaults: userDefaults)

        let shouldLock = service.shouldLockOnForeground()
        #expect(shouldLock == false)
    }

    @Test
    func shouldNotLockWhenBackgroundTimeIsShort() {
        let userDefaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let service = LockStateService(userDefaults: userDefaults)

        // Record background time just now
        service.recordBackgroundTime()

        // Immediately check if should lock
        let shouldLock = service.shouldLockOnForeground()
        #expect(shouldLock == false)
    }

    @Test
    func shouldLockWhenBackgroundTimeExceedsTimeout() {
        let userDefaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
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
    func shouldLockClearsBackgroundTime() {
        let userDefaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let service = LockStateService(userDefaults: userDefaults)

        service.recordBackgroundTime()
        _ = service.shouldLockOnForeground()

        // Background time should be cleared
        let backgroundTime = userDefaults.double(forKey: "com.family-medical-app.background-time")
        #expect(backgroundTime == 0)
    }

    @Test
    func unlockClearsBackgroundTime() {
        let userDefaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let service = LockStateService(userDefaults: userDefaults)

        service.recordBackgroundTime()
        service.unlock()

        let backgroundTime = userDefaults.double(forKey: "com.family-medical-app.background-time")
        #expect(backgroundTime == 0)
    }

    // MARK: - Edge Cases

    @Test
    func multipleBackgroundRecordingsUseLatest() {
        let userDefaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
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
