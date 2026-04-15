import Foundation
@testable import FamilyMedicalApp

/// Tiny HEIC and JPEG byte blobs loaded from committed binary fixtures under
/// `FamilyMedicalAppTests/Fixtures/camera/`. Both files are metadata-scrubbed
/// with `exiftool -all=` — no GPS/EXIF/camera-identity data lands in git.
///
/// Previously generated at test-run time via `CGImageDestinationCreateWithData`.
/// That path hit the iOS simulator's flaky HEIC encoder
/// (`CMPhotoCompressionSession` / `hvc1`) and deadlocked Swift Testing when
/// multiple `@MainActor struct` suites called it in parallel. Committed
/// fixtures eliminate the entire class of problems. See
/// `docs/superpowers/specs/2026-04-15-camera-test-hang-research.md`.
enum SyntheticPhotoFixtures {
    static let heicData: Data = loadFixture(name: "sample", extension: "heic")
    static let jpegData: Data = loadFixture(name: "sample", extension: "jpeg")

    private static func loadFixture(name: String, extension ext: String) -> Data {
        let bundle = Bundle(for: FixtureLocator.self)
        guard let url = bundle.url(forResource: name, withExtension: ext) else {
            fatalError("SyntheticPhotoFixtures: \(name).\(ext) not found in test bundle")
        }
        do {
            return try Data(contentsOf: url)
        } catch {
            fatalError("SyntheticPhotoFixtures: failed to load \(name).\(ext): \(error)")
        }
    }
}

/// Empty class solely used as a bundle-locator token for
/// `Bundle(for:)` — it must live in the same test target as the
/// fixtures so `Bundle(for:)` returns the right bundle URL.
private final class FixtureLocator {}
