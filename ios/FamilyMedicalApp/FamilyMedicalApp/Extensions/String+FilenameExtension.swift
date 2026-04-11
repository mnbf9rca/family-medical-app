import Foundation
import UniformTypeIdentifiers

extension String {
    /// Append the canonical filename extension for `mimeType` to the receiver.
    ///
    /// Apple's UTType registry owns the mapping (`UTType(mimeType:)?.preferredFilenameExtension`),
    /// so the result agrees with whatever iOS would produce for that MIME — e.g. `image/jpeg` →
    /// `jpeg`, `image/heic` → `heic`, `application/pdf` → `pdf`.
    ///
    /// When the MIME cannot be mapped to a concrete extension — unrecognized types, synthetic
    /// `dyn.*` placeholder types (e.g. `image/unknown`), or types whose `preferredFilenameExtension`
    /// is nil — the helper uses `fallback` if provided, otherwise returns the receiver unchanged.
    /// Callers that must produce a file with *some* extension (e.g. for the iOS share sheet) pass
    /// `fallback: "bin"`; callers producing a user-visible display title pass `fallback: nil`.
    ///
    /// The helper is idempotent for the canonical extension: calling it on a string
    /// that already ends with `.<canonicalExtension>` (or `.<fallback>` when the
    /// fallback path is taken) returns the receiver unchanged, so callers can run
    /// the helper safely on strings that may or may not already carry the extension.
    func appendingCanonicalExtension(forMimeType mimeType: String, fallback: String?) -> String {
        let extToAppend: String
        if let type = UTType(mimeType: mimeType),
           let preferred = type.preferredFilenameExtension {
            extToAppend = preferred
        } else if let fallback {
            extToAppend = fallback
        } else {
            return self
        }
        // Idempotence guard: if the receiver already ends with the extension we
        // would append, return it unchanged so the helper does not produce
        // "file.pdf.pdf" when called on a base that already carries the canonical
        // extension for the detected MIME.
        if hasSuffix(".\(extToAppend)") {
            return self
        }
        return "\(self).\(extToAppend)"
    }
}
