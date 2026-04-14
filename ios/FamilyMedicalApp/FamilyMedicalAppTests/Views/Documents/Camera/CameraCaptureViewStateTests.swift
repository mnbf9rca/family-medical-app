import Foundation
import Testing
import UIKit
@testable import FamilyMedicalApp

/// Smoke tests for `CameraCaptureController`. The view itself owns a real
/// `CameraCaptureController` via `@State`, which constructs a real
/// `AVCaptureSession` — testing the SwiftUI body directly would touch
/// AVFoundation. State-rendering behavior is verified by the coordinator
/// unit tests, which exercise every branch of `content`'s switch. These
/// smoke tests confirm the controller itself does not crash on the
/// simulator.
@MainActor
struct CameraCaptureControllerSmokeTests {
    @Test
    func hasAnyCamera_doesNotCrash() {
        _ = CameraCaptureController.hasAnyCamera
    }

    @Test
    func controllerInit_doesNotCrash() {
        _ = CameraCaptureController()
    }
}
