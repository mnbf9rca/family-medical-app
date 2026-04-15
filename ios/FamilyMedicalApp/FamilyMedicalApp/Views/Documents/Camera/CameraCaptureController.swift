import AVFoundation
import Foundation
import UIKit

/// Owns the real `AVCaptureSession`, its input/output, and the live
/// collaborator implementations. Constructs a `CameraCaptureCoordinator`
/// with those collaborators and exposes it for the SwiftUI view to bind to.
///
/// This is the only file in the capture pipeline that imports the full
/// AVFoundation surface area — `CameraCaptureCoordinator` is pure logic
/// behind four injected protocols, and carries the ≥85% per-file coverage
/// threshold. This file is mostly initialization and notification wiring
/// that is not reachable from the simulator; coverage on it is intentionally
/// not targeted.
@MainActor
final class CameraCaptureController: NSObject {
    let coordinator: CameraCaptureCoordinator
    let previewLayer: AVCaptureVideoPreviewLayer

    private let session: AVCaptureSession
    private let photoOutput: AVCapturePhotoOutput
    private let sessionQueue: DispatchQueue
    private let liveSession: LiveSessionController
    /// Drives `AVCaptureConnection.videoRotationAngle` at capture time so
    /// the HEIC/JPEG pixels match the UI orientation. iOS 17+ replacement
    /// for the deprecated `videoOrientation`. Optional because simulators
    /// and devices without a camera have no `AVCaptureDevice` to bind to.
    private let rotationCoordinator: AVCaptureDevice.RotationCoordinator?

    override init() {
        let session = AVCaptureSession()
        session.sessionPreset = .photo

        let photoOutput = AVCapturePhotoOutput()
        photoOutput.maxPhotoQualityPrioritization = .quality

        let sessionQueue = DispatchQueue(label: "camera.session.queue")
        let liveSession = LiveSessionController(
            session: session,
            photoOutput: photoOutput,
            sessionQueue: sessionQueue
        )

        self.session = session
        self.photoOutput = photoOutput
        self.sessionQueue = sessionQueue
        self.liveSession = liveSession
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill

        // The rotation coordinator needs the physical `AVCaptureDevice`
        // plus the preview layer. `LiveSessionController.installInput`
        // discovers the device asynchronously on the session queue, so we
        // resolve it here instead for the coordinator binding. This is
        // only observed from the main actor.
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
            ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) {
            rotationCoordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: previewLayer)
        } else {
            rotationCoordinator = nil
        }

        // `forwarder` breaks the chicken-and-egg: the coordinator needs a
        // `PhotoCapturing` at init, and the capturer needs `self`. The
        // forwarder is a weak back-reference wired up after `super.init`.
        let forwarder = PhotoCaptureForwarder()
        let availability: @Sendable () -> Bool = { CameraCaptureController.hasAnyCamera }
        coordinator = CameraCaptureCoordinator(
            auth: LiveAuthorizationStatusProvider(),
            capturer: forwarder,
            thermal: LiveThermalStateProvider(),
            session: liveSession,
            cameraAvailable: availability
        )

        super.init()

        forwarder.controller = self
        coordinator.observeThermalState()
        liveSession.configure(initialPosition: .back)
        subscribeToSessionNotifications()
    }

    /// Used by `DocumentPickerView` to decide whether to offer the
    /// "Take Photo" menu item at all. `nonisolated` because
    /// `AVCaptureDevice.default` is thread-safe and the coordinator's
    /// `cameraAvailable` parameter is `@Sendable`.
    nonisolated static var hasAnyCamera: Bool {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil
            || AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) != nil
    }

    fileprivate func performCapture(with settings: AVCapturePhotoSettings) {
        if let angle = rotationCoordinator?.videoRotationAngleForHorizonLevelCapture,
           let connection = photoOutput.connection(with: .video),
           connection.isVideoRotationAngleSupported(angle) {
            connection.videoRotationAngle = angle
        }
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    /// Build `AVCapturePhotoSettings` that explicitly request HEVC when the
    /// `AVCapturePhotoOutput` advertises it (all iPhone 7+ devices). Falls
    /// back to the default JPEG settings otherwise. Called from
    /// `PhotoCaptureForwarder.makeCaptureSettings()`.
    fileprivate func makeCaptureSettingsFromOutput() -> AVCapturePhotoSettings {
        if photoOutput.availablePhotoCodecTypes.contains(.hevc) {
            return AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc.rawValue])
        }
        return AVCapturePhotoSettings()
    }

    private func subscribeToSessionNotifications() {
        let center = NotificationCenter.default
        center.addObserver(
            forName: AVCaptureSession.wasInterruptedNotification,
            object: session,
            queue: .main
        ) { [weak self] notification in
            let reason = (notification.userInfo?[AVCaptureSessionInterruptionReasonKey] as? Int)
                .flatMap(AVCaptureSession.InterruptionReason.init(rawValue:))
            Task { @MainActor [weak self] in
                self?.coordinator.handleInterruption(began: true, reason: reason)
            }
        }
        center.addObserver(
            forName: AVCaptureSession.interruptionEndedNotification,
            object: session,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.coordinator.handleInterruption(began: false)
            }
        }
        center.addObserver(
            forName: AVCaptureSession.runtimeErrorNotification,
            object: session,
            queue: .main
        ) { [weak self] notification in
            let error = (notification.userInfo?[AVCaptureSessionErrorKey] as? AVError)
                ?? AVError(.unknown)
            Task { @MainActor [weak self] in
                self?.coordinator.handleRuntimeError(error)
            }
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraCaptureController: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(
        _: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        // Extract the `Sendable` pieces (Data + UTType + Error) here, before
        // hopping to the main actor. `AVCapturePhoto` itself is not Sendable
        // and must not cross actor boundaries. The bytes from
        // `fileDataRepresentation()` ARE the on-disk file — this is the
        // point where the byte-integrity invariant starts.
        let data = photo.fileData
        let type = photo.uniformType
        let capturedError = error
        Task { @MainActor [weak self] in
            if let capturedError {
                self?.coordinator.handleRuntimeError(capturedError)
            } else {
                self?.coordinator.handlePhoto(ExtractedCapturedPhoto(fileData: data, uniformType: type))
            }
        }
    }
}

