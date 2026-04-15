import AVFoundation
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// SwiftUI assembly of the custom camera screen.
///
/// Binds to a `CameraCaptureController` and renders one of seven states:
/// live preview + chrome, post-capture confirm sheet, permission denied,
/// camera unavailable, interrupted overlay, capture failed, or a neutral
/// black background while the system permission dialog is up. The
/// `onPhotoCaptured` callback fires exactly once with the encoded `Data`
/// + `UTType` when the user taps "Use Photo".
struct CameraCaptureView: View {
    // Stored lazily: SwiftUI evaluates `@State` default expressions at
    // struct-construction time, so a non-optional `CameraCaptureController()`
    // default would stand up a live `AVCaptureSession` every time the view
    // struct is initialised — including from any test that constructs a
    // `CameraCaptureView(...)` or, transitively, any code path that builds
    // the view before it is mounted. On the iOS simulator, spinning up a
    // real session triggers `FigCaptureSourceSimulator` signalling that
    // deadlocks the `@MainActor` Swift Testing runner and hangs the test
    // suite indefinitely. Constructing inside `.task` defers session
    // creation to actual view mount, so inspection and unit-test paths
    // never touch AVFoundation.
    @State private var controller: CameraCaptureController?
    @State private var focusSquareLocation: CGPoint?
    /// Tracks the previous coordinator state's case-kind so the `.onChange`
    /// handler can recognise specific transitions (running→capturing,
    /// capturing→captured) for VoiceOver announcements without needing
    /// `CameraCaptureCoordinator.State` to be `Equatable` (its associated
    /// values include `Error`, which isn't).
    @State private var lastAnnouncedStateKind: StateKind?

    /// Coarse-grained tag for `CameraCaptureCoordinator.State` used only
    /// to drive VoiceOver-announcement edge detection.
    private enum StateKind {
        case notDetermined, running, capturing, captured, interrupted, denied, unavailable, failed
    }

    private func kind(of state: CameraCaptureCoordinator.State) -> StateKind {
        switch state {
        case .notDetermined: .notDetermined
        case .running: .running
        case .capturing: .capturing
        case .captured: .captured
        case .interrupted: .interrupted
        case .permissionDenied: .denied
        case .cameraUnavailable: .unavailable
        case .failed: .failed
        }
    }

