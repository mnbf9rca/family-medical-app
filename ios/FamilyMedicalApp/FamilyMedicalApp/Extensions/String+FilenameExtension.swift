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
    func appendingCanonicalExtension(forMimeType mimeType: String, fallback: String?) -> String {
        if let type = UTType(mimeType: mimeType),
           let ext = type.preferredFilenameExtension {
            return "\(self).\(ext)"
        }
        if let fallback {
            return "\(self).\(fallback)"
        }
        return self
    }
}
