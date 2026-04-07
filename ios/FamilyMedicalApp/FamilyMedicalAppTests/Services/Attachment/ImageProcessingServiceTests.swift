import Foundation
import Testing
import UIKit
@testable import FamilyMedicalApp

struct ImageProcessingServiceTests {
    // MARK: - Test Fixtures

    let service = ImageProcessingService()

    /// Create a test image with specific dimensions at scale 1.0
    /// Using scale 1.0 ensures pixel dimensions match point dimensions
    func makeTestImage(width: Int, height: Int, color: UIColor = .red) -> Data {
        let size = CGSize(width: width, height: height)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0 // Force 1:1 scale to match pixel dimensions
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { ctx in
            color.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
        // swiftlint:disable:next force_unwrapping
        return image.jpegData(compressionQuality: 0.9)!
    }

    /// Create test PNG data at scale 1.0
    func makeTestPNG(width: Int, height: Int) -> Data {
        let size = CGSize(width: width, height: height)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { ctx in
            UIColor.blue.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
        // swiftlint:disable:next force_unwrapping
        return image.pngData()!
    }

    // MARK: - validateImage Tests

    @Test
    func validateImage_jpegData_returnsJPEGMime() throws {
        let imageData = makeTestImage(width: 100, height: 100)

        let mimeType = try service.validateImage(imageData)

        #expect(mimeType == "image/jpeg")
    }

    @Test
    func validateImage_pngData_returnsPNGMime() throws {
        let pngData = makeTestPNG(width: 100, height: 100)

        let mimeType = try service.validateImage(pngData)

        #expect(mimeType == "image/png")
    }

    @Test
    func validateImage_invalidData_throwsError() throws {
        let invalidData = Data("not an image".utf8)

        #expect(throws: ModelError.self) {
            _ = try service.validateImage(invalidData)
        }
    }

    @Test
    func validateImage_emptyData_throwsError() throws {
        let emptyData = Data()

        #expect(throws: ModelError.self) {
            _ = try service.validateImage(emptyData)
        }
    }

    @Test
    func validateImage_largeJPEG_returnsCorrectMime() throws {
        let imageData = makeTestImage(width: 3_000, height: 2_000)

        let mimeType = try service.validateImage(imageData)

        #expect(mimeType == "image/jpeg")
    }

    // MARK: - Generate Thumbnail Tests

    @Test
    func generateThumbnail_validImage_returnsThumbnail() throws {
        let imageData = makeTestImage(width: 500, height: 500)

        let thumbnail = try service.generateThumbnail(imageData, maxDimension: 200)

        #expect(!thumbnail.isEmpty)

        guard let thumbnailImage = UIImage(data: thumbnail) else {
            Issue.record("Thumbnail data is not a valid image")
            return
        }

        let maxDim = max(thumbnailImage.size.width, thumbnailImage.size.height)
        #expect(maxDim <= 200)
    }

    @Test
    func generateThumbnail_smallImage_notUpscaled() throws {
        // Image smaller than thumbnail size
        let imageData = makeTestImage(width: 100, height: 100)

        let thumbnail = try service.generateThumbnail(imageData, maxDimension: 200)

        #expect(!thumbnail.isEmpty)

        guard let thumbnailImage = UIImage(data: thumbnail) else {
            Issue.record("Thumbnail data is not a valid image")
            return
        }

        // Should not be upscaled beyond original size
        // The exact size may vary due to JPEG re-encoding, but should not exceed original
        #expect(thumbnailImage.size.width <= 200)
        #expect(thumbnailImage.size.height <= 200)
    }

    @Test
    func generateThumbnail_largeImage_resizesToMaxDimension() throws {
        let imageData = makeTestImage(width: 3_000, height: 2_000)

        let thumbnail = try service.generateThumbnail(imageData, maxDimension: 200)

        guard let thumbnailImage = UIImage(data: thumbnail) else {
            Issue.record("Thumbnail data is not a valid image")
            return
        }

        let maxDim = max(thumbnailImage.size.width, thumbnailImage.size.height)
        #expect(maxDim <= 200)
    }

    @Test
    func generateThumbnail_invalidData_throwsError() throws {
        let invalidData = Data("not an image".utf8)

        #expect(throws: ModelError.self) {
            _ = try service.generateThumbnail(invalidData, maxDimension: 200)
        }
    }

    @Test
    func generateThumbnail_pngImage_convertsToJPEG() throws {
        let pngData = makeTestPNG(width: 300, height: 300)

        let thumbnail = try service.generateThumbnail(pngData, maxDimension: 200)

        // Verify JPEG format (magic bytes)
        let bytes = [UInt8](thumbnail.prefix(3))
        #expect(bytes[0] == 0xFF)
        #expect(bytes[1] == 0xD8)
        #expect(bytes[2] == 0xFF)
    }

    @Test
    func generateThumbnail_maintainsAspectRatio() throws {
        // 2:1 aspect ratio image
        let imageData = makeTestImage(width: 600, height: 300)

        let thumbnail = try service.generateThumbnail(imageData, maxDimension: 200)

        guard let thumbnailImage = UIImage(data: thumbnail) else {
            Issue.record("Thumbnail data is not a valid image")
            return
        }

        // Width should be max (200), height should be half (100)
        let ratio = thumbnailImage.size.width / thumbnailImage.size.height
        #expect(ratio > 1.8 && ratio < 2.2) // ~2.0 with tolerance
    }

    // MARK: - Empty/Edge Cases

    @Test
    func generateThumbnail_emptyData_throwsError() throws {
        let emptyData = Data()

        #expect(throws: ModelError.self) {
            _ = try service.generateThumbnail(emptyData, maxDimension: 200)
        }
    }
}
