import CoreGraphics
import Foundation
import ImageIO
import UIKit
import UniformTypeIdentifiers

/// Generates tiny valid HEIC and JPEG byte blobs at test-run time.
///
/// We deliberately do NOT commit binary fixtures:
/// 1. No EXIF/GPS/camera-identity leak risk.
/// 2. No git-LFS pressure on a privacy-conscious repo.
/// 3. The HMAC-equality test holds regardless of whether the bytes come
///    from a committed file or a generator — the invariant is
///    "input bytes == stored bytes", not "input bytes match a golden file".
enum SyntheticPhotoFixtures {
    /// 50×50 solid-color HEIC encoded by ImageIO.
    static func heicData(color: UIColor = .systemBlue) -> Data {
        encode(color: color, type: UTType.heic.identifier as CFString)
    }

    /// 50×50 solid-color JPEG encoded by ImageIO.
    static func jpegData(color: UIColor = .systemGreen) -> Data {
        encode(color: color, type: UTType.jpeg.identifier as CFString)
    }

    private static func encode(color: UIColor, type: CFString) -> Data {
        let size = CGSize(width: 50, height: 50)
        let renderer = UIGraphicsImageRenderer(size: size)
        let uiImage = renderer.image { ctx in
            color.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
        guard let cgImage = uiImage.cgImage else {
            fatalError("SyntheticPhotoFixtures: could not produce CGImage")
        }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, type, 1, nil) else {
            fatalError("SyntheticPhotoFixtures: CGImageDestinationCreateWithData failed for \(type)")
        }
        CGImageDestinationAddImage(destination, cgImage, nil)
        guard CGImageDestinationFinalize(destination) else {
            fatalError("SyntheticPhotoFixtures: CGImageDestinationFinalize failed for \(type)")
        }
        return output as Data
    }
}
