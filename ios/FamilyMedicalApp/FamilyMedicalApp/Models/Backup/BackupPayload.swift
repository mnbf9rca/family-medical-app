import Foundation

/// Decrypted backup payload containing all user data
struct BackupPayload: Codable, Equatable {
    let exportedAt: Date
    let appVersion: String
    let metadata: BackupMetadata
    let persons: [PersonBackup]
    let records: [MedicalRecordBackup]
    let providers: [ProviderBackup]

    var isEmpty: Bool {
        persons.isEmpty && records.isEmpty && providers.isEmpty
    }

    /// Convenience initializer with default empty providers for backward compatibility
    init(
        exportedAt: Date,
        appVersion: String,
        metadata: BackupMetadata,
        persons: [PersonBackup],
        records: [MedicalRecordBackup],
        providers: [ProviderBackup] = []
    ) {
        self.exportedAt = exportedAt
        self.appVersion = appVersion
        self.metadata = metadata
        self.persons = persons
        self.records = records
        self.providers = providers
    }
}

/// Backup metadata (counts, stored inside encrypted payload)
struct BackupMetadata: Codable, Equatable {
    let personCount: Int
    let recordCount: Int
    let providerCount: Int

    /// Convenience initializer with default zero providerCount for backward compatibility
    init(personCount: Int, recordCount: Int, providerCount: Int = 0) {
        self.personCount = personCount
        self.recordCount = recordCount
        self.providerCount = providerCount
    }
}
