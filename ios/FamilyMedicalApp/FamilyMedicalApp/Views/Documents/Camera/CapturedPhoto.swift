import Foundation
import UniformTypeIdentifiers

/// Test seam for the bytes produced by `AVCapturePhotoCaptureDelegate`.
///
/// Production uses `ExtractedCapturedPhoto` (in `CameraCaptureController.swift`)
/// which is built from the already-cached `fileDataRepresentation()` buffer.
/// Tests inject `FakeCapturedPhoto` to drive the capture-success path with
/// synthetic bytes.
protocol CapturedPhoto {
    /// The encoded file bytes the hardware pipeline produced.
    /// Returning `nil` models the documented AVFoundation case where
    /// `fileDataRepresentation()` fails (thermal shutdown, lens obscured
    /// at the exact wrong moment, etc).
    var fileData: Data? { get }

    /// The UTType corresponding to the encoded bytes — `.heic` when the
    /// capture used HEVC, `.jpeg` otherwise.
    var uniformType: UTType { get }
}
