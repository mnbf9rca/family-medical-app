import Foundation
import Testing
@testable import FamilyMedicalApp

/// Unit tests for `String.appendingCanonicalExtension(forMimeType:fallback:)`.
///
/// The helper derives a filename from a base name and a detected MIME type. It's used
/// by `DocumentPickerViewModel` to label incoming attachments with the canonical extension
/// for their actual stored format, and by `DocumentViewerViewModel` to produce a temp-file
/// name for the share-sheet export flow (where the file must have *some* extension so iOS
/// picks a sensible default app).
struct StringFilenameExtensionTests {
    // MARK: - fallback: nil (display-title mode)

    @Test
    func appendingExtension_pngMime_appendsPng() {
        let result = "Photo_20260410_143045"
            .appendingCanonicalExtension(forMimeType: "image/png", fallback: nil)
        #expect(result == "Photo_20260410_143045.png")
    }

    @Test
    func appendingExtension_heicMime_appendsHeic() {
        let result = "Photo_20260410_143045"
            .appendingCanonicalExtension(forMimeType: "image/heic", fallback: nil)
        #expect(result == "Photo_20260410_143045.heic")
    }

    @Test
    func appendingExtension_jpegMime_appendsCanonicalJpegExtension() {
        // UTType.jpeg.preferredFilenameExtension is "jpeg", not "jpg".
        let result = "Photo_20260410_143045"
            .appendingCanonicalExtension(forMimeType: "image/jpeg", fallback: nil)
        #expect(result == "Photo_20260410_143045.jpeg")
    }

    @Test
    func appendingExtension_pdfMime_appendsPdf() {
        let result = "lab_results"
            .appendingCanonicalExtension(forMimeType: "application/pdf", fallback: nil)
        #expect(result == "lab_results.pdf")
    }

    @Test
    func appendingExtension_gifMime_appendsGif() {
        let result = "anim"
            .appendingCanonicalExtension(forMimeType: "image/gif", fallback: nil)
        #expect(result == "anim.gif")
    }

    @Test
    func appendingExtension_unrecognizedMime_nilFallback_returnsBaseUnchanged() {
        let result = "Photo_20260410_143045"
            .appendingCanonicalExtension(forMimeType: "application/x-nonexistent", fallback: nil)
        #expect(result == "Photo_20260410_143045")
    }

    @Test
    func appendingExtension_syntheticDynamicMime_nilFallback_returnsBaseUnchanged() {
        // `image/unknown` resolves to a synthetic `dyn.*` UTType whose
        // preferredFilenameExtension is nil. The helper must fall through cleanly rather
        // than producing `Photo_….dyn.xxxxx`.
        let result = "Photo_20260410_143045"
            .appendingCanonicalExtension(forMimeType: "image/unknown", fallback: nil)
        #expect(result == "Photo_20260410_143045")
    }

    @Test
    func appendingExtension_baseAlreadyHasCanonicalExtension_doesNotDoubleAppend() {
        let result = "lab_results.pdf"
            .appendingCanonicalExtension(forMimeType: "application/pdf", fallback: nil)
        #expect(result == "lab_results.pdf")
    }

    @Test
    func appendingExtension_baseHasCanonicalExtensionWithBinFallback_doesNotDoubleAppend() {
        let result = "scan.png"
            .appendingCanonicalExtension(forMimeType: "image/png", fallback: "bin")
        #expect(result == "scan.png")
    }

    // MARK: - fallback: "bin" (share-sheet export mode)

    @Test
    func appendingExtension_pngMime_binFallback_stillAppendsPng() {
        let result = "abc12345"
            .appendingCanonicalExtension(forMimeType: "image/png", fallback: "bin")
        #expect(result == "abc12345.png")
    }

    @Test
    func appendingExtension_unrecognizedMime_binFallback_appendsBin() {
        let result = "abc12345"
            .appendingCanonicalExtension(forMimeType: "application/x-nonexistent", fallback: "bin")
        #expect(result == "abc12345.bin")
    }

    @Test
    func appendingExtension_syntheticDynamicMime_binFallback_appendsBin() {
        let result = "abc12345"
            .appendingCanonicalExtension(forMimeType: "image/unknown", fallback: "bin")
        #expect(result == "abc12345.bin")
    }
}
