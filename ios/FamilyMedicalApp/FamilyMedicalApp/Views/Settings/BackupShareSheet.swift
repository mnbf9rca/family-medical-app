import Foundation
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Share Sheet

struct BackupShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    var onDismiss: (() -> Void)?

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, _, _, _ in
            // Clean up temp files after share completes (success or cancel)
            BackupFileItem.cleanupTempFiles()
            onDismiss?()
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Backup File Item for Sharing

final class BackupFileItem: NSObject, UIActivityItemSource {
    let data: Data
    let fileName: String

    /// Dedicated subdirectory for backup exports
    private static let exportDirectoryName = "FamilyMedicalAppExports"

    init(data: Data, fileName: String) {
        self.data = data
        self.fileName = fileName
    }

    /// Directory for temporary export files
    private static var exportDirectory: URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(exportDirectoryName, isDirectory: true)
    }

    /// Build the temp file URL for this backup
    private var tempURL: URL {
        Self.exportDirectory.appendingPathComponent(fileName)
    }

    /// Clean up all temporary export files
    static func cleanupTempFiles() {
        try? FileManager.default.removeItem(at: exportDirectory)
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        tempURL
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        // Ensure export directory exists
        try? FileManager.default.createDirectory(
            at: Self.exportDirectory,
            withIntermediateDirectories: true
        )

        // Write to temp file for sharing
        do {
            try data.write(to: tempURL, options: .atomic)
            return tempURL
        } catch {
            return nil
        }
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        subjectForActivityType activityType: UIActivity.ActivityType?
    ) -> String {
        "Family Medical App Backup"
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        dataTypeIdentifierForActivityType activityType: UIActivity.ActivityType?
    ) -> String {
        UTType.fmaBackup.identifier
    }
}

// MARK: - UTType Extension

extension UTType {
    static let fmaBackup = UTType(exportedAs: "com.cynexia.familymedicalapp.backup")
}
