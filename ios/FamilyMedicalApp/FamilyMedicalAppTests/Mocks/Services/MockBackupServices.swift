import CryptoKit
import Foundation
@testable import FamilyMedicalApp

// swiftlint:disable unneeded_throws_rethrows

// MARK: - Mock Export Service

final class MockExportService: ExportServiceProtocol, @unchecked Sendable {
    var shouldFail = false
    var exportCallCount = 0

    func exportData(primaryKey _: SymmetricKey) async throws -> BackupPayload {
        exportCallCount += 1
        if shouldFail {
            throw BackupError.exportFailed("Mock failure")
        }
        return BackupPayload(
            exportedAt: Date(),
            appVersion: "1.0.0",
            metadata: BackupMetadata(personCount: 1, recordCount: 2, attachmentCount: 0, schemaCount: 0),
            persons: [
                PersonBackup(
                    id: UUID(),
                    name: "Test Person",
                    dateOfBirth: nil,
                    labels: [],
                    notes: nil,
                    createdAt: Date(),
                    updatedAt: Date()
                )
            ],
            records: [],
            attachments: [],
            schemas: []
        )
    }
}

// MARK: - Mock Import Service

final class MockImportService: ImportServiceProtocol, @unchecked Sendable {
    var shouldFail = false
    var importCallCount = 0
    var lastImportedPayload: BackupPayload?
    var lastPrimaryKey: SymmetricKey?

    func importData(_ payload: BackupPayload, primaryKey: SymmetricKey) async throws {
        importCallCount += 1
        lastImportedPayload = payload
        lastPrimaryKey = primaryKey
        if shouldFail {
            throw BackupError.importFailed("Mock failure")
        }
    }
}

// MARK: - Mock Backup File Service

final class MockBackupFileService: BackupFileServiceProtocol, @unchecked Sendable {
    var mockBackupFile: BackupFile?
    var mockDecryptedPayload: BackupPayload?
    var shouldFailDecrypt = false
    var shouldFailSerialize = false
    var shouldFailChecksum = false
    var shouldFailDeserialize = false

    func createEncryptedBackup(payload _: BackupPayload, password _: String) throws -> BackupFile {
        BackupFile(
            schema: nil,
            formatName: BackupFile.formatNameValue,
            formatVersion: BackupFile.currentVersion,
            generator: "Test",
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
            generator: "Test",
            encrypted: false,
            checksum: BackupChecksum(algorithm: "SHA-256", value: "test"),
            encryption: nil,
            ciphertext: nil,
            data: payload
        )
    }

    func decryptBackup(file _: BackupFile, password _: String) throws -> BackupPayload {
        if shouldFailDecrypt {
            throw BackupError.invalidPassword
        }
        return mockDecryptedPayload ?? BackupPayload(
            exportedAt: Date(),
            appVersion: "1.0.0",
            metadata: BackupMetadata(personCount: 0, recordCount: 0, attachmentCount: 0, schemaCount: 0),
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
            metadata: BackupMetadata(personCount: 0, recordCount: 0, attachmentCount: 0, schemaCount: 0),
            persons: [],
            records: [],
            attachments: [],
            schemas: []
        )
    }

    func verifyChecksum(file _: BackupFile) throws -> Bool {
        !shouldFailChecksum
    }

    func serializeToJSON(file _: BackupFile) throws -> Data {
        if shouldFailSerialize {
            throw BackupError.fileOperationFailed("Mock failure")
        }
        return Data("{\"test\": true}".utf8)
    }

    func deserializeFromJSON(_: Data) throws -> BackupFile {
        if shouldFailDeserialize {
            throw BackupError.corruptedFile
        }
        return mockBackupFile ?? BackupFile(
            schema: nil,
            formatName: BackupFile.formatNameValue,
            formatVersion: BackupFile.currentVersion,
            generator: "Test",
            encrypted: false,
            checksum: BackupChecksum(algorithm: "SHA-256", value: "test"),
            encryption: nil,
            ciphertext: nil,
            data: nil
        )
    }
}

// swiftlint:enable unneeded_throws_rethrows
