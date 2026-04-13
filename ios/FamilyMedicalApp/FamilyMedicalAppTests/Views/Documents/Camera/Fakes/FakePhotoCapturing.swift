import AVFoundation
import Foundation
@testable import FamilyMedicalApp

/// Fake photo capturer that records `capture()` calls. The delegate
/// isn't automatically invoked — tests call the delegate methods
/// directly when they want to drive the capture callback, or call
/// `coordinator.handlePhoto(_:)` with a `FakeCapturedPhoto`.
final class FakePhotoCapturing: PhotoCapturing, @unchecked Sendable {
    private(set) var captureCalls: Int = 0
    private(set) var lastDelegate: AVCapturePhotoCaptureDelegate?

    func capture(
        with _: AVCapturePhotoSettings,
        delegate: AVCapturePhotoCaptureDelegate
    ) {
        captureCalls += 1
        lastDelegate = delegate
    }
}