    @Environment(\.scenePhase)
    private var scenePhase

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    let onPhotoCaptured: (Data, UTType) -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let controller {
                content(controller: controller)
                    .onChange(of: kind(of: controller.coordinator.state)) { _, newKind in
                        announceIfNeeded(newKind: newKind)
                    }
            }
        }
        // Deliberate lazy init. `CameraCaptureController()` creates a real
        // `AVCaptureSession`; constructing it at struct-init time wedges
        // Swift Testing on the simulator's flaky HEVC encoder. See commit
        // 704d8aa and docs/superpowers/specs/2026-04-15-camera-test-hang-research.md.
        .task {
            let active: CameraCaptureController
            if let existing = controller {
                active = existing
            } else {
                active = CameraCaptureController()
                controller = active
            }
            await active.coordinator.start()
        }
        .onChange(of: scenePhase) { _, newPhase in
            handleScenePhase(newPhase)
        }
    }

    /// Emit a VoiceOver announcement for shutter-press and capture-complete
    /// transitions. Accessibility announcements are not suppressed under
    /// reduce-motion: they are an accessibility feature, not a motion effect.
    private func announceIfNeeded(newKind: StateKind) {
        defer { lastAnnouncedStateKind = newKind }
        guard let previous = lastAnnouncedStateKind else { return }
        if previous == .running, newKind == .capturing {
            UIAccessibility.post(notification: .announcement, argument: "Capturing")
        } else if previous == .capturing, newKind == .captured {
            UIAccessibility.post(
                notification: .announcement,
                argument: "Photo captured, ready to use or retake"
            )
        }
    }

    private func handleScenePhase(_ phase: ScenePhase) {
        guard let controller else { return }
        switch phase {
        case .background:
            controller.coordinator.applicationDidEnterBackground()
        case .active:
            Task { @MainActor in
                await controller.coordinator.applicationWillEnterForeground()
            }
        default:
            break
        }
    }

    // MARK: - Content switch

    @ViewBuilder
    private func content(controller: CameraCaptureController) -> some View {
        switch controller.coordinator.state {
        case .notDetermined:
            Color.black.ignoresSafeArea()
        case .capturing, .running:
            liveCapture(controller: controller)
        case let .captured(data, type):
            confirmSheet(controller: controller, data: data, type: type)
        case .interrupted:
            messageScreen(
                icon: "pause.circle",
                title: "Camera paused",
                subtitle: "Resuming when available",
                dismissAction: onCancel
            )
        case .permissionDenied:
            deniedScreen
        case .cameraUnavailable:
            messageScreen(icon: "camera.slash", title: "Camera not available on this device", dismissAction: onCancel)
        case let .failed(error):
            failedScreen(controller: controller, error: error)
        }
    }

    // MARK: - Live capture

    private func liveCapture(controller: CameraCaptureController) -> some View {
        ZStack {
            CameraPreviewView(previewLayer: controller.previewLayer)
                .ignoresSafeArea()
                .gesture(
                    SpatialTapGesture()
                        .onEnded { value in
                            handleFocusTap(controller: controller, at: value.location)
                        }
                )
                .simultaneousGesture(
                    TapGesture(count: 2)
                        .onEnded {
                            handleDoubleTapReset(controller: controller)
                        }
                )
            if let point = focusSquareLocation {
                Rectangle()
                    .strokeBorder(Color.yellow, lineWidth: 2)
                    .frame(width: 80, height: 80)
                    .position(point)
                    .allowsHitTesting(false)
            }
            captureChrome(controller: controller)
        }
    }

    private func captureChrome(controller: CameraCaptureController) -> some View {
        VStack {
            HStack {
                Button("Cancel", action: onCancel)
                    .foregroundStyle(.white)
                    .padding()
                    .accessibilityLabel("Cancel")
                Spacer()
            }
            Spacer()
            HStack(spacing: 40) {
                Spacer()
                shutterButton(controller: controller)
                Spacer()
                Button {
                    controller.coordinator.flipCamera()
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath.camera")
                        .font(.title)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Switch camera")
            }
            .padding(.bottom, 40)
        }
    }

    private func shutterButton(controller: CameraCaptureController) -> some View {
        Button {
            if !reduceMotion {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
            controller.coordinator.capturePhoto()
        } label: {
            ZStack {
                Circle().stroke(Color.white, lineWidth: 4).frame(width: 72, height: 72)
                Circle().fill(Color.white).frame(width: 58, height: 58)
            }
            .frame(minWidth: 44, minHeight: 44)
        }
        .accessibilityLabel("Take photo")
    }

    private func handleFocusTap(controller: CameraCaptureController, at location: CGPoint) {
        let devicePoint = controller.previewLayer.captureDevicePointConverted(fromLayerPoint: location)
        controller.coordinator.focus(at: devicePoint)
        guard !reduceMotion else { return }
        withAnimation(.easeOut(duration: 0.25)) { focusSquareLocation = location }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 600_000_000)
            withAnimation(.easeIn(duration: 0.15)) { focusSquareLocation = nil }
        }
    }

    private func handleDoubleTapReset(controller: CameraCaptureController) {
        controller.coordinator.resetFocus()
        if reduceMotion {
            focusSquareLocation = nil
        } else {
            withAnimation(.easeIn(duration: 0.15)) { focusSquareLocation = nil }
        }
    }

    // MARK: - Confirm sheet

    private func confirmSheet(
        controller: CameraCaptureController,
        data: Data,
        type _: UTType
    ) -> some View {
        ZStack {
            Color.black.ignoresSafeArea()
            // Display-only decode. The original `data` is authoritative and
            // flows untouched through `onPhotoCaptured` — NEVER pass pixels
            // from this `UIImage` back into the capture path.
            if let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .ignoresSafeArea()
            } else {
                Color.black.overlay(
                    Text("Preview unavailable").foregroundStyle(.white)
                )
            }
            VStack {
                Spacer()
                HStack(spacing: 40) {
                    Button("Retake") {
                        controller.coordinator.retake()
                    }
                    .accessibilityLabel("Retake")
                    .buttonStyle(.bordered)
                    .tint(.white)

                    Button("Use Photo") {
                        if let confirmed = controller.coordinator.confirm() {
                            onPhotoCaptured(confirmed.0, confirmed.1)
                        }
                    }
                    .accessibilityLabel("Use photo")
                    .buttonStyle(.borderedProminent)
                }
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Error / denied / unavailable

    private var deniedScreen: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.circle")
                .font(.system(size: 64))
                .foregroundStyle(.white)
            Text("Camera access denied")
                .font(.headline)
                .foregroundStyle(.white)
            Text("Enable camera access in Settings to take photos for medical records.")
                .font(.body)
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .accessibilityLabel("Open Settings")
            .buttonStyle(.borderedProminent)
            Button("Cancel", action: onCancel)
                .foregroundStyle(.white)
        }
    }

    private func failedScreen(controller: CameraCaptureController, error: Error) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 64))
                .foregroundStyle(.white)
            Text("Couldn't capture photo")
                .font(.headline)
                .foregroundStyle(.white)
            Text(error.localizedDescription)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("Retry") {
                Task { await controller.coordinator.start() }
            }
            .buttonStyle(.borderedProminent)
            Button("Cancel", action: onCancel)
                .foregroundStyle(.white)
        }
    }

    private func messageScreen(
        icon: String,
        title: String,
        subtitle: String? = nil,
        dismissAction: (() -> Void)? = nil
    ) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 64))
                .foregroundStyle(.white)
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
            }
            if let dismissAction {
                Button("Dismiss", action: dismissAction)
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}
