import Foundation

/// A healthcare provider (person) or facility (organization).
/// At least one of name or organization must be non-nil.
struct Provider: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String?
    var organization: String?
    var specialty: String?
    var phone: String?
    var address: String?
    var notes: String?
    let createdAt: Date
    var updatedAt: Date
    var version: Int
    var previousVersionId: UUID?

    private enum CodingKeys: String, CodingKey {
        case id, name, organization, specialty, phone, address, notes
        case createdAt, updatedAt, version, previousVersionId
    }

    /// Display string: "Name at Organization", or whichever is populated
    var displayString: String {
        switch (name, organization) {
        case let (name?, org?): "\(name) at \(org)"
        case let (name?, nil): name
        case let (nil, org?): org
        case (nil, nil): "Unknown Provider"
        }
    }

    init(
        id: UUID = UUID(),
        name: String? = nil,
        organization: String? = nil,
        specialty: String? = nil,
        phone: String? = nil,
        address: String? = nil,
        notes: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        version: Int = 1,
        previousVersionId: UUID? = nil
    ) {
        precondition(name != nil || organization != nil, "Provider must have name or organization")
        self.id = id
        self.name = name
        self.organization = organization
        self.specialty = specialty
        self.phone = phone
        self.address = address
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.version = version
        self.previousVersionId = previousVersionId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        organization = try container.decodeIfPresent(String.self, forKey: .organization)
        guard name != nil || organization != nil else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Provider must have at least one of name or organization"
                )
            )
        }
        specialty = try container.decodeIfPresent(String.self, forKey: .specialty)
        phone = try container.decodeIfPresent(String.self, forKey: .phone)
        address = try container.decodeIfPresent(String.self, forKey: .address)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        version = try container.decode(Int.self, forKey: .version)
        previousVersionId = try container.decodeIfPresent(UUID.self, forKey: .previousVersionId)
    }
}
