import Foundation

/// Decrypted person data for backup
struct PersonBackup: Codable, Equatable {
    let id: UUID
    let name: String
    let dateOfBirth: Date?
    let labels: [String]
    let notes: String?
    let gender: String?
    let bloodType: String?
    let createdAt: Date
    let updatedAt: Date

    /// Convert from decrypted Person model
    init(from person: Person) {
        self.id = person.id
        self.name = person.name
        self.dateOfBirth = person.dateOfBirth
        self.labels = person.labels
        self.notes = person.notes
        self.gender = person.gender
        self.bloodType = person.bloodType
        self.createdAt = person.createdAt
        self.updatedAt = person.updatedAt
    }

    /// Direct initialization
    init(
        id: UUID,
        name: String,
        dateOfBirth: Date?,
        labels: [String],
        notes: String?,
        gender: String? = nil,
        bloodType: String? = nil,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.name = name
        self.dateOfBirth = dateOfBirth
        self.labels = labels
        self.notes = notes
        self.gender = gender
        self.bloodType = bloodType
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Convert back to Person model
    func toPerson() throws -> Person {
        try Person(
            id: id,
            name: name,
            dateOfBirth: dateOfBirth,
            labels: labels,
            notes: notes,
            gender: gender,
            bloodType: bloodType,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
