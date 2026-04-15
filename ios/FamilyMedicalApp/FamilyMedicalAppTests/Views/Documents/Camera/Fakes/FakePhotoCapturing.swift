import AVFoundation
import Foundation
@testable import FamilyMedicalApp

/// Fake photo capturer that records `capture()` calls. Tests drive the
/// capture-success path by calling `coordinator.handlePhoto(_:)` directly
/// with a `FakeCapturedPhoto`.
@MainActor
final class FakePhotoCapturing: PhotoCapturing {
    private(set) var captureCalls: Int = 0
    private(set) var settingsRequested: Int = 0

    func makeCaptureSettings() -> AVCapturePhotoSettings {
        settingsRequested += 1
        return AVCapturePhotoSettings()
    }

    func capture(with _: AVCapturePhotoSettings) {
        captureCalls += 1
    }
}
