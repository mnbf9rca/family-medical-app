import AVFoundation
import SwiftUI
import UIKit

/// Hosts a `CameraCaptureController`'s `AVCaptureVideoPreviewLayer`
/// inside SwiftUI. Intentionally minimal — no state, no logic.
struct CameraPreviewView: UIViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer

    func makeUIView(context _: Context) -> PreviewContainer {
        let view = PreviewContainer()
        view.backgroundColor = .black
        view.layer.addSublayer(previewLayer)
        return view
    }

    func updateUIView(_ uiView: PreviewContainer, context _: Context) {
        previewLayer.frame = uiView.bounds
    }

    final class PreviewContainer: UIView {
        override func layoutSubviews() {
            super.layoutSubviews()
            for sub in layer.sublayers ?? [] {
                sub.frame = bounds
            }
        }
    }
}
