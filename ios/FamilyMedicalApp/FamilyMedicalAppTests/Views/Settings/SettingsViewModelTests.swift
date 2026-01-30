import CryptoKit
import Foundation
import Testing
@testable import FamilyMedicalApp

@Suite("SettingsViewModel Tests")
struct SettingsViewModelTests {
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

    // MARK: - Export Flow Tests

    @Test("Starting export shows export options")
    @MainActor
    func startExportShowsOptions() {
        let viewModel = makeViewModel()

        viewModel.startExport()

        #expect(viewModel.showingExportOptions == true)
        #expect(viewModel.exportPassword.isEmpty)
        #expect(viewModel.exportConfirmPassword.isEmpty)
    }

    @Test("Export with encryption requires password")
    @MainActor
    func exportWithEncryptionRequiresPassword() async {
        let viewModel = makeViewModel()

        viewModel.startExport()
        viewModel.exportEncrypted = true
        viewModel.exportPassword = ""

        await viewModel.performExport(primaryKey: testPrimaryKey)

        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.errorMessage?.contains("password") == true)
    }

    @Test("Export with encryption requires matching passwords")
    @MainActor
    func exportRequiresMatchingPasswords() async {
        let viewModel = makeViewModel()

        viewModel.startExport()
        viewModel.exportEncrypted = true
        viewModel.exportPassword = "TestPassword123!"
        viewModel.exportConfirmPassword = "DifferentPassword!"

        await viewModel.performExport(primaryKey: testPrimaryKey)

        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.errorMessage?.contains("match") == true)
    }

    @Test("Export without encryption shows warning")
    @MainActor
    func exportWithoutEncryptionShowsWarning() {
        let viewModel = makeViewModel()

        viewModel.startExport()
        viewModel.exportEncrypted = false
        viewModel.requestUnencryptedExport()

        #expect(viewModel.showingUnencryptedWarning == true)
    }

    @Test("Successful encrypted export produces file data")
    @MainActor
    func successfulEncryptedExport() async {
        let exportService = MockExportService()
        let backupFileService = MockBackupFileService()
        let viewModel = makeViewModel(
            exportService: exportService,
            backupFileService: backupFileService
        )

        viewModel.startExport()
        viewModel.exportEncrypted = true
        viewModel.exportPassword = "SecurePassword123!"
        viewModel.exportConfirmPassword = "SecurePassword123!"

        await viewModel.performExport(primaryKey: testPrimaryKey)

        #expect(viewModel.exportedFileData != nil)
        #expect(viewModel.showingShareSheet == true)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("Successful unencrypted export produces file data")
    @MainActor
    func successfulUnencryptedExport() async {
        let exportService = MockExportService()
        let backupFileService = MockBackupFileService()
        let viewModel = makeViewModel(
            exportService: exportService,
            backupFileService: backupFileService
        )

        viewModel.startExport()
        viewModel.exportEncrypted = false
        viewModel.confirmUnencryptedExport()

        await viewModel.performExport(primaryKey: testPrimaryKey)

        #expect(viewModel.exportedFileData != nil)
        #expect(viewModel.showingShareSheet == true)
    }

    @Test("Export failure shows error")
    @MainActor
    func exportFailureShowsError() async {
        let exportService = MockExportService()
        exportService.shouldFail = true
        let viewModel = makeViewModel(exportService: exportService)

        viewModel.startExport()
        viewModel.exportEncrypted = false
        viewModel.confirmUnencryptedExport()

        await viewModel.performExport(primaryKey: testPrimaryKey)

        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.exportedFileData == nil)
    }

    // MARK: - Import Flow Tests

    @Test("Starting import shows file picker")
    @MainActor
    func startImportShowsFilePicker() {
        let viewModel = makeViewModel()

        viewModel.startImport()

        #expect(viewModel.showingFilePicker == true)
    }

    @Test("Selecting encrypted file shows password entry")
    @MainActor
    func selectingEncryptedFileShowsPasswordEntry() async {
        let backupFileService = MockBackupFileService()
        backupFileService.mockBackupFile = BackupFile(
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

        let viewModel = makeViewModel(backupFileService: backupFileService)

        // Use handleFileData directly to avoid file system access
        await viewModel.handleFileData(Data("{\"test\": true}".utf8))

        #expect(viewModel.showingImportPassword == true)
        #expect(viewModel.selectedBackupFile != nil)
    }

    @Test("Selecting unencrypted file shows preview directly")
    @MainActor
    func selectingUnencryptedFileShowsPreview() async {
        let backupFileService = MockBackupFileService()
        let testPayload = BackupPayload(
            exportedAt: Date(),
            appVersion: "1.0.0",
            metadata: BackupMetadata(personCount: 2, recordCount: 5, attachmentCount: 1, schemaCount: 0),
            persons: [],
            records: [],
            attachments: [],
            schemas: []
        )
        backupFileService.mockBackupFile = BackupFile(
            schema: nil,
            formatName: BackupFile.formatNameValue,
            formatVersion: BackupFile.currentVersion,
            generator: "Test",
            encrypted: false,
            checksum: BackupChecksum(algorithm: "SHA-256", value: "test"),
            encryption: nil,
            ciphertext: nil,
            data: testPayload
        )

        let viewModel = makeViewModel(backupFileService: backupFileService)

        // Use handleFileData directly to avoid file system access
        await viewModel.handleFileData(Data("{\"test\": true}".utf8))

        #expect(viewModel.showingImportPreview == true)
        #expect(viewModel.importPreviewPayload != nil)
        #expect(viewModel.importPreviewPayload?.metadata.personCount == 2)
    }

    @Test("Successful import clears state")
    @MainActor
    func successfulImportClearsState() async {
        let importService = MockImportService()
        let viewModel = makeViewModel(importService: importService)
        viewModel.importPreviewPayload = BackupPayload(
            exportedAt: Date(),
            appVersion: "1.0.0",
            metadata: BackupMetadata(personCount: 1, recordCount: 1, attachmentCount: 0, schemaCount: 0),
            persons: [],
            records: [],
            attachments: [],
            schemas: []
        )

        await viewModel.performImport(primaryKey: testPrimaryKey)

        #expect(viewModel.importCompleted == true)
        #expect(viewModel.showingImportPreview == false)
        #expect(importService.importCallCount == 1)
    }

    @Test("Import failure shows error")
    @MainActor
    func importFailureShowsError() async {
        let importService = MockImportService()
        importService.shouldFail = true
        let viewModel = makeViewModel(importService: importService)
        viewModel.importPreviewPayload = BackupPayload(
            exportedAt: Date(),
            appVersion: "1.0.0",
            metadata: BackupMetadata(personCount: 1, recordCount: 1, attachmentCount: 0, schemaCount: 0),
            persons: [],
            records: [],
            attachments: [],
            schemas: []
        )

        await viewModel.performImport(primaryKey: testPrimaryKey)

        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.importCompleted == false)
    }

    // MARK: - Password Strength Tests

    @Test("Password strength updates as user types")
    @MainActor
    func passwordStrengthUpdates() {
        let viewModel = makeViewModel()

        viewModel.exportPassword = "weak"
        #expect(viewModel.passwordStrength == .weak)

        viewModel.exportPassword = "StrongerPassword123!"
        #expect(viewModel.passwordStrength >= .good)
    }

    // MARK: - Reset Tests

    @Test("Reset clears all export state")
    @MainActor
    func resetClearsExportState() {
        let viewModel = makeViewModel()
        viewModel.exportPassword = "test"
        viewModel.exportConfirmPassword = "test"
        viewModel.exportEncrypted = true
        viewModel.showingExportOptions = true
        viewModel.exportedFileData = Data()

        viewModel.resetExportState()

        #expect(viewModel.exportPassword.isEmpty)
        #expect(viewModel.exportConfirmPassword.isEmpty)
        #expect(viewModel.showingExportOptions == false)
        #expect(viewModel.exportedFileData == nil)
    }

    @Test("Reset clears all import state")
    @MainActor
    func resetClearsImportState() {
        let viewModel = makeViewModel()
        viewModel.importPassword = "test"
        viewModel.showingFilePicker = true
        viewModel.showingImportPassword = true
        viewModel.showingImportPreview = true

        viewModel.resetImportState()

        #expect(viewModel.importPassword.isEmpty)
        #expect(viewModel.showingFilePicker == false)
        #expect(viewModel.showingImportPassword == false)
        #expect(viewModel.showingImportPreview == false)
        #expect(viewModel.selectedBackupFile == nil)
        #expect(viewModel.importPreviewPayload == nil)
    }
}
