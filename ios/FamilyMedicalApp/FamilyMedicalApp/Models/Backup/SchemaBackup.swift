import Foundation

/// Custom schema data for backup
struct SchemaBackup: Codable, Equatable {
    let personId: UUID
    let schema: RecordSchema
}
