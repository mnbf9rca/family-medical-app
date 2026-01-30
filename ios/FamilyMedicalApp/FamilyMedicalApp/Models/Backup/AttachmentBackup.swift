import Foundation

/// Attachment data for backup including file content
struct AttachmentBackup: Codable, Equatable {
    let id: UUID
    let personId: UUID
    let linkedRecordIds: [UUID]
    let fileName: String
    let mimeType: String
    let content: String // Base64-encoded file bytes
    let thumbnail: String? // Base64-encoded thumbnail or null
    let uploadedAt: Date

    init(
        id: UUID,
        personId: UUID,
        linkedRecordIds: [UUID],
        fileName: String,
        mimeType: String,
        content: Data,
        thumbnail: Data?,
        uploadedAt: Date
    ) {
        self.id = id
        self.personId = personId
        self.linkedRecordIds = linkedRecordIds
        self.fileName = fileName
        self.mimeType = mimeType
        self.content = content.base64EncodedString()
        self.thumbnail = thumbnail?.base64EncodedString()
        self.uploadedAt = uploadedAt
    }

    /// Decode content from base64
    var contentData: Data? {
        Data(base64Encoded: content)
    }

    /// Decode thumbnail from base64
    var thumbnailData: Data? {
        thumbnail.flatMap { Data(base64Encoded: $0) }
    }
}
