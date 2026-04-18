import Foundation

extension String? {
    /// Return the receiver trimmed of leading/trailing whitespace and newlines,
    /// or `nil` if the trimmed result is empty (or the receiver was already `nil`).
    ///
    /// Backup decoders use this to coerce strings that round-tripped through JSON
    /// — where `nil`, `""`, and `"   "` all mean "no value" — back into the
    /// canonical absent-value representation (`nil`) before feeding them into
    /// model initializers that treat empty strings differently from absent ones.
    func trimmedNonEmpty() -> String? {
        guard let trimmed = self?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}
