import AVFoundation
import Foundation
import UniformTypeIdentifiers

/// Test seam for the bytes produced by `AVCapturePhotoCaptureDelegate`.
///
/// Production uses the `AVCapturePhoto` conformance below; tests inject
/// `FakeCapturedPhoto` to drive the capture-success path with synthetic
/// bytes. The coordinator never touches `AVCapturePhoto` directly — that
/// is the whole point of this protocol.
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

extension AVCapturePhoto: CapturedPhoto {
    var fileData: Data? {
        fileDataRepresentation()
    }

    /// Detects the encoded format by sniffing the file's magic bytes.
    /// JPEG files always begin with `FF D8 FF`; HEIF/HEIC files have an
    /// `ftyp` box at offset 4. This avoids depending on AVFoundation's
    /// resolved-settings codec API, which is inconsistent across SDK versions.
    var uniformType: UTType {
        guard let data = fileDataRepresentation(), data.count >= 12 else { return .jpeg }
        // JPEG: FF D8 FF
        if data[0] == 0xFF, data[1] == 0xD8, data[2] == 0xFF { return .jpeg }
        // HEIF/HEIC: bytes 4–7 are 'ftyp'
        if data[4] == 0x66, data[5] == 0x74, data[6] == 0x79, data[7] == 0x70 { return .heic }
        return .jpeg
    }
}
