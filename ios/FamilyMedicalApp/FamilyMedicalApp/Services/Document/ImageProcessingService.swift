import ImageIO
import UIKit
import UniformTypeIdentifiers

/// Protocol for image validation and thumbnail generation
///
/// This service validates image data via CGImageSource (Apple's codec layer) and
/// generates JPEG thumbnails for preview. Original image bytes are stored as-is —
/// no re-encoding.
protocol ImageProcessingServiceProtocol: Sendable {
    /// Validate image data and detect its MIME type via CGImageSource.
    /// Returns the detected MIME type. Throws if data is not a valid image.
    func validateImage(_ imageData: Data) throws -> String

    /// Generate a JPEG thumbnail for preview.
    ///
    /// This performs a full pixel decode (UIImage(data:)) which validates
    /// content integrity — corrupt pixels are caught here.
    ///
    /// - Parameters:
    ///   - imageData: Raw image data
    ///   - maxDimension: Maximum width or height for thumbnail
    /// - Returns: Thumbnail as JPEG data
    /// - Throws: ModelError.imageProcessingFailed if processing fails
    func generateThumbnail(_ imageData: Data, maxDimension: Int) throws -> Data
}

/// Default implementation using ImageIO + UIKit for image processing
final class ImageProcessingService: ImageProcessingServiceProtocol, @unchecked Sendable {
    // MARK: - Constants

    /// JPEG compression quality for thumbnails (smaller = smaller file)
    private let thumbnailCompressionQuality: CGFloat = 0.7

    // MARK: - Properties

    private let logger: TracingCategoryLogger

    // MARK: - Initialization

    init(logger: CategoryLoggerProtocol? = nil) {
        self.logger = TracingCategoryLogger(
            wrapping: logger ?? LoggingService.shared.logger(category: .storage)
        )
    }

    // MARK: - ImageProcessingServiceProtocol

    func validateImage(_ imageData: Data) throws -> String {
        let start = ContinuousClock.now
        logger.entry("validateImage")
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil) else {
            throw ModelError.imageProcessingFailed(reason: "Could not create image source from data")
        }
        guard let utTypeString = CGImageSourceGetType(source) as? String,
              let utType = UTType(utTypeString)
        else {
            throw ModelError.imageProcessingFailed(reason: "Could not determine image type")
        }
        guard let mimeType = utType.preferredMIMEType else {
            throw ModelError.imageProcessingFailed(reason: "No MIME type for detected image format")
        }
        logger.debug("Detected image MIME: \(mimeType)")
        logger.exit("validateImage", duration: ContinuousClock.now - start)
        return mimeType
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
}
