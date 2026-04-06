import UIKit

/// Protocol for image compression and thumbnail generation
///
/// This service handles preprocessing of images before encryption and storage.
/// It ensures images are within size limits while maintaining quality.
protocol ImageProcessingServiceProtocol: Sendable {
    /// Compress an image to fit within size and dimension limits
    ///
    /// - Parameters:
    ///   - imageData: Raw image data (JPEG or PNG)
    ///   - maxSizeBytes: Maximum file size in bytes
    ///   - maxDimension: Maximum width or height in pixels
    /// - Returns: Compressed JPEG data
    /// - Throws: ModelError.imageProcessingFailed if processing fails
    func compress(_ imageData: Data, maxSizeBytes: Int, maxDimension: Int) throws -> Data

    /// Generate a thumbnail from image data
    ///
    /// - Parameters:
    ///   - imageData: Raw image data (JPEG or PNG)
    ///   - maxDimension: Maximum width or height for thumbnail
    /// - Returns: Thumbnail as JPEG data
    /// - Throws: ModelError.imageProcessingFailed if processing fails
    func generateThumbnail(_ imageData: Data, maxDimension: Int) throws -> Data
}

/// Default implementation using UIKit for image processing
final class ImageProcessingService: ImageProcessingServiceProtocol, @unchecked Sendable {
    // MARK: - Constants

    /// Default JPEG compression quality for full images
    private let defaultCompressionQuality: CGFloat = 0.85

    /// JPEG compression quality for thumbnails (smaller = smaller file)
    private let thumbnailCompressionQuality: CGFloat = 0.7

    /// Minimum JPEG quality to try during iterative compression
    private let minimumCompressionQuality: CGFloat = 0.1

    /// Quality reduction step during iterative compression
    private let qualityStep: CGFloat = 0.1

    // MARK: - Properties

    private let logger: TracingCategoryLogger

    // MARK: - Initialization

    init(logger: CategoryLoggerProtocol? = nil) {
        self.logger = TracingCategoryLogger(
            wrapping: logger ?? LoggingService.shared.logger(category: .storage)
        )
    }

    // MARK: - ImageProcessingServiceProtocol

    func compress(_ imageData: Data, maxSizeBytes: Int, maxDimension: Int) throws -> Data {
        let start = ContinuousClock.now
        logger.entry("compress")
        guard let image = UIImage(data: imageData) else {
            logger.error("Failed to create image from data")
            throw ModelError.imageProcessingFailed(reason: "Could not create image from data")
        }

        // First, resize if needed
        let resizedImage = resizeIfNeeded(image, maxDimension: maxDimension)

        // Then compress to meet size limit
        guard let compressedData = compressToSize(resizedImage, maxSizeBytes: maxSizeBytes) else {
            logger.error("Failed to compress image to target size")
            throw ModelError.imageProcessingFailed(reason: "Could not compress image to target size")
        }

        let ratio = Double(compressedData.count) / Double(imageData.count) * 100
        logger.debug("Compressed image: \(imageData.count) → \(compressedData.count) bytes (\(Int(ratio))%)")

        logger.exit("compress", duration: ContinuousClock.now - start)
        return compressedData
    }

    func generateThumbnail(_ imageData: Data, maxDimension: Int) throws -> Data {
        let start = ContinuousClock.now
        logger.entry("generateThumbnail")
        guard let image = UIImage(data: imageData) else {
            logger.error("Failed to create image for thumbnail")
            throw ModelError.imageProcessingFailed(reason: "Could not create image from data")
        }

        // Resize to thumbnail dimensions
        let thumbnailImage = resizeIfNeeded(image, maxDimension: maxDimension)

        // Convert to JPEG at thumbnail quality
        guard let thumbnailData = thumbnailImage.jpegData(compressionQuality: thumbnailCompressionQuality) else {
            logger.error("Failed to generate thumbnail data")
            throw ModelError.imageProcessingFailed(reason: "Could not generate thumbnail data")
        }

        logger.debug("Generated thumbnail: \(thumbnailData.count) bytes")

        logger.exit("generateThumbnail", duration: ContinuousClock.now - start)
        return thumbnailData
    }

    // MARK: - Private Helpers

    /// Resize image if it exceeds max dimension, maintaining aspect ratio
    private func resizeIfNeeded(_ image: UIImage, maxDimension: Int) -> UIImage {
        let maxDim = CGFloat(maxDimension)
        let size = image.size

        // Check if resize is needed
        guard size.width > maxDim || size.height > maxDim else {
            return image
        }

        // Calculate new size maintaining aspect ratio
        let aspectRatio = size.width / size.height
        let newSize = if size.width > size.height {
            CGSize(width: maxDim, height: maxDim / aspectRatio)
        } else {
            CGSize(width: maxDim * aspectRatio, height: maxDim)
        }

        // Use UIGraphicsImageRenderer for high-quality resizing
        // Force scale 1.0 for consistent pixel dimensions in storage
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    /// Iteratively compress image until it fits within size limit
    private func compressToSize(_ image: UIImage, maxSizeBytes: Int) -> Data? {
        var quality = defaultCompressionQuality

        // Try initial compression
        guard var data = image.jpegData(compressionQuality: quality) else {
            return nil
        }

        // If already under limit, return
        if data.count <= maxSizeBytes {
            return data
        }

        // Iteratively reduce quality until we fit
        while data.count > maxSizeBytes, quality > minimumCompressionQuality {
            quality -= qualityStep
            guard let newData = image.jpegData(compressionQuality: quality) else {
                return nil
            }
            data = newData
        }

        // Return result even if still over limit (caller can decide)
        return data
    }
}
