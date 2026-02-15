import CryptoKit
import SwiftUI

// MARK: - Preview & Preview Helpers

#if DEBUG

#Preview {
    SettingsView(
        viewModel: SettingsViewModel(
            exportService: PreviewExportService(),
            importService: PreviewImportService(),
            backupFileService: PreviewBackupFileService(),
            logExportService: PreviewLogExportService()
        ),
        primaryKey: SymmetricKey(size: .bits256)
    )
}

// swiftlint:disable unneeded_throws_rethrows
final class PreviewExportService: ExportServiceProtocol, @unchecked Sendable {
    func exportData(primaryKey: SymmetricKey) async throws -> BackupPayload {
        BackupPayload(
            exportedAt: Date(),
            appVersion: "1.0.0",
            metadata: BackupMetadata(
                personCount: 2,
                recordCount: 10,
                attachmentCount: 3,
                schemaCount: 1
            ),
            persons: [],
            records: [],
            attachments: [],
            schemas: []
        )
    }
}

final class PreviewImportService: ImportServiceProtocol, @unchecked Sendable {
    func importData(_ payload: BackupPayload, primaryKey: SymmetricKey) async throws {}
}

final class PreviewBackupFileService: BackupFileServiceProtocol, @unchecked Sendable {
    func createEncryptedBackup(payload: BackupPayload, password: String) throws -> BackupFile {
        BackupFile(
            schema: nil,
            formatName: BackupFile.formatNameValue,
            formatVersion: BackupFile.currentVersion,
            generator: "Preview",
            encrypted: true,
            checksum: BackupChecksum(algorithm: "SHA-256", value: "test"),
            encryption: BackupEncryption(
                algorithm: "AES-256-GCM",
                kdf: BackupKDF.defaultArgon2id,
                nonce: "test",
                tag: "test"
            ),
            ciphertext: "test",
            data: nil
        )
    }

    func createUnencryptedBackup(payload: BackupPayload) throws -> BackupFile {
        BackupFile(
            schema: nil,
            formatName: BackupFile.formatNameValue,
            formatVersion: BackupFile.currentVersion,
            generator: "Preview",
            encrypted: false,
            checksum: BackupChecksum(algorithm: "SHA-256", value: "test"),
            encryption: nil,
            ciphertext: nil,
            data: payload
        )
    }

    func decryptBackup(file: BackupFile, password: String) throws -> BackupPayload {
        BackupPayload(
            exportedAt: Date(),
            appVersion: "1.0.0",
            metadata: BackupMetadata(
                personCount: 0,
                recordCount: 0,
                attachmentCount: 0,
                schemaCount: 0
            ),
            persons: [],
            records: [],
            attachments: [],
            schemas: []
        )
    }

    func readUnencryptedBackup(file: BackupFile) throws -> BackupPayload {
        file.data ?? BackupPayload(
            exportedAt: Date(),
            appVersion: "1.0.0",
            metadata: BackupMetadata(
                personCount: 0,
                recordCount: 0,
                attachmentCount: 0,
                schemaCount: 0
            ),
            persons: [],
            records: [],
            attachments: [],
            schemas: []
        )
    }

    func verifyChecksum(file: BackupFile) throws -> Bool {
        true
    }

    func serializeToJSON(file: BackupFile) throws -> Data {
        Data("{\"test\": true}".utf8)
    }

    func deserializeFromJSON(_ data: Data) throws -> BackupFile {
        BackupFile(
            schema: nil,
            formatName: BackupFile.formatNameValue,
            formatVersion: BackupFile.currentVersion,
            generator: "Preview",
            encrypted: false,
            checksum: BackupChecksum(algorithm: "SHA-256", value: "test"),
            encryption: nil,
            ciphertext: nil,
            data: nil
        )
    }
}

final class PreviewLogExportService: LogExportServiceProtocol, @unchecked Sendable {
    func exportLogs(timeWindow: LogTimeWindow) async throws -> URL {
        // Write a stub diagnostic file for preview interaction
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("preview-diagnostics.txt")
        try Data("Preview diagnostic logs".utf8).write(to: url)
        return url
    }
}

// swiftlint:enable unneeded_throws_rethrows

#endif
