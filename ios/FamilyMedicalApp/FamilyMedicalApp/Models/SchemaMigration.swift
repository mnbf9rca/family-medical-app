import Foundation

/// Defines a migration between schema versions
///
/// A schema migration describes how to transform records from one schema version
/// to another. It contains a list of field transformations that will be applied
/// to each record's content.
///
/// **Usage:**
/// ```swift
/// let migration = SchemaMigration(
///     schemaId: "custom-lab-results",
///     fromVersion: 1,
///     toVersion: 2,
///     transformations: [
///         .typeConvert(fieldId: "bloodPressure", toType: .int),
///         .remove(fieldId: "obsoleteField")
///     ]
/// )
/// ```
struct SchemaMigration: Codable, Equatable, Identifiable, Hashable {
    // MARK: - Properties

    /// Unique identifier for this migration
    let id: UUID

    /// The schema this migration applies to
    let schemaId: String

    /// The source schema version
    let fromVersion: Int

    /// The target schema version
    let toVersion: Int

    /// The transformations to apply to each record
    let transformations: [FieldTransformation]

    /// When this migration was created
    let createdAt: Date

    // MARK: - Initialization

    /// Initialize a new schema migration
    ///
    /// - Parameters:
    ///   - id: Unique identifier (defaults to new UUID)
    ///   - schemaId: The schema this migration applies to
    ///   - fromVersion: The source schema version
    ///   - toVersion: The target schema version
    ///   - transformations: The transformations to apply
    ///   - createdAt: When this migration was created (defaults to now)
    /// - Throws: ModelError if validation fails
    init(
        id: UUID = UUID(),
        schemaId: String,
        fromVersion: Int,
        toVersion: Int,
        transformations: [FieldTransformation],
        createdAt: Date = Date()
    ) throws {
        self.id = id
        self.schemaId = schemaId
        self.fromVersion = fromVersion
        self.toVersion = toVersion
        self.transformations = transformations
        self.createdAt = createdAt

        try validate()
    }

    // MARK: - Validation

    /// Validate the migration configuration
    ///
    /// - Throws: ModelError if validation fails
    func validate() throws {
        guard !schemaId.isEmpty else {
            throw ModelError.validationFailed(fieldName: "schemaId", reason: "Schema ID cannot be empty")
        }

        guard fromVersion >= 0 else {
            throw ModelError.validationFailed(fieldName: "fromVersion", reason: "From version must be non-negative")
        }

        guard toVersion > fromVersion else {
            throw ModelError.validationFailed(
                fieldName: "toVersion",
                reason: "To version must be greater than from version"
            )
        }

        guard !transformations.isEmpty else {
            throw ModelError.validationFailed(
                fieldName: "transformations",
                reason: "Migration must have at least one transformation"
            )
        }

        // Validate each transformation
        for transformation in transformations {
            try transformation.validate()
        }

        // Check for duplicate field IDs across transformations
        var seenFieldIds: Set<String> = []
        for transformation in transformations {
            for fieldId in transformation.affectedFieldIds {
                if seenFieldIds.contains(fieldId) {
                    throw ModelError.validationFailed(
                        fieldName: "transformations",
                        reason: "Field '\(fieldId)' appears in multiple transformations"
                    )
                }
                seenFieldIds.insert(fieldId)
            }
        }
    }

    // MARK: - Computed Properties

    /// Returns true if this migration contains any type conversions
    var hasTypeConversions: Bool {
        transformations.contains { $0.isTypeConversion }
    }

    /// Returns true if this migration contains any merge transformations
    var hasMerges: Bool {
        transformations.contains { $0.isMerge }
    }

    /// Returns all field IDs affected by this migration
    var affectedFieldIds: Set<String> {
        Set(transformations.flatMap(\.affectedFieldIds))
    }
}
