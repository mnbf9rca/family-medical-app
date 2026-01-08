import Foundation
@testable import FamilyMedicalApp

/// Shared test helpers for creating Person fixtures across test files.
/// Extracted from HomeViewTests, PersonDetailViewModelTests, PersonRowViewTests.
enum PersonTestHelper {
    /// Creates a test Person with configurable properties.
    ///
    /// - Parameters:
    ///   - id: The person ID. Defaults to a new UUID.
    ///   - name: The person's name. Defaults to "Test Person".
    ///   - dateOfBirth: The date of birth. Defaults to current date.
    ///   - labels: The person's labels. Defaults to ["Self"].
    ///   - notes: Optional notes. Defaults to nil.
    /// - Returns: A test Person instance.
    /// - Throws: If person creation fails validation.
    static func makeTestPerson(
        id: UUID = UUID(),
        name: String = "Test Person",
        dateOfBirth: Date? = Date(),
        labels: [String] = ["Self"],
        notes: String? = nil
    ) throws -> Person {
        try Person(
            id: id,
            name: name,
            dateOfBirth: dateOfBirth,
            labels: labels,
            notes: notes
        )
    }

    /// Creates a test Person with a fixed date of birth for deterministic tests.
    ///
    /// - Parameters:
    ///   - id: The person ID. Defaults to a new UUID.
    ///   - name: The person's name. Defaults to "Test Person".
    ///   - dateOfBirthTimestamp: Unix timestamp for date of birth. Defaults to Jan 1, 1990 (631152000).
    ///   - labels: The person's labels. Defaults to ["Self"].
    ///   - notes: Optional notes. Defaults to nil.
    /// - Returns: A test Person instance with deterministic date.
    /// - Throws: If person creation fails validation.
    static func makeTestPersonDeterministic(
        id: UUID = UUID(),
        name: String = "Test Person",
        dateOfBirthTimestamp: TimeInterval = 631_152_000, // Jan 1, 1990
        labels: [String] = ["Self"],
        notes: String? = nil
    ) throws -> Person {
        try Person(
            id: id,
            name: name,
            dateOfBirth: Date(timeIntervalSince1970: dateOfBirthTimestamp),
            labels: labels,
            notes: notes
        )
    }
}
