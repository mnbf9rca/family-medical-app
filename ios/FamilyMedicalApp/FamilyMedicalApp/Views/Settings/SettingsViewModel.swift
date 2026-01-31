import CryptoKit
import Foundation
import Observation

/// ViewModel for the Settings view handling backup export/import
@Observable
@MainActor
final class SettingsViewModel {
    // MARK: - Dependencies

    private let exportService: ExportServiceProtocol
    private let importService: ImportServiceProtocol
    private let backupFileService: BackupFileServiceProtocol
    private let passwordValidationService: PasswordValidationServiceProtocol
    private let logger: CategoryLoggerProtocol

    // MARK: - Export State

    var showingExportOptions = false
    var exportEncrypted = true
    var exportPassword = ""
    var exportConfirmPassword = ""
    var showingUnencryptedWarning = false
    var showingShareSheet = false
    var exportedFileData: Data?
    var isExporting = false

    // MARK: - Import State

    var showingFilePicker = false
    var showingImportPassword = false
    var showingImportPreview = false
    var importPassword = ""
    var selectedBackupFile: BackupFile?
    var importPreviewPayload: BackupPayload?
    var importCompleted = false
    var isImporting = false

    // MARK: - Common State

    var errorMessage: String?

    // MARK: - Computed Properties

    var passwordStrength: PasswordStrength {
        passwordValidationService.passwordStrength(exportPassword)
    }

    var canExport: Bool {
        if exportEncrypted {
            return !exportPassword.isEmpty &&
                exportPassword == exportConfirmPassword &&
                passwordStrength >= .fair
        }
        return true
    }

    var exportFileName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: Date())
        return "FamilyMedical-\(dateString).fmabackup"
    }

    // MARK: - Initialization

    init(
        exportService: ExportServiceProtocol,
        importService: ImportServiceProtocol,
        backupFileService: BackupFileServiceProtocol,
        passwordValidationService: PasswordValidationServiceProtocol = PasswordValidationService(),
        logger: CategoryLoggerProtocol? = nil
    ) {
        self.exportService = exportService
        self.importService = importService
        self.backupFileService = backupFileService
        self.passwordValidationService = passwordValidationService
        self.logger = logger ?? LoggingService.shared.logger(category: .storage)
    }

    /// Creates a SettingsViewModel with default production dependencies
    static func makeDefault() -> SettingsViewModel {
        let deps = DefaultDependencies()
        return SettingsViewModel(
            exportService: deps.exportService,
            importService: deps.importService,
            backupFileService: deps.backupFileService
        )
    }
}

// MARK: - Default Dependencies

/// Container for default production dependencies used by SettingsViewModel
private struct DefaultDependencies {
    let exportService: ExportServiceProtocol
    let importService: ImportServiceProtocol
    let backupFileService: BackupFileServiceProtocol

    init() {
        let coreDataStack = CoreDataStack.shared
        let encryptionService = EncryptionService()
        let fmkService = FamilyMemberKeyService()

        let personRepository = PersonRepository(
            coreDataStack: coreDataStack,
            encryptionService: encryptionService,
            fmkService: fmkService
        )
        let recordRepository = MedicalRecordRepository(coreDataStack: coreDataStack)
        let attachmentRepository = AttachmentRepository(
            coreDataStack: coreDataStack,
            encryptionService: encryptionService,
            fmkService: fmkService
        )
        let customSchemaRepository = CustomSchemaRepository(
            coreDataStack: coreDataStack,
            encryptionService: encryptionService
        )
        let recordContentService = RecordContentService(encryptionService: encryptionService)
        let attachmentService = Self.makeAttachmentService(
            attachmentRepository: attachmentRepository,
            encryptionService: encryptionService,
            fmkService: fmkService
        )

        self.exportService = ExportService(
            personRepository: personRepository,
            recordRepository: recordRepository,
            recordContentService: recordContentService,
            attachmentService: attachmentService,
            customSchemaRepository: customSchemaRepository,
            fmkService: fmkService
        )

        self.importService = ImportService(
            personRepository: personRepository,
            recordRepository: recordRepository,
            recordContentService: recordContentService,
            attachmentService: attachmentService,
            customSchemaRepository: customSchemaRepository,
            fmkService: fmkService
        )

        self.backupFileService = BackupFileService(
            keyDerivationService: KeyDerivationService(),
            encryptionService: encryptionService
        )
    }

    private static func makeAttachmentService(
        attachmentRepository: AttachmentRepositoryProtocol,
        encryptionService: EncryptionServiceProtocol,
        fmkService: FamilyMemberKeyServiceProtocol
    ) -> AttachmentService {
        // File storage init only fails if file system is inaccessible (fatal)
        guard let fileStorage = try? AttachmentFileStorageService() else {
            fatalError("Failed to initialize AttachmentFileStorageService - file system inaccessible")
        }
        return AttachmentService(
            attachmentRepository: attachmentRepository,
            fileStorage: fileStorage,
            imageProcessor: ImageProcessingService(),
            encryptionService: encryptionService,
            fmkService: fmkService
        )
    }
}

// MARK: - Export/Import Methods

extension SettingsViewModel {
    // MARK: - Export Methods

