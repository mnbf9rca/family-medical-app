import AVFoundation
import Foundation
import Observation
import UniformTypeIdentifiers

/// Pure-logic state machine and orchestrator for camera capture.
///
/// Holds no AVFoundation objects directly — all side effects go through
/// the four injected collaborators. This is the file the 85% per-file
/// coverage threshold applies to; `CameraCaptureController.swift` is the
/// thin AVFoundation glue layer that is mostly uncoverable in the simulator.
@MainActor
@Observable
final class CameraCaptureCoordinator {
    // MARK: - State

    enum State {
        case notDetermined
        case permissionDenied
        case cameraUnavailable
        case running
        case capturing
        case captured(Data, UTType)
        case interrupted
        case failed(Error)
    }

    private(set) var state: State

    // MARK: - Dependencies

    @ObservationIgnored private let auth: AuthorizationStatusProviding
    @ObservationIgnored private let capturer: PhotoCapturing
    @ObservationIgnored private let thermal: ThermalStateProviding
    @ObservationIgnored private let session: SessionController
    @ObservationIgnored private let cameraAvailable: @Sendable () -> Bool

    // MARK: - Init

    init(
        auth: AuthorizationStatusProviding,
        capturer: PhotoCapturing,
        thermal: ThermalStateProviding,
        session: SessionController,
        cameraAvailable: @escaping @Sendable () -> Bool
    ) {
        self.auth = auth
        self.capturer = capturer
        self.thermal = thermal
        self.session = session
        self.cameraAvailable = cameraAvailable
        // Derive the initial state from the authorization provider without
        // touching the camera hardware. `start()` is the method that actually
        // requests access and moves the machine forward.
        switch auth.currentStatus() {
        case .notDetermined: self.state = .notDetermined
        case .denied, .restricted: self.state = .permissionDenied
        case .authorized: self.state = cameraAvailable() ? .running : .cameraUnavailable
        @unknown default: self.state = .permissionDenied
        }
    }

    // MARK: - Lifecycle

    /// Resolve permissions, and if allowed, start the underlying session.
    /// Safe to call repeatedly; a no-op when already running.
    func start() async {
        switch auth.currentStatus() {
        case .notDetermined:
            let granted = await auth.requestAccess()
            if granted, cameraAvailable() {
                session.start()
                state = .running
            } else {
                state = .permissionDenied
            }
        case .denied, .restricted:
            state = .permissionDenied
        case .authorized:
            guard cameraAvailable() else {
                state = .cameraUnavailable
                return
            }
            session.start()
            state = .running
        @unknown default:
            state = .permissionDenied
        }
    }

    // MARK: - Errors

    enum CameraError: Error {
        case photoDataUnavailable
        case captureFailed(underlying: Error)
    }

    // MARK: - Capture

    /// User tapped the shutter. Transitions `.running → .capturing` and fires
    /// the capture; the delegate callback will invoke `handlePhoto(_:)` on us
    /// via `CameraCaptureController`.
    func capturePhoto() {
        guard case .running = state else { return }
        state = .capturing
        let settings = AVCapturePhotoSettings()
        // Delegate is owned by `CameraCaptureController`, which forwards the
        // call back into `handlePhoto` — the coordinator does not conform to
        // AVCapturePhotoCaptureDelegate directly, to keep this file free of
        // AVFoundation-specific delegate boilerplate.
        capturer.capture(with: settings, delegate: PhotoDelegateBridge.shared)
    }

    /// Called from the glue layer when `didFinishProcessingPhoto` fires.
    /// This is where the byte-integrity invariant is enforced: the `Data`
    /// that arrives here is the same `Data` that leaves via `onPhotoCaptured`
    /// from the view, and the same `Data` that `DocumentBlobService` will
    /// HMAC and encrypt.
    func handlePhoto(_ photo: CapturedPhoto) {
        guard let data = photo.fileData else {
            state = .failed(CameraError.photoDataUnavailable)
            return
        }
        state = .captured(data, photo.uniformType)
    }

    /// Throw away the current captured photo and return to live preview.
    func retake() {
        guard case .captured = state else { return }
        state = .running
    }

    /// Swap front/back camera. Valid only from `.running`.
    func flipCamera() {
        guard case .running = state else { return }
        session.swapCameraPosition()
    }

    /// Return the captured `(Data, UTType)` if there is one, else nil.
    /// The caller is responsible for forwarding to `onPhotoCaptured`.
    func confirm() -> (Data, UTType)? {
        guard case let .captured(data, type) = state else { return nil }
        return (data, type)
    }
}

/// Placeholder delegate. Not actually invoked in tests because
/// `FakePhotoCapturing.capture` never calls back. `CameraCaptureController`
/// provides the real delegate in production.
///
/// The singleton is stateless — AVCapturePhotoCaptureDelegate methods are
/// never called on this instance in the coordinator's own code path — so
/// `@unchecked Sendable` is safe.
private final class PhotoDelegateBridge: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    static let shared = PhotoDelegateBridge()
}
