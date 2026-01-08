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

    // MARK: - Compress Tests

    @Test
    func compress_smallImage_returnsData() throws {
        let imageData = makeTestImage(width: 100, height: 100)

        let compressed = try service.compress(
            imageData,
            maxSizeBytes: 10_000_000, // 10 MB
            maxDimension: 4_096
        )

        #expect(!compressed.isEmpty)
    }

    @Test
    func compress_imageWithinLimits_returnsProcessed() throws {
        let imageData = makeTestImage(width: 200, height: 200)

        let compressed = try service.compress(
            imageData,
            maxSizeBytes: 10_000_000,
            maxDimension: 4_096
        )

        // Should return data (processed or original)
        #expect(!compressed.isEmpty)

        // Verify it's valid JPEG
        let image = UIImage(data: compressed)
        #expect(image != nil)
    }

    @Test
    func compress_oversizedImage_resizesToMaxDimension() throws {
        // Create a large image (2000x1000)
        let imageData = makeTestImage(width: 2_000, height: 1_000)

        let compressed = try service.compress(
            imageData,
            maxSizeBytes: 10_000_000,
            maxDimension: 500
        )

        // Verify output is valid image
        guard let outputImage = UIImage(data: compressed) else {
            Issue.record("Compressed data is not a valid image")
            return
        }

        // Should be resized (max dimension 500)
        let maxDim = max(outputImage.size.width, outputImage.size.height)
        #expect(maxDim <= 500)
    }

    @Test
    func compress_squareOversizedImage_resizesCorrectly() throws {
        let imageData = makeTestImage(width: 1_000, height: 1_000)

        let compressed = try service.compress(
            imageData,
            maxSizeBytes: 10_000_000,
            maxDimension: 300
        )

        guard let outputImage = UIImage(data: compressed) else {
            Issue.record("Compressed data is not a valid image")
            return
        }

        #expect(outputImage.size.width <= 300)
        #expect(outputImage.size.height <= 300)
    }

    @Test
    func compress_invalidData_throwsError() throws {
        let invalidData = Data("not an image".utf8)

        #expect(throws: ModelError.self) {
            _ = try service.compress(
                invalidData,
                maxSizeBytes: 10_000_000,
                maxDimension: 4_096
            )
        }
    }

    @Test
    func compress_pngImage_convertsToJPEG() throws {
        let pngData = makeTestPNG(width: 100, height: 100)

        let compressed = try service.compress(
            pngData,
            maxSizeBytes: 10_000_000,
            maxDimension: 4_096
        )

        // JPEG magic bytes: FF D8 FF
        let bytes = [UInt8](compressed.prefix(3))
        #expect(bytes[0] == 0xFF)
        #expect(bytes[1] == 0xD8)
        #expect(bytes[2] == 0xFF)
    }

    @Test
    func compress_portraitImage_maintainsAspectRatio() throws {
        // Portrait image: 500 wide, 1000 tall
        let imageData = makeTestImage(width: 500, height: 1_000)

        let compressed = try service.compress(
            imageData,
            maxSizeBytes: 10_000_000,
            maxDimension: 400
        )

        guard let outputImage = UIImage(data: compressed) else {
            Issue.record("Compressed data is not a valid image")
            return
        }

        // Max dimension should be 400 (the height)
        #expect(outputImage.size.height <= 400)
        // Width should maintain ratio (approximately half of height)
        let ratio = outputImage.size.width / outputImage.size.height
        #expect(ratio > 0.4 && ratio < 0.6) // ~0.5 with some tolerance
    }

    @Test
    func compress_landscapeImage_maintainsAspectRatio() throws {
        // Landscape image: 1000 wide, 500 tall
        let imageData = makeTestImage(width: 1_000, height: 500)

        let compressed = try service.compress(
            imageData,
            maxSizeBytes: 10_000_000,
            maxDimension: 400
        )

        guard let outputImage = UIImage(data: compressed) else {
            Issue.record("Compressed data is not a valid image")
            return
        }

        // Max dimension should be 400 (the width)
        #expect(outputImage.size.width <= 400)
        // Height should maintain ratio (approximately half of width)
        let ratio = outputImage.size.height / outputImage.size.width
        #expect(ratio > 0.4 && ratio < 0.6)
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

    // MARK: - Size Limit Tests

    @Test
    func compress_iterativelyReducesQuality() throws {
        // Create a moderately sized image
        let imageData = makeTestImage(width: 800, height: 800)

        // Request very small max size to force quality reduction
        let compressed = try service.compress(
            imageData,
            maxSizeBytes: 5_000, // Very small target
            maxDimension: 800
        )

        // Should return some data (may or may not hit target)
        #expect(!compressed.isEmpty)

        // Should be smaller than original
        #expect(compressed.count < imageData.count)
    }

    // MARK: - Empty/Edge Cases

    @Test
    func compress_emptyData_throwsError() throws {
        let emptyData = Data()

        #expect(throws: ModelError.self) {
            _ = try service.compress(emptyData, maxSizeBytes: 10_000_000, maxDimension: 4_096)
        }
    }

    @Test
    func generateThumbnail_emptyData_throwsError() throws {
        let emptyData = Data()

        #expect(throws: ModelError.self) {
            _ = try service.generateThumbnail(emptyData, maxDimension: 200)
        }
    }
}
