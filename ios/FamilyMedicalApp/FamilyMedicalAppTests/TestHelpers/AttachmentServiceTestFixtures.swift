import CryptoKit
import Foundation
import UIKit
@testable import FamilyMedicalApp

/// Shared test fixtures for AttachmentService tests
struct AttachmentServiceTestFixtures {
    let service: AttachmentService
    let repository: MockAttachmentRepository
    let fileStorage: MockAttachmentFileStorageService
    let imageProcessor: MockImageProcessingService
    let encryptionService: MockEncryptionService
    let fmkService: MockFamilyMemberKeyService
    let primaryKey: SymmetricKey
    let fmk: SymmetricKey
    let personId: UUID
    let recordId: UUID

    /// Create an AddAttachmentInput with common defaults
    func makeInput(
        data: Data,
        fileName: String,
        mimeType: String,
        recordId: UUID? = nil
    ) -> AddAttachmentInput {
        AddAttachmentInput(
            data: data,
            fileName: fileName,
            mimeType: mimeType,
            recordId: recordId ?? self.recordId,
            personId: personId,
            primaryKey: primaryKey
        )
    }

    /// Create a fully configured test fixtures instance
    static func make() -> AttachmentServiceTestFixtures {
        let repository = MockAttachmentRepository()
        let fileStorage = MockAttachmentFileStorageService()
        let imageProcessor = MockImageProcessingService()
        let encryptionService = MockEncryptionService()
        let fmkService = MockFamilyMemberKeyService()

        let primaryKey = SymmetricKey(size: .bits256)
        let fmk = SymmetricKey(size: .bits256)
        let personId = UUID()

        fmkService.storedFMKs[personId.uuidString] = fmk

        let service = AttachmentService(
            attachmentRepository: repository,
            fileStorage: fileStorage,
            imageProcessor: imageProcessor,
            encryptionService: encryptionService,
            fmkService: fmkService
        )

        return AttachmentServiceTestFixtures(
            service: service,
            repository: repository,
            fileStorage: fileStorage,
            imageProcessor: imageProcessor,
            encryptionService: encryptionService,
            fmkService: fmkService,
            primaryKey: primaryKey,
            fmk: fmk,
            personId: personId,
            recordId: UUID()
        )
    }

    /// Create test JPEG data with optional seed for variation
    /// - Parameter seed: Seed to vary the color (cycles through 6 colors)
    /// - Returns: Valid JPEG data
    static func makeTestJPEGData(seed: Int = 0) -> Data {
        let size = CGSize(width: 10, height: 10)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let colors: [UIColor] = [.blue, .red, .green, .yellow, .orange, .purple]
        let color = colors[seed % colors.count]
        let image = renderer.image { ctx in
            color.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
        // swiftlint:disable:next force_unwrapping
        return image.jpegData(compressionQuality: 0.5)!
    }

    /// Create test PDF data
    /// - Returns: Valid PDF-like data (header + padding)
    static func makeTestPDFData() -> Data {
        var data = Data("%PDF-1.4\n".utf8)
        data.append(Data(repeating: 0, count: 100))
        return data
    }
}
