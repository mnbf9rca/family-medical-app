import Foundation

/// Visibility state for a field in a schema
///
/// Controls whether a field is shown in the UI and how it's treated.
/// This enables soft-delete functionality where fields can be hidden
/// without losing existing data.
///
/// Per ADR-0009 (Schema Evolution in Multi-Master Replication):
/// - Hidden fields keep their data in records
/// - Users can restore hidden fields later
/// - Deprecated fields warn if old records have data
enum FieldVisibility: String, Codable, CaseIterable, Hashable, Sendable {
    /// Normal field, shown in UI for viewing and editing
    case active

    /// Not shown in UI, but data preserved in existing records
    ///
    /// Use this to "remove" a field without losing data.
    /// Hidden fields can be restored to active later.
    case hidden

    /// Hidden from UI with warning if old records have data
    ///
    /// Indicates the field is no longer recommended for use.
    /// When viewing old records with deprecated field data,
    /// the UI may show a warning or migration prompt.
    case deprecated
}
