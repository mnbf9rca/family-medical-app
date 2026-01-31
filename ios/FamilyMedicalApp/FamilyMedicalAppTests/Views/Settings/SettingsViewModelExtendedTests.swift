import CryptoKit
import Foundation
import Testing
@testable import FamilyMedicalApp

@Suite("SettingsViewModel Extended Tests")
struct SettingsViewModelExtendedTests {
    // MARK: - Test Setup

    let testPrimaryKey = SymmetricKey(size: .bits256)

    @MainActor
    func makeViewModel(
        exportService: MockExportService = MockExportService(),
        importService: MockImportService = MockImportService(),
        backupFileService: MockBackupFileService = MockBackupFileService(),
        passwordValidationService: PasswordValidationServiceProtocol = PasswordValidationService()
    ) -> SettingsViewModel {
        SettingsViewModel(
            exportService: exportService,
            importService: importService,
            backupFileService: backupFileService,
            passwordValidationService: passwordValidationService
        )
    }

    // MARK: - Decrypt Tests

    @Test("Decrypting with correct password shows preview")
    @MainActor
    func decryptingWithCorrectPasswordShowsPreview() async {
        let backupFileService = MockBackupFileService()
        let testPayload = BackupPayload(
            exportedAt: Date(),
            appVersion: "1.0.0",
            metadata: BackupMetadata(personCount: 3, recordCount: 10, attachmentCount: 2, schemaCount: 1),
            persons: [],
            records: [],
            attachments: [],
            schemas: []
        )
        backupFileService.mockDecryptedPayload = testPayload

        let viewModel = makeViewModel(backupFileService: backupFileService)
        viewModel.selectedBackupFile = BackupFile(
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
        viewModel.importPassword = "CorrectPassword123!"

        await viewModel.decryptAndPreview()

        #expect(viewModel.showingImportPreview == true)
        #expect(viewModel.importPreviewPayload?.metadata.personCount == 3)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("Decrypting with wrong password shows error")
    @MainActor
    func decryptingWithWrongPasswordShowsError() async {
        let backupFileService = MockBackupFileService()
        backupFileService.shouldFailDecrypt = true

        let viewModel = makeViewModel(backupFileService: backupFileService)
        viewModel.selectedBackupFile = BackupFile(
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
        viewModel.importPassword = "WrongPassword!"

        await viewModel.decryptAndPreview()

        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.showingImportPreview == false)
    }

    // MARK: - Can Export Tests

    @Test("canExport is true for unencrypted export")
    @MainActor
    func canExportUnencrypted() {
        let viewModel = makeViewModel()
        viewModel.exportEncrypted = false

        #expect(viewModel.canExport == true)
    }

    @Test("canExport is false when encrypted but no password")
    @MainActor
    func canExportFalseWithoutPassword() {
        let viewModel = makeViewModel()
        viewModel.exportEncrypted = true
        viewModel.exportPassword = ""

        #expect(viewModel.canExport == false)
    }

    @Test("canExport is false when passwords don't match")
    @MainActor
    func canExportFalsePasswordMismatch() {
        let viewModel = makeViewModel()
        viewModel.exportEncrypted = true
        viewModel.exportPassword = "StrongPassword123!"
        viewModel.exportConfirmPassword = "DifferentPassword!"

        #expect(viewModel.canExport == false)
    }

    @Test("canExport is false when password too weak")
    @MainActor
    func canExportFalseWeakPassword() {
        let viewModel = makeViewModel()
        viewModel.exportEncrypted = true
        viewModel.exportPassword = "weak"
        viewModel.exportConfirmPassword = "weak"

        #expect(viewModel.canExport == false)
    }

    @Test("canExport is true when encrypted with strong matching passwords")
    @MainActor
    func canExportTrueStrongPassword() {
        let viewModel = makeViewModel()
        viewModel.exportEncrypted = true
        viewModel.exportPassword = "StrongPassword123!"
        viewModel.exportConfirmPassword = "StrongPassword123!"

        #expect(viewModel.canExport == true)
    }

    // MARK: - Export File Name Tests

    @Test("Export file name contains date")
    @MainActor
    func exportFileNameContainsDate() {
        let viewModel = makeViewModel()

        let fileName = viewModel.exportFileName

        #expect(fileName.hasPrefix("FamilyMedical-"))
        #expect(fileName.hasSuffix(".fmabackup"))
        #expect(fileName.contains("-"))
    }

    // MARK: - Export With Weak Password Tests

    @Test("Export with weak password shows error")
    @MainActor
    func exportWithWeakPasswordShowsError() async {
        let viewModel = makeViewModel()

        viewModel.startExport()
        viewModel.exportEncrypted = true
        viewModel.exportPassword = "weak"
        viewModel.exportConfirmPassword = "weak"

        await viewModel.performExport(primaryKey: testPrimaryKey)

        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.errorMessage?.contains("stronger") == true)
    }

    // MARK: - Backup File Service Failure Tests

    @Test("Export fails when backup file service fails to serialize")
    @MainActor
    func exportFailsOnSerializeError() async {
        let backupFileService = MockBackupFileService()
        backupFileService.shouldFailSerialize = true
        let viewModel = makeViewModel(backupFileService: backupFileService)

        viewModel.startExport()
        viewModel.exportEncrypted = false
        viewModel.confirmUnencryptedExport()

        await viewModel.performExport(primaryKey: testPrimaryKey)

        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.exportedFileData == nil)
    }

    // MARK: - Dismiss Import Completed Tests

    @Test("Dismiss import completed clears flag")
    @MainActor
    func dismissImportCompleted() {
        let viewModel = makeViewModel()
        viewModel.importCompleted = true

        viewModel.dismissImportCompleted()

        #expect(viewModel.importCompleted == false)
    }

    // MARK: - Checksum Failure Tests

    @Test("Import fails when checksum verification fails")
    @MainActor
    func importFailsOnChecksumFailure() async {
        let backupFileService = MockBackupFileService()
        backupFileService.shouldFailChecksum = true

        let viewModel = makeViewModel(backupFileService: backupFileService)

        await viewModel.handleFileData(Data("{\"test\": true}".utf8))

        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.errorMessage?.contains("corrupted") == true)
    }

    // MARK: - Handle Selected File Error Tests

    @Test("Selecting file shows error when deserialization fails")
    @MainActor
    func selectingFileShowsErrorOnDeserializeFail() async {
        let backupFileService = MockBackupFileService()
        backupFileService.shouldFailDeserialize = true

        let viewModel = makeViewModel(backupFileService: backupFileService)

        await viewModel.handleFileData(Data("{\"test\": true}".utf8))

        #expect(viewModel.errorMessage != nil)
    }

    // MARK: - Import With No Payload Tests

    @Test("Import fails when no payload is set")
    @MainActor
    func importFailsWithNoPayload() async {
        let viewModel = makeViewModel()
        viewModel.importPreviewPayload = nil

        await viewModel.performImport(primaryKey: testPrimaryKey)

        #expect(viewModel.errorMessage != nil)
        #expect(
            viewModel.errorMessage?.contains("no backup") == true ||
                viewModel.errorMessage?.contains("No backup") == true
        )
    }

    // MARK: - Decrypt With No File Tests

    @Test("Decrypt fails when no backup file selected")
    @MainActor
    func decryptFailsWithNoFile() async {
        let viewModel = makeViewModel()
        viewModel.selectedBackupFile = nil
        viewModel.importPassword = "test"

        await viewModel.decryptAndPreview()

        #expect(viewModel.errorMessage != nil)
    }
}