    func startExport() {
        resetExportState()
        showingExportOptions = true
    }

    func requestUnencryptedExport() {
        showingUnencryptedWarning = true
    }

    func confirmUnencryptedExport() {
        showingUnencryptedWarning = false
        exportEncrypted = false
    }

    func performExport(primaryKey: SymmetricKey) async {
        // Validate password if encrypted
        if exportEncrypted {
            if exportPassword.isEmpty {
                errorMessage = "Please enter a password to protect your backup."
                return
            }
            if exportPassword != exportConfirmPassword {
                errorMessage = "Passwords do not match. Please try again."
                return
            }
            if passwordStrength < .fair {
                errorMessage = "Please choose a stronger password."
                return
            }
        }

        isExporting = true
        errorMessage = nil

        do {
            // Step 1: Export data from repositories
            logger.debug("Starting backup export")
            let payload = try await exportService.exportData(primaryKey: primaryKey)

            // Step 2: Create backup file (encrypted or unencrypted)
            let backupFile: BackupFile = if exportEncrypted {
                try backupFileService.createEncryptedBackup(
                    payload: payload,
                    password: exportPassword
                )
            } else {
                try backupFileService.createUnencryptedBackup(payload: payload)
            }

            // Step 3: Serialize to JSON
            let jsonData = try backupFileService.serializeToJSON(file: backupFile)

            exportedFileData = jsonData
            showingExportOptions = false
            showingShareSheet = true

            logger.debug("Backup export completed: \(jsonData.count) bytes")
        } catch let error as BackupError {
            logger.error("Backup export failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        } catch {
            logger.error("Backup export failed: \(error.localizedDescription)")
            errorMessage = "Export failed: \(error.localizedDescription)"
        }

        isExporting = false
    }

    func resetExportState() {
        showingExportOptions = false
        exportEncrypted = true
        exportPassword = ""
        exportConfirmPassword = ""
        showingUnencryptedWarning = false
        showingShareSheet = false
        exportedFileData = nil
        isExporting = false
        errorMessage = nil
    }

    // MARK: - Import Methods

    func startImport() {
        resetImportState()
        showingFilePicker = true
    }

    func handleSelectedFile(url: URL) async {
        showingFilePicker = false
        errorMessage = nil

        do {
            // Start accessing the security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                errorMessage = "Unable to access the selected file."
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            // Read file data
            let fileData = try Data(contentsOf: url)
            await handleFileData(fileData)
        } catch let error as BackupError {
            logger.error("Failed to read backup file: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        } catch {
            logger.error("Failed to read backup file: \(error.localizedDescription)")
            errorMessage = "Failed to read backup file: \(error.localizedDescription)"
        }
    }

    /// Process backup file data (extracted for testability)
    func handleFileData(_ fileData: Data) async {
        do {
            // Parse backup file
            let backupFile = try backupFileService.deserializeFromJSON(fileData)

            // Verify checksum
            guard try backupFileService.verifyChecksum(file: backupFile) else {
                errorMessage = "The backup file appears to be corrupted."
                return
            }

            selectedBackupFile = backupFile

            if backupFile.encrypted {
                // Show password entry
                showingImportPassword = true
            } else {
                // Show preview directly
                let payload = try backupFileService.readUnencryptedBackup(file: backupFile)
                importPreviewPayload = payload
                showingImportPreview = true
            }
        } catch let error as BackupError {
            logger.error("Failed to parse backup file: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        } catch {
            logger.error("Failed to parse backup file: \(error.localizedDescription)")
            errorMessage = "Failed to read backup file: \(error.localizedDescription)"
        }
    }

    func decryptAndPreview() async {
        guard let backupFile = selectedBackupFile else {
            errorMessage = "No backup file selected."
            return
        }

        errorMessage = nil

        do {
            let payload = try backupFileService.decryptBackup(
                file: backupFile,
                password: importPassword
            )

            importPreviewPayload = payload
            showingImportPassword = false
            showingImportPreview = true
        } catch BackupError.invalidPassword {
            errorMessage = "Incorrect password. Please try again."
        } catch let error as BackupError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "Failed to decrypt backup: \(error.localizedDescription)"
        }
    }

    func performImport(primaryKey: SymmetricKey) async {
        guard let payload = importPreviewPayload else {
            errorMessage = "No backup data to import."
            return
        }

        isImporting = true
        errorMessage = nil

        do {
            logger.debug("Starting backup import")
            try await importService.importData(payload, primaryKey: primaryKey)

            importCompleted = true
            showingImportPreview = false
            resetImportState()

            logger.debug("Backup import completed successfully")
        } catch let error as BackupError {
            logger.error("Backup import failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        } catch {
            logger.error("Backup import failed: \(error.localizedDescription)")
            errorMessage = "Import failed: \(error.localizedDescription)"
        }

        isImporting = false
    }

    func resetImportState() {
        showingFilePicker = false
        showingImportPassword = false
        showingImportPreview = false
        importPassword = ""
        selectedBackupFile = nil
        importPreviewPayload = nil
        isImporting = false
        // Don't reset importCompleted here - it's used for success feedback
    }

    func dismissImportCompleted() {
        importCompleted = false
    }
}
