import Foundation

/// Decrypted provider data for backup
struct ProviderBackup: Codable, Equatable {
    let id: UUID
    let personId: UUID
    let name: String?
    let organization: String?
    let specialty: String?
    let phone: String?
    let address: String?
    let notes: String?
    let createdAt: Date
    let updatedAt: Date
    let version: Int
    let previousVersionId: UUID?

    /// Convert from decrypted Provider model with associated person ID
    init(from provider: Provider, personId: UUID) {
        self.id = provider.id
        self.personId = personId
        self.name = provider.name
        self.organization = provider.organization
        self.specialty = provider.specialty
        self.phone = provider.phone
        self.address = provider.address
        self.notes = provider.notes
        self.createdAt = provider.createdAt
        self.updatedAt = provider.updatedAt
        self.version = provider.version
        self.previousVersionId = provider.previousVersionId
    }

    /// Direct initialization
    init(
        id: UUID,
        personId: UUID,
        name: String?,
        organization: String?,
        specialty: String? = nil,
        phone: String? = nil,
        address: String? = nil,
        notes: String? = nil,
        createdAt: Date,
        updatedAt: Date,
        version: Int = 1,
        previousVersionId: UUID? = nil
    ) {
        self.id = id
        self.personId = personId
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

    /// Convert back to Provider model
    func toProvider() throws -> Provider {
        let trimmedName = name.trimmedNonEmpty()
        let trimmedOrganization = organization.trimmedNonEmpty()

        guard trimmedName != nil || trimmedOrganization != nil else {
            throw BackupError.corruptedFile
        }
        return Provider(
            id: id,
            name: trimmedName,
            organization: trimmedOrganization,
            specialty: specialty.trimmedNonEmpty(),
            phone: phone.trimmedNonEmpty(),
            address: address.trimmedNonEmpty(),
            notes: notes.trimmedNonEmpty(),
            createdAt: createdAt,
            updatedAt: updatedAt,
            version: version,
            previousVersionId: previousVersionId
        )
    }
}
