import Foundation
import UIKit
@testable import FamilyMedicalApp

/// Shared test helpers for creating attachment fixtures across test files.
/// Extracted from AttachmentPickerViewModelTests and AttachmentViewerViewModelTests.
enum AttachmentTestHelper {
    /// Creates a test UIImage for attachment tests.
    ///
    /// - Parameter size: The size of the image to create. Defaults to 100x100.
    /// - Returns: A solid blue UIImage of the specified size.
    static func makeTestImage(size: CGSize = CGSize(width: 100, height: 100)) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor.blue.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }

    /// Creates a test Attachment with randomized HMAC for unique identification.
    ///
    /// - Parameters:
    ///   - id: The attachment ID. Defaults to a new UUID.
    ///   - fileName: The file name. Defaults to "test.jpg".
    ///   - mimeType: The MIME type. Defaults to "image/jpeg".
    ///   - encryptedSize: The encrypted content size. Defaults to 1024.
    ///   - uploadedAt: The upload date. Defaults to current date.
    /// - Returns: A test Attachment instance.
    /// - Throws: If attachment creation fails validation.
    static func makeTestAttachment(
        id: UUID = UUID(),
        fileName: String = "test.jpg",
        mimeType: String = "image/jpeg",
        encryptedSize: Int = 1_024,
        uploadedAt: Date = Date()
    ) throws -> FamilyMedicalApp.Attachment {
        try FamilyMedicalApp.Attachment(
            id: id,
            fileName: fileName,
            mimeType: mimeType,
            contentHMAC: Data((0 ..< 32).map { _ in UInt8.random(in: 0 ... 255) }),
            encryptedSize: encryptedSize,
            thumbnailData: nil,
            uploadedAt: uploadedAt
        )
    }

    /// Creates a test Attachment with a fixed HMAC for deterministic tests.
    ///
    /// - Parameters:
    ///   - id: The attachment ID. Defaults to a new UUID.
    ///   - fileName: The file name. Defaults to "test.jpg".
    ///   - mimeType: The MIME type. Defaults to "image/jpeg".
    ///   - hmacByte: The byte value to fill the HMAC with. Defaults to 0xAB.
    ///   - encryptedSize: The encrypted content size. Defaults to 1024.
    ///   - uploadedAt: The upload date. Defaults to current date.
    /// - Returns: A test Attachment instance with deterministic HMAC.
    /// - Throws: If attachment creation fails validation.
    static func makeTestAttachmentDeterministic(
        id: UUID = UUID(),
        fileName: String = "test.jpg",
        mimeType: String = "image/jpeg",
        hmacByte: UInt8 = 0xAB,
        encryptedSize: Int = 1_024,
        uploadedAt: Date = Date()
    ) throws -> FamilyMedicalApp.Attachment {
        try FamilyMedicalApp.Attachment(
            id: id,
            fileName: fileName,
            mimeType: mimeType,
            contentHMAC: Data(repeating: hmacByte, count: 32),
            encryptedSize: encryptedSize,
            thumbnailData: nil,
            uploadedAt: uploadedAt
        )
    }
}
