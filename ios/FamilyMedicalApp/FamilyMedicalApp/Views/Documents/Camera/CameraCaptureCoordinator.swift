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
}
