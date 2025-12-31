import Foundation

/// Individual with medical records
///
/// Represents a person whose medical records are being tracked.
/// Note: When stored, name, dateOfBirth, and labels are encrypted with the person's Family Member Key (FMK).
struct Person: Codable, Equatable, Hashable, Identifiable {
    // MARK: - Validation Constants

    static let nameMinLength = 1
    static let nameMaxLength = 100
    static let labelMaxLength = 50

    // MARK: - Plaintext Properties (sync coordination)

    /// Unique identifier for this person
    let id: UUID

    /// When this person record was created
    let createdAt: Date

    /// When this person record was last updated
    var updatedAt: Date

    // MARK: - Encrypted Properties

    /// Name of the person (encrypted when stored)
    var name: String

    /// Date of birth (encrypted when stored)
    var dateOfBirth: Date?

    /// Flexible labels describing roles/relationships (encrypted when stored)
    ///
    /// Examples: ["child", "dependent", "legal-guardian", "lives-with-us"]
    /// - Labels are user-defined and can reflect any dimension: legal, social, caregiving, household
    /// - A person can have multiple labels (e.g., both "child" and "dependent")
    /// - Avoids encoding nuclear-family assumptions
    var labels: [String]

    /// Additional notes about this person (encrypted when stored)
    var notes: String?

    // MARK: - Initialization

    /// Initialize a new person record
    ///
    /// - Parameters:
    ///   - id: Unique identifier (defaults to new UUID)
    ///   - name: Person's name (trimmed, validated for length)
    ///   - dateOfBirth: Optional date of birth
    ///   - labels: Flexible role/relationship labels (validated for content)
    ///   - notes: Optional additional notes
    ///   - createdAt: Creation timestamp (defaults to now)
    ///   - updatedAt: Last update timestamp (defaults to now)
    /// - Throws: ModelError if validation fails
    init(
        id: UUID = UUID(),
        name: String,
        dateOfBirth: Date? = nil,
        labels: [String] = [],
        notes: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) throws {
        // Validate and trim name
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedName.count >= Self.nameMinLength else {
            throw ModelError.nameEmpty
        }
        guard trimmedName.count <= Self.nameMaxLength else {
            throw ModelError.nameTooLong(maxLength: Self.nameMaxLength)
        }

        // Validate labels
        var seenLabels = Set<String>()
        var trimmedLabels: [String] = []
        for label in labels {
            let trimmedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedLabel.isEmpty else {
                throw ModelError.labelEmpty
            }
            guard trimmedLabel.count <= Self.labelMaxLength else {
                throw ModelError.labelTooLong(label: label, maxLength: Self.labelMaxLength)
            }
            // Check for duplicates (case-insensitive)
            let lowercased = trimmedLabel.lowercased()
            if seenLabels.contains(lowercased) {
                throw ModelError.labelTooLong(label: "Duplicate label: \(trimmedLabel)", maxLength: 0)
            }
            seenLabels.insert(lowercased)
            trimmedLabels.append(trimmedLabel)
        }

        self.id = id
        self.name = trimmedName
        self.dateOfBirth = dateOfBirth
        self.labels = trimmedLabels
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // MARK: - Label Helpers

    /// Check if this person has a specific label
    ///
    /// - Parameter label: The label to check for (case-insensitive)
    /// - Returns: true if the label exists, false otherwise
    func hasLabel(_ label: String) -> Bool {
        labels.contains { $0.caseInsensitiveCompare(label) == .orderedSame }
    }

    /// Add a label if it doesn't already exist
    ///
    /// - Parameter label: The label to add (will be trimmed and validated)
    /// - Throws: ModelError if label validation fails
    mutating func addLabel(_ label: String) throws {
        let trimmedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedLabel.isEmpty else {
            throw ModelError.labelEmpty
        }
        guard trimmedLabel.count <= Self.labelMaxLength else {
            throw ModelError.labelTooLong(label: label, maxLength: Self.labelMaxLength)
        }

        // Don't add duplicate labels (case-insensitive check)
        if !hasLabel(trimmedLabel) {
            labels.append(trimmedLabel)
            updatedAt = Date()
        }
    }

    /// Remove a label
    ///
    /// - Parameter label: The label to remove (case-insensitive)
    mutating func removeLabel(_ label: String) {
        let originalCount = labels.count
        labels.removeAll { $0.caseInsensitiveCompare(label) == .orderedSame }
        if labels.count != originalCount {
            updatedAt = Date()
        }
    }

    // MARK: - Common Label Suggestions

    /// Common label suggestions for UI (not constraints - users can use any labels)
    static let commonLabels = [
        "Self",
        "Spouse",
        "Partner",
        "Child",
        "Parent",
        "Sibling",
        "Dependent",
        "Caregiver",
        "Legal Guardian",
        "Household Member"
    ]
}
