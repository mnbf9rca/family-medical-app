import Foundation

// MARK: - Migration Options

/// User-selected options for handling migrations
struct MigrationOptions: Codable, Equatable, Hashable, Sendable {
    /// How to combine values when merging fields
    /// Also used when target field has an existing value (treated as first source)
    let mergeStrategy: MergeStrategy

    /// Default options with concatenate
    static let `default` = MigrationOptions(
        mergeStrategy: .concatenate(separator: " ")
    )
}

/// How to combine source field values with an existing target field value
///
/// In a merge operation:
/// - **Source fields**: the fields being merged together
/// - **Target field**: the destination field (may already have a value)
enum MergeStrategy: Codable, Equatable, Hashable, Sendable {
    /// Join string representations with a separator
    case concatenate(separator: String)

    /// Prefer the source value (use first non-empty source field)
    case preferSource

    /// Prefer the target value (keep existing target if present)
    case preferTarget
}

// MARK: - Migration Preview

/// Preview of what a migration will do
struct MigrationPreview: Equatable, Sendable {
    /// Number of records that will be affected
    let recordCount: Int

    /// Sample record ID (for preview purposes)
    let sampleRecordId: UUID?

    /// Warnings about the migration (e.g., "3 records have non-numeric values that will fail conversion")
    let warnings: [String]

    /// Creates an empty preview (no records to migrate)
    static let empty = MigrationPreview(recordCount: 0, sampleRecordId: nil, warnings: [])
}

// MARK: - Migration Progress

/// Progress of an ongoing migration
struct MigrationProgress: Equatable, Sendable {
    /// Total number of records to migrate
    let totalRecords: Int

    /// Number of records already processed
    let processedRecords: Int

    /// ID of the record currently being processed
    let currentRecordId: UUID?

    /// Progress as a fraction (0.0 to 1.0)
    var progress: Double {
        guard totalRecords > 0 else { return 0 }
        return Double(processedRecords) / Double(totalRecords)
    }

    /// Percentage complete (0 to 100)
    var percentComplete: Int {
        Int(progress * 100)
    }
}

// MARK: - Migration Result

/// Result of a completed migration
struct MigrationResult: Equatable, Sendable {
    /// The migration that was executed
    let migration: SchemaMigration

    /// Total number of records processed
    let recordsProcessed: Int

    /// Number of records successfully migrated
    let recordsSucceeded: Int

    /// Number of records that failed migration
    let recordsFailed: Int

    /// Errors encountered during migration
    let errors: [MigrationRecordError]

    /// When the migration started
    let startTime: Date

    /// When the migration completed
    let endTime: Date

    /// Whether the migration was fully successful
    var isSuccess: Bool {
        recordsFailed == 0
    }

    /// Duration of the migration in seconds
    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }
}

/// Error that occurred while migrating a specific record
struct MigrationRecordError: Equatable, Hashable, Sendable {
    /// The record that failed
    let recordId: UUID

    /// The field that caused the error (if applicable)
    let fieldId: String?

    /// Human-readable reason for the failure
    let reason: String
}