// MARK: - ExtractedCapturedPhoto

/// `Sendable` bag that carries the encoded bytes + UTType from the
/// nonisolated delegate callback across to the main-actor coordinator.
/// `AVCapturePhoto` itself is not Sendable, so we extract the only two
/// things we need (the bytes and the format) before crossing actors.
private struct ExtractedCapturedPhoto: CapturedPhoto {
    let fileData: Data?
    let uniformType: UTType
}

// MARK: - PhotoCaptureForwarder

/// Private bridge between the coordinator's `PhotoCapturing` dependency and
/// the controller that owns the `AVCapturePhotoOutput`. This indirection is
/// the minimum the Swift init-ordering rules require — the coordinator
/// needs a `PhotoCapturing` at construction time, but the controller cannot
/// pass `self` to the coordinator until after `super.init`.
///
/// `PhotoCapturing` is `@MainActor`; the forwarder's call runs synchronously
/// on the main actor and reaches the controller's `performCapture(with:)`
/// directly — no `Task` hop.
///
/// Ownership: `CameraCaptureController` → `CameraCaptureCoordinator` →
/// (strong) `PhotoCaptureForwarder` → (weak) `CameraCaptureController`.
/// The weak back-reference is load-bearing — do not make it strong, or the
/// controller will never deallocate.
@MainActor
private final class PhotoCaptureForwarder: PhotoCapturing {
    weak var controller: CameraCaptureController?

    func makeCaptureSettings() -> AVCapturePhotoSettings {
        controller?.makeCaptureSettingsFromOutput() ?? AVCapturePhotoSettings()
    }

    func capture(with settings: AVCapturePhotoSettings) {
        controller?.performCapture(with: settings)
    }
}
