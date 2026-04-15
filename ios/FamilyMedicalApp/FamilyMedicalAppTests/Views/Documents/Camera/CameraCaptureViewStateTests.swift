import Foundation
import Testing
import UIKit
@testable import FamilyMedicalApp

/// Smoke tests for `CameraCaptureController`. The view stores the
/// controller lazily (constructed inside `.task`, not in a `@State`
/// default) specifically so the struct can be built in tests without
/// touching AVFoundation. State-rendering behavior is verified by the
/// coordinator unit tests, which exercise every branch of `content`'s
/// switch.
///
/// Only the nonisolated static `hasAnyCamera` probe is exercised here:
/// constructing a real `CameraCaptureController` on the simulator creates
/// a live `AVCaptureSession` whose `FigCaptureSourceSimulator` signalling
/// deadlocks the `@MainActor` Swift Testing runner (600s timeouts across
/// sibling parallel suites). The coordinator-level unit tests already
/// cover every logical branch; the controller's body is AVFoundation
/// wiring that is intentionally excluded from the per-file coverage
/// target (see plan §Task 11 notes on `CameraCaptureController.swift`).
@MainActor
struct CameraCaptureControllerSmokeTests {
    @Test
    func hasAnyCamera_doesNotCrash() {
        _ = CameraCaptureController.hasAnyCamera
    }
}
