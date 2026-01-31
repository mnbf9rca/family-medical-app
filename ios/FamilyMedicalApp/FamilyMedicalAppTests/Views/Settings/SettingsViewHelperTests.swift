import Foundation
import Testing
import UIKit
import UniformTypeIdentifiers
@testable import FamilyMedicalApp

@Suite("SettingsView Helper Tests")
struct SettingsViewHelperTests {
    // MARK: - InfoRow Tests

    @Test("InfoRow displays label and value")
    func infoRowDisplays() {
        let row = InfoRow(label: "Test Label", value: "Test Value")

        #expect(row.label == "Test Label")
        #expect(row.value == "Test Value")
    }

    // MARK: - BackupFileItem Tests

    @Test("BackupFileItem stores data and filename")
    func backupFileItemStoresData() {
        let testData = Data("test content".utf8)
        let item = BackupFileItem(data: testData, fileName: "test.fmabackup")

        #expect(item.data == testData)
        #expect(item.fileName == "test.fmabackup")
    }

    @Test("BackupFileItem provides placeholder URL")
    @MainActor
    func backupFileItemPlaceholder() {
        let testData = Data("test".utf8)
        let item = BackupFileItem(data: testData, fileName: "backup.fmabackup")

        let placeholder = item.activityViewControllerPlaceholderItem(
            UIActivityViewController(activityItems: [], applicationActivities: nil)
        )

        #expect(placeholder is URL)
        if let url = placeholder as? URL {
            #expect(url.lastPathComponent == "backup.fmabackup")
        }
    }

    @Test("BackupFileItem returns subject for activity")
    @MainActor
    func backupFileItemSubject() {
        let item = BackupFileItem(data: Data(), fileName: "test.fmabackup")

        let subject = item.activityViewController(
            UIActivityViewController(activityItems: [], applicationActivities: nil),
            subjectForActivityType: nil
        )

        #expect(subject == "Family Medical App Backup")
    }

    @Test("BackupFileItem returns data type identifier")
    @MainActor
    func backupFileItemDataType() {
        let item = BackupFileItem(data: Data(), fileName: "test.fmabackup")

        let dataType = item.activityViewController(
            UIActivityViewController(activityItems: [], applicationActivities: nil),
            dataTypeIdentifierForActivityType: nil
        )

        #expect(dataType == UTType.fmaBackup.identifier)
    }

    @Test("BackupFileItem writes to temp file for activity")
    @MainActor
    func backupFileItemWritesTempFile() {
        let testData = Data("test content for export".utf8)
        let item = BackupFileItem(data: testData, fileName: "export.fmabackup")

        let result = item.activityViewController(
            UIActivityViewController(activityItems: [], applicationActivities: nil),
            itemForActivityType: nil
        )

        #expect(result is URL)
        if let url = result as? URL {
            #expect(url.lastPathComponent == "export.fmabackup")
            // Verify file was written
            let readData = try? Data(contentsOf: url)
            #expect(readData == testData)
        }
        // Cleanup via the cleanup method
        BackupFileItem.cleanupTempFiles()
    }

    @Test("BackupFileItem cleanup removes temp directory")
    @MainActor
    func backupFileItemCleanup() {
        // First create a temp file
        let testData = Data("cleanup test".utf8)
        let item = BackupFileItem(data: testData, fileName: "cleanup-test.fmabackup")

        let result = item.activityViewController(
            UIActivityViewController(activityItems: [], applicationActivities: nil),
            itemForActivityType: nil
        )

        guard let url = result as? URL else {
            Issue.record("Expected URL result")
            return
        }

        // Verify file exists
        #expect(FileManager.default.fileExists(atPath: url.path))

        // Call cleanup
        BackupFileItem.cleanupTempFiles()

        // Verify file no longer exists
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    @Test("BackupFileItem uses dedicated export directory")
    @MainActor
    func backupFileItemExportDirectory() {
        let testData = Data("directory test".utf8)
        let item = BackupFileItem(data: testData, fileName: "dir-test.fmabackup")

        let result = item.activityViewController(
            UIActivityViewController(activityItems: [], applicationActivities: nil),
            itemForActivityType: nil
        )

        guard let url = result as? URL else {
            Issue.record("Expected URL result")
            return
        }

        // Verify path contains the export directory
        #expect(url.path.contains("FamilyMedicalAppExports"))

        // Cleanup
        BackupFileItem.cleanupTempFiles()
    }

    // MARK: - UTType Extension Tests

    @Test("UTType.fmaBackup has correct identifier")
    func utTypeFmaBackup() {
        let identifier = UTType.fmaBackup.identifier

        #expect(identifier == "com.cynexia.familymedicalapp.backup")
    }
}
