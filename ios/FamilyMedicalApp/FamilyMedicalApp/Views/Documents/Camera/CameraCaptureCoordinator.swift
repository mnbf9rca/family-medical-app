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
        case interrupted(AVCaptureSession.InterruptionReason?)
        case failed(Error)
    }

    private(set) var state: State

    /// Quality-degradation UI hint set when thermal state goes `.serious` or
    /// above. Observable by the view so it can show a discreet warning.
    private(set) var isQualityDegraded: Bool = false

    @ObservationIgnored private var thermalObserverBox: ThermalObserverBox?

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
    /// the capture. The concrete `PhotoCapturing` implementation owns the
    /// delegate relationship and forwards the resulting photo back into
    /// `handlePhoto(_:)` on the main actor.
    func capturePhoto() {
        guard case .running = state else { return }
        state = .capturing
        let settings = AVCapturePhotoSettings()
        capturer.capture(with: settings)
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

    // MARK: - Interruption / runtime
    //
    // The concrete `CameraCaptureController` subscribes to the relevant
    // `AVCaptureSession` notifications and forwards them here. Splitting it
    // this way keeps the coordinator testable without any real session.

    func handleInterruption(began: Bool, reason: AVCaptureSession.InterruptionReason? = nil) {
        if began {
            switch state {
            case .capturing, .running:
                state = .interrupted(reason)
            default:
                return // ignore interruption from other states
            }
        } else {
            guard case .interrupted = state else { return }
            state = .running
        }
    }

    func handleRuntimeError(_ error: Error) {
        state = .failed(error)
    }

    /// Called by `CameraCaptureController` once — registers the thermal
    /// observer. Separate from `init` so that in unit tests we can construct
    /// the coordinator and then trigger thermal changes via the fake.
    ///
    /// The token is wrapped in a `ThermalObserverBox` whose own `deinit`
    /// unregisters from `NotificationCenter`. This pattern avoids needing a
    /// `MainActor.assumeIsolated` call in the coordinator's `deinit`, which
    /// would trap when ARC releases the coordinator from a non-main thread
    /// (causing hangs in unit-test teardown).
    func observeThermalState() {
        guard thermalObserverBox == nil else { return }
        isQualityDegraded = thermal.thermalState.rawValue >= ProcessInfo.ThermalState.serious.rawValue
        let token = thermal.addObserver { [weak self] newState in
            Task { @MainActor [weak self] in
                self?.isQualityDegraded = newState.rawValue >= ProcessInfo.ThermalState.serious.rawValue
            }
        }
        thermalObserverBox = ThermalObserverBox(token: token)
    }

    // MARK: - Focus

    /// Set the last focus point the user tapped. The view layer observes
    /// `lastFocusPoint` to drive a tap-to-focus animation; the underlying
    /// session sets the focus + exposure point of interest.
    private(set) var lastFocusPoint: CGPoint?

    func focus(at point: CGPoint) {
        lastFocusPoint = point
        session.setFocusPoint(point)
    }

    // MARK: - App lifecycle

    func applicationDidEnterBackground() {
        session.stop()
    }

    func applicationWillEnterForeground() async {
        // Re-evaluate permission and restart the session if we're still
        // allowed. Users can revoke camera access in Settings while the app
        // is backgrounded, so this is a real path, not a belt-and-braces
        // check.
        await start()
    }
}

// MARK: - ThermalObserverBox

/// RAII wrapper for a `NotificationCenter` observer token. Its `deinit`
/// unregisters the observer, so releasing the box is enough to clean up
/// the subscription. `NotificationCenter.removeObserver` is documented
/// as thread-safe, so no actor isolation is required in `deinit`.
private final class ThermalObserverBox: @unchecked Sendable {
    private let token: NSObjectProtocol

    init(token: NSObjectProtocol) {
        self.token = token
    }

    deinit {
        NotificationCenter.default.removeObserver(token)
    }
}
