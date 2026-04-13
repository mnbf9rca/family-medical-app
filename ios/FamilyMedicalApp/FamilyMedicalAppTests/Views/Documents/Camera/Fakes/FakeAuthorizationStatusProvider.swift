import AVFoundation
import Foundation
@testable import FamilyMedicalApp

/// Deterministic fake for `AuthorizationStatusProviding`.
/// `initialStatus` controls the result of `currentStatus()`.
/// `accessGranted` controls the result of `requestAccess()`.
/// `requestAccessCalls` records invocations for verification.
final class FakeAuthorizationStatusProvider: AuthorizationStatusProviding, @unchecked Sendable {
    var initialStatus: AVAuthorizationStatus
    var accessGranted: Bool
    private(set) var requestAccessCalls: Int = 0

    init(initialStatus: AVAuthorizationStatus = .authorized, accessGranted: Bool = true) {
        self.initialStatus = initialStatus
        self.accessGranted = accessGranted
    }

    func currentStatus() -> AVAuthorizationStatus {
        initialStatus
    }

    func requestAccess() async -> Bool {
        requestAccessCalls += 1
        return accessGranted
    }
}
