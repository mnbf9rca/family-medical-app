import Foundation

/// Errors that can occur during backup export/import operations
enum BackupError: Error, LocalizedError, Equatable {
    /// The provided password is incorrect
    case invalidPassword

    /// The backup file is corrupted or malformed
    case corruptedFile

    /// The checksum doesn't match (file corrupted)
    case checksumMismatch

    /// The backup file version is not supported
    case unsupportedVersion(String)

    /// Export operation failed
    case exportFailed(String)

    /// Import operation failed
    case importFailed(String)

    /// No data to export
    case noDataToExport

    /// Password is too weak (< 8 characters)
    case passwordTooWeak

    /// File read/write error
    case fileOperationFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidPassword:
            "The password is incorrect. Please try again."
        case .corruptedFile:
            "The backup file is corrupted or invalid."
        case .checksumMismatch:
            "The backup file appears to be corrupted (checksum mismatch)."
        case let .unsupportedVersion(version):
            "This backup file version (\(version)) is not supported by this app version."
        case let .exportFailed(reason):
            "Export failed: \(reason)"
        case let .importFailed(reason):
            "Import failed: \(reason)"
        case .noDataToExport:
            "There is no data to export."
        case .passwordTooWeak:
            "Please choose a stronger password (at least 8 characters)."
        case let .fileOperationFailed(reason):
            "File operation failed: \(reason)"
        }
    }
}
