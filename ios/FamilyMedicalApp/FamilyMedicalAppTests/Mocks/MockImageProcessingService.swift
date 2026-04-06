import Foundation
import UIKit
@testable import FamilyMedicalApp

/// Mock implementation of ImageProcessingService for testing
final class MockImageProcessingService: ImageProcessingServiceProtocol, @unchecked Sendable {
    // MARK: - Call Record Types

    struct ValidateCall {
        let data: Data
    }

    struct ThumbnailCall {
        let data: Data
        let maxDimension: Int
    }

    // MARK: - Configuration

    var shouldFailValidate = false
    var shouldFailThumbnail = false

    /// MIME type to return from validateImage (defaults to "image/jpeg")
    var validateResult: String = "image/jpeg"

    /// Optional custom data to return from generateThumbnail
    var thumbnailResult: Data?

    // MARK: - Call Tracking

    var validateCalls: [ValidateCall] = []
    var thumbnailCalls: [ThumbnailCall] = []

    // MARK: - ImageProcessingServiceProtocol

    func validateImage(_ imageData: Data) throws -> String {
        validateCalls.append(ValidateCall(data: imageData))

        if shouldFailValidate {
            throw ModelError.imageProcessingFailed(reason: "Mock validate failure")
        }

        return validateResult
    }

    func generateThumbnail(_ imageData: Data, maxDimension: Int) throws -> Data {
        thumbnailCalls.append(ThumbnailCall(data: imageData, maxDimension: maxDimension))

        if shouldFailThumbnail {
            throw ModelError.imageProcessingFailed(reason: "Mock thumbnail failure")
        }

        // Return custom result or a small placeholder
        if let result = thumbnailResult {
            return result
        }

        // Generate a tiny valid JPEG as placeholder
        return createPlaceholderThumbnail()
    }

    // MARK: - Test Helpers

    func reset() {
        validateCalls.removeAll()
        thumbnailCalls.removeAll()
        shouldFailValidate = false
        shouldFailThumbnail = false
        validateResult = "image/jpeg"
        thumbnailResult = nil
    }

    private func createPlaceholderThumbnail() -> Data {
        // Create a small 10x10 image as placeholder
        let size = CGSize(width: 10, height: 10)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            UIColor.gray.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
        return image.jpegData(compressionQuality: 0.5) ?? Data()
    }
}
