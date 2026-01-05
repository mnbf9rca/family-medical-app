import Foundation

extension UUID {
    /// Sentinel value representing "system" or "built-in" entity (no device identity)
    ///
    /// Used for provenance tracking in built-in schema fields:
    /// - `createdBy: .zero` indicates a field was defined by the app, not a user
    /// - `updatedBy: .zero` indicates a field was last modified by the app
    ///
    /// This is the nil UUID (all zeros): 00000000-0000-0000-0000-000000000000
    ///
    /// Per ADR-0009 (Schema Evolution in Multi-Master Replication):
    /// - User-created fields use the device ID for `createdBy`
    /// - Built-in fields use `.zero` to indicate system origin
    static let zero = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
}
