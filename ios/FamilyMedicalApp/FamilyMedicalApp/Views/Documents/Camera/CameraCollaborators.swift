import AVFoundation
import Foundation

// MARK: - AuthorizationStatusProviding

/// Wraps `AVCaptureDevice` authorization APIs so the coordinator can be
/// unit-tested without touching shared system state.
protocol AuthorizationStatusProviding: Sendable {
    func currentStatus() -> AVAuthorizationStatus
    func requestAccess() async -> Bool
}

struct LiveAuthorizationStatusProvider: AuthorizationStatusProviding {
    func currentStatus() -> AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .video)
    }

    func requestAccess() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .video)
    }
}

// MARK: - PhotoCapturing

/// Wraps `AVCapturePhotoOutput.capturePhoto(with:delegate:)` so tests can
/// drive the capture callback without a running session.
protocol PhotoCapturing: AnyObject {
    func capture(
        with settings: AVCapturePhotoSettings,
        delegate: AVCapturePhotoCaptureDelegate
    )
}

extension AVCapturePhotoOutput: PhotoCapturing {
    func capture(
        with settings: AVCapturePhotoSettings,
        delegate: AVCapturePhotoCaptureDelegate
    ) {
        capturePhoto(with: settings, delegate: delegate)
    }
}

// MARK: - ThermalStateProviding

/// Wraps `ProcessInfo.thermalState` and its notification so the coordinator
/// can react to hot devices deterministically in tests.
protocol ThermalStateProviding: Sendable {
    var thermalState: ProcessInfo.ThermalState { get }
    func addObserver(
        _ handler: @escaping @Sendable (ProcessInfo.ThermalState) -> Void
    ) -> NSObjectProtocol
}

final class LiveThermalStateProvider: ThermalStateProviding {
    var thermalState: ProcessInfo.ThermalState {
        ProcessInfo.processInfo.thermalState
    }

    func addObserver(
        _ handler: @escaping @Sendable (ProcessInfo.ThermalState) -> Void
    ) -> NSObjectProtocol {
        NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            handler(ProcessInfo.processInfo.thermalState)
        }
    }
}

// MARK: - SessionController

/// Wraps the subset of `AVCaptureSession` the coordinator actually drives.
/// Tests use a fake to observe `start()`/`stop()`/`swapCameraPosition()`/
/// `setFocusPoint(_:)` calls without running a real session.
protocol SessionController: AnyObject {
    var isRunning: Bool { get }
    func start()
    func stop()
    /// Swap the current camera input to the opposite position. No-op if
    /// the opposite camera is unavailable.
    func swapCameraPosition()
    /// Set the focus + exposure point of interest in normalized device
    /// coordinates (0,0 is top-left, 1,1 is bottom-right).
    func setFocusPoint(_ point: CGPoint)
}

// MARK: - LiveSessionController

/// Real AVFoundation implementation of `SessionController`. All session
/// mutation happens on a dedicated serial queue per Apple's guidance.
final class LiveSessionController: SessionController, @unchecked Sendable {
    private let session: AVCaptureSession
    private let photoOutput: AVCapturePhotoOutput
    private let sessionQueue: DispatchQueue
    private var currentPosition: AVCaptureDevice.Position = .back

    var isRunning: Bool {
        session.isRunning
    }

    init(
        session: AVCaptureSession,
        photoOutput: AVCapturePhotoOutput,
        sessionQueue: DispatchQueue
    ) {
        self.session = session
        self.photoOutput = photoOutput
        self.sessionQueue = sessionQueue
    }

    func configure(initialPosition position: AVCaptureDevice.Position) {
        sessionQueue.async { [self] in
            session.beginConfiguration()
            defer { session.commitConfiguration() }
            if session.canAddOutput(photoOutput) {
                session.addOutput(photoOutput)
            }
            installInput(for: position)
            currentPosition = position
        }
    }

    func start() {
        sessionQueue.async { [session] in
            if !session.isRunning { session.startRunning() }
        }
    }

    func stop() {
        sessionQueue.async { [session] in
            if session.isRunning { session.stopRunning() }
        }
    }

    func swapCameraPosition() {
        sessionQueue.async { [self] in
            let newPosition: AVCaptureDevice.Position = currentPosition == .back ? .front : .back
            session.beginConfiguration()
            defer { session.commitConfiguration() }
            for input in session.inputs {
                session.removeInput(input)
            }
            installInput(for: newPosition)
            currentPosition = newPosition
        }
    }

    func setFocusPoint(_ point: CGPoint) {
        sessionQueue.async { [self] in
            guard let device = (session.inputs.first as? AVCaptureDeviceInput)?.device else { return }
            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }
                if device.isFocusPointOfInterestSupported, device.isFocusModeSupported(.autoFocus) {
                    device.focusPointOfInterest = point
                    device.focusMode = .autoFocus
                }
                if device.isExposurePointOfInterestSupported, device.isExposureModeSupported(.autoExpose) {
                    device.exposurePointOfInterest = point
                    device.exposureMode = .autoExpose
                }
            } catch {
                // Best-effort focus; a failure here just means the tap didn't
                // lock focus on that point. The continuous autofocus still runs.
            }
        }
    }

    private func installInput(for position: AVCaptureDevice.Position) {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position)
            ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
            ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
        else { return }
        configureDeviceDefaults(device)
        guard let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) else { return }
        session.addInput(input)
    }

    private func configureDeviceDefaults(_ device: AVCaptureDevice) {
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            if device.isAutoFocusRangeRestrictionSupported {
                device.autoFocusRangeRestriction = .none
            }
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
        } catch {
            // Best-effort — fall back to the device's current defaults.
        }
    }
}
