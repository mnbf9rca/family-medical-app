import Foundation
import SwiftUI

/// Helper for detecting if the app is running in UI testing mode
enum UITestingHelpers {
    /// Returns true if the app was launched with --uitesting flag
    /// - Note: This can ONLY be true when launched by XCUITest automation
    /// - Warning: Release builds will assert if this is somehow true (safety check)
    static var isUITesting: Bool {
        let isTesting = CommandLine.arguments.contains("--uitesting")

        #if !DEBUG
        // Safety assertion: Release builds should NEVER have --uitesting flag
        // This would indicate a security issue (insecure TextFields in production)
        assert(!isTesting, "SECURITY ERROR: --uitesting flag detected in Release build")
        #endif

        return isTesting
    }

    /// Returns true if test attachments should be auto-seeded when creating records
    /// - Note: When enabled, creating a record with attachment capability will
    ///   automatically add a synthetic test attachment for coverage testing
    static var shouldSeedTestAttachments: Bool {
        isUITesting && CommandLine.arguments.contains("--seed-test-attachments")
    }

    /// Returns true if demo mode should be used for faster test setup
    /// - Note: When enabled, tests can use demo mode instead of full account creation
    static var shouldUseDemoMode: Bool {
        isUITesting && CommandLine.arguments.contains("--use-demo-mode")
    }

    /// Test attachment data for UI coverage testing
    struct TestAttachmentData {
        let id: UUID
        let fileName: String
        let mimeType: String
        let thumbnailData: Data
    }

    /// Creates synthetic test attachment data for UI test coverage
    /// - Returns: Test attachment metadata for creating synthetic attachments
    static func createTestAttachmentData() -> TestAttachmentData {
        TestAttachmentData(
            id: UUID(),
            fileName: "test_attachment.jpg",
            mimeType: "image/jpeg",
            thumbnailData: createTestThumbnailData()
        )
    }

    /// Creates minimal valid JPEG-like data for thumbnail testing
    /// This ensures AttachmentThumbnailView renders the thumbnail branch
    private static func createTestThumbnailData() -> Data {
        // Create a 1x1 blue pixel PNG (smallest valid image)
        // PNG header + IHDR + IDAT + IEND
        let pngData: [UInt8] = [
            0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
            0x00, 0x00, 0x00, 0x0D, // IHDR length
            0x49, 0x48, 0x44, 0x52, // IHDR
            0x00, 0x00, 0x00, 0x01, // width = 1
            0x00, 0x00, 0x00, 0x01, // height = 1
            0x08, 0x02, // bit depth 8, color type 2 (RGB)
            0x00, 0x00, 0x00, // compression, filter, interlace
            0x90, 0x77, 0x53, 0xDE, // CRC
            0x00, 0x00, 0x00, 0x0C, // IDAT length
            0x49, 0x44, 0x41, 0x54, // IDAT
            0x08, 0xD7, 0x63, 0x60, 0x60, 0xF8, 0x0F, 0x00, // compressed blue pixel
            0x01, 0x01, 0x01, 0x00, // Adler32
            0x1B, 0xB6, 0xEE, 0x56, // CRC
            0x00, 0x00, 0x00, 0x00, // IEND length
            0x49, 0x45, 0x4E, 0x44, // IEND
            0xAE, 0x42, 0x60, 0x82 // CRC
        ]
        return Data(pngData)
    }
}

// MARK: - View Extension

extension View {
    /// Conditionally applies textContentType only when NOT in UI testing mode
    /// This prevents password autofill prompts from blocking XCUITest automation
    @ViewBuilder
    func textContentTypeIfNotTesting(_ contentType: UITextContentType?) -> some View {
        if UITestingHelpers.isUITesting {
            // In UI testing mode: don't apply textContentType to avoid autofill prompts
            self
        } else {
            // In production: apply textContentType for proper password manager support
            self.textContentType(contentType)
        }
    }
}
