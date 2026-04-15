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
    /// RAII box holding the `NotificationCenter` observer tokens registered
    /// in `subscribeToSessionNotifications()`. Releasing the box unregisters
    /// every token — block-based observers are retained by the center and
    /// leak if not explicitly removed. Parallels the `ThermalObserverBox`
    /// pattern in `CameraCaptureCoordinator`: wrapping the tokens in an
    /// `@unchecked Sendable` class lets ARC clean them up off-main without
    /// forcing `MainActor.assumeIsolated` in `deinit`.
    private var notificationObserverBox: SessionNotificationObserverBox?

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
        var tokens: [NSObjectProtocol] = []
        tokens.append(center.addObserver(
            forName: AVCaptureSession.wasInterruptedNotification,
            object: session,
            queue: .main
        ) { [weak self] notification in
            let reason = (notification.userInfo?[AVCaptureSessionInterruptionReasonKey] as? Int)
                .flatMap(AVCaptureSession.InterruptionReason.init(rawValue:))
            Task { @MainActor [weak self] in
                self?.coordinator.handleInterruption(began: true, reason: reason)
            }
        })
        tokens.append(center.addObserver(
            forName: AVCaptureSession.interruptionEndedNotification,
            object: session,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.coordinator.handleInterruption(began: false)
            }
        })
        tokens.append(center.addObserver(
            forName: AVCaptureSession.runtimeErrorNotification,
            object: session,
            queue: .main
        ) { [weak self] notification in
            let error = (notification.userInfo?[AVCaptureSessionErrorKey] as? AVError)
                ?? AVError(.unknown)
            Task { @MainActor [weak self] in
                self?.coordinator.handleRuntimeError(error)
            }
        })
        notificationObserverBox = SessionNotificationObserverBox(tokens: tokens)
    }
}

// MARK: - SessionNotificationObserverBox

/// RAII wrapper for the `CameraCaptureController`'s AVCaptureSession
/// notification tokens. Its `deinit` removes every observer from
/// `NotificationCenter.default`, so dropping the box is enough to clean up
/// the subscriptions when the controller deallocates.
///
/// `@unchecked Sendable` is safe here because the wrapped tokens are
/// immutable `NSObjectProtocol` references after init, the array is never
/// mutated, and `NotificationCenter.removeObserver` is documented
/// thread-safe. This lets ARC release the controller (and therefore the
/// box) off-main without forcing `MainActor.assumeIsolated` in the
/// controller's own `deinit`. Mirrors `ThermalObserverBox` in
/// `CameraCaptureCoordinator.swift`.
private final class SessionNotificationObserverBox: @unchecked Sendable {
    private let tokens: [NSObjectProtocol]

    init(tokens: [NSObjectProtocol]) {
        self.tokens = tokens
    }

    deinit {
        let center = NotificationCenter.default
        for token in tokens {
            center.removeObserver(token)
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
        // Extract the on-disk bytes ONCE. AVCapturePhoto does not cache
        // fileDataRepresentation(), so touching `photo.fileData` and
        // `photo.uniformType` separately would materialize the buffer twice.
        let data = photo.fileDataRepresentation()
        let type = Self.sniffType(data: data)
        let capturedError = error
        Task { @MainActor [weak self] in
            if let capturedError {
                self?.coordinator.handleRuntimeError(capturedError)
            } else {
                self?.coordinator.handlePhoto(ExtractedCapturedPhoto(fileData: data, uniformType: type))
            }
        }
    }

    /// Detect HEIC vs JPEG from the magic bytes of an already-cached buffer.
    /// Kept `nonisolated static` so the delegate callback (which is itself
    /// nonisolated) can call it without actor hops.
    nonisolated static func sniffType(data: Data?) -> UTType {
        guard let data, data.count >= 12 else { return .jpeg }
        if data[0] == 0xFF, data[1] == 0xD8, data[2] == 0xFF { return .jpeg }
        if data[4] == 0x66, data[5] == 0x74, data[6] == 0x79, data[7] == 0x70 { return .heic }
        return .jpeg
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
