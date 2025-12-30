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
