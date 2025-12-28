import Foundation

/// Log subsystem categories for structured logging
///
/// Each category represents a major functional area of the app
/// and appears in Console.app for filtering and debugging.
enum LogCategory: String, CaseIterable, Sendable {
    /// Authentication and user account management
    case auth

    /// Cryptographic operations and key management
    case crypto

    /// Local storage and data persistence
    case storage

    /// Cross-device synchronization
    case sync

    /// User interface and view operations
    case ui
}
