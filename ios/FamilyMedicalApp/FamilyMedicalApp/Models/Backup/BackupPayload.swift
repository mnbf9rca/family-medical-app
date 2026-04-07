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
}

/// Backup metadata (counts, stored inside encrypted payload)
struct BackupMetadata: Codable, Equatable {
    let personCount: Int
    let recordCount: Int
    let providerCount: Int
}
