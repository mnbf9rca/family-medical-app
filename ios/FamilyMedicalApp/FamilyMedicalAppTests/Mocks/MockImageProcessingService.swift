import Foundation
import UIKit
@testable import FamilyMedicalApp

/// Mock implementation of ImageProcessingService for testing
final class MockImageProcessingService: ImageProcessingServiceProtocol, @unchecked Sendable {
    // MARK: - Call Record Types

    struct CompressCall {
        let data: Data
        let maxSizeBytes: Int
        let maxDimension: Int
    }

    struct ThumbnailCall {
        let data: Data
        let maxDimension: Int
    }

    // MARK: - Configuration

    var shouldFailCompress = false
    var shouldFailThumbnail = false

    /// Optional custom data to return from compress
    var compressResult: Data?

    /// Optional custom data to return from generateThumbnail
    var thumbnailResult: Data?

    // MARK: - Call Tracking

    var compressCalls: [CompressCall] = []
    var thumbnailCalls: [ThumbnailCall] = []

    // MARK: - ImageProcessingServiceProtocol

    func compress(_ imageData: Data, maxSizeBytes: Int, maxDimension: Int) throws -> Data {
        compressCalls.append(CompressCall(data: imageData, maxSizeBytes: maxSizeBytes, maxDimension: maxDimension))

        if shouldFailCompress {
            throw ModelError.imageProcessingFailed(reason: "Mock compress failure")
        }

        // Return custom result or the original data
        return compressResult ?? imageData
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
        compressCalls.removeAll()
        thumbnailCalls.removeAll()
        shouldFailCompress = false
        shouldFailThumbnail = false
        compressResult = nil
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
