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
    private let demoModeService: DemoModeServiceProtocol
    private let logExportService: LogExportServiceProtocol
    private let cleanupService: OrphanBlobCleanupServiceProtocol
    private let personRepository: PersonRepositoryProtocol
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

    // MARK: - Demo Mode State

    var showingExitDemoConfirmation = false
    var demoModeExited = false

    // MARK: - Log Export State

    var logTimeWindow: LogTimeWindow = .last24Hours
    var logExportState: LogExportState = .idle
    var exportedLogURL: URL?
    var showingLogShareSheet = false

    // MARK: - Storage Cleanup State

    var isCheckingStorage = false
    var isCleaningStorage = false
    var showingCleanupConfirmation = false
    var showingCleanupResult = false
    var cleanupDryRunResult: CleanupResult?
    var cleanupResult: CleanupResult?

    enum LogExportState: Equatable {
        case idle
        case exporting
        case ready
        case error(String)
    }

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

    var isDemoMode: Bool {
        demoModeService.isInDemoMode
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
        demoModeService: DemoModeServiceProtocol = DemoModeService(),
        logExportService: LogExportServiceProtocol? = nil,
        cleanupService: OrphanBlobCleanupServiceProtocol? = nil,
        personRepository: PersonRepositoryProtocol? = nil,
        logger: CategoryLoggerProtocol? = nil
    ) {
        self.exportService = exportService
        self.importService = importService
        self.backupFileService = backupFileService
        self.passwordValidationService = passwordValidationService
        self.demoModeService = demoModeService
        self.logExportService = logExportService ?? LogExportService()
        self.cleanupService = cleanupService ?? OrphanBlobCleanupService.makeDefault()
        self.personRepository = personRepository ?? DefaultDependencies().personRepository
        self.logger = logger ?? LoggingService.shared.logger(category: .storage)
    }

    /// Creates a SettingsViewModel with default production dependencies
    static func makeDefault() -> SettingsViewModel {
        let deps = DefaultDependencies()
        return SettingsViewModel(
            exportService: deps.exportService,
            importService: deps.importService,
            backupFileService: deps.backupFileService,
            personRepository: deps.personRepository
        )
    }
}

// MARK: - Default Dependencies

/// Container for default production dependencies used by SettingsViewModel
private struct DefaultDependencies {
    let exportService: ExportServiceProtocol
    let importService: ImportServiceProtocol
    let backupFileService: BackupFileServiceProtocol
    let personRepository: PersonRepositoryProtocol

    init() {
        let coreDataStack = CoreDataStack.shared
        let encryptionService = EncryptionService()
        let fmkService = FamilyMemberKeyService()

        let personRepository = PersonRepository(
            coreDataStack: coreDataStack,
            encryptionService: encryptionService,
            fmkService: fmkService
        )
        self.personRepository = personRepository
        let recordRepository = MedicalRecordRepository(coreDataStack: coreDataStack)
        let recordContentService = RecordContentService(encryptionService: encryptionService)
        let providerRepository = ProviderRepository(
            coreDataStack: coreDataStack,
            encryptionService: encryptionService,
            fmkService: fmkService
        )

        self.exportService = ExportService(
            personRepository: personRepository,
            recordRepository: recordRepository,
            recordContentService: recordContentService,
            providerRepository: providerRepository,
            fmkService: fmkService
        )

        self.importService = ImportService(
            personRepository: personRepository,
            recordRepository: recordRepository,
            recordContentService: recordContentService,
            providerRepository: providerRepository,
            fmkService: fmkService
        )

        self.backupFileService = BackupFileService(
            keyDerivationService: KeyDerivationService(),
            encryptionService: encryptionService
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
            logger.logError(error, context: "SettingsViewModel.performExport")
            errorMessage = error.localizedDescription
        } catch {
            logger.logError(error, context: "SettingsViewModel.performExport")
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
            logger.logError(error, context: "SettingsViewModel.handleSelectedFile")
            errorMessage = error.localizedDescription
        } catch {
            logger.logError(error, context: "SettingsViewModel.handleSelectedFile")
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
            logger.logError(error, context: "SettingsViewModel.handleFileData")
            errorMessage = error.localizedDescription
        } catch {
            logger.logError(error, context: "SettingsViewModel.handleFileData")
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
            logger.logError(error, context: "SettingsViewModel.performImport")
            errorMessage = error.localizedDescription
        } catch {
            logger.logError(error, context: "SettingsViewModel.performImport")
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

    // MARK: - Demo Mode Methods

    func showExitDemoConfirmation() {
        showingExitDemoConfirmation = true
    }

    func cancelExitDemo() {
        showingExitDemoConfirmation = false
    }

    func confirmExitDemo() async {
        showingExitDemoConfirmation = false
        demoModeExited = true

        // Notify the app that demo mode has exited
        // MainAppView observes this to trigger AuthenticationViewModel.exitDemoMode()
        // which handles the actual demoModeService.exitDemoMode() call
        NotificationCenter.default.post(name: .demoModeExitRequested, object: nil)
    }

    // MARK: - Log Export Methods

    func exportDiagnosticLogs() async {
        logExportState = .exporting
        do {
            let url = try await logExportService.exportLogs(timeWindow: logTimeWindow)
            exportedLogURL = url
            logExportState = .ready
            showingLogShareSheet = true
        } catch {
            logger.logError(error, context: "SettingsViewModel.exportDiagnosticLogs")
            logExportState = .error(error.localizedDescription)
        }
    }
}

// MARK: - Storage Cleanup

extension SettingsViewModel {
    /// Run a dry-run orphan scan across all persons. If any orphans are found, surface
    /// the confirmation dialog; otherwise show a result alert immediately.
    func checkStorage(primaryKey: SymmetricKey) async {
        isCheckingStorage = true
        cleanupDryRunResult = nil
        cleanupResult = nil
        errorMessage = nil

        do {
            let persons = try await personRepository.fetchAll(primaryKey: primaryKey)
            var totalOrphans = 0
            var totalBytes: UInt64 = 0
            for person in persons {
                let result = try await cleanupService.countOrphans(
                    personId: person.id,
                    primaryKey: primaryKey
                )
                totalOrphans += result.orphanCount
                totalBytes += result.freedBytes
            }
            let aggregate = CleanupResult(orphanCount: totalOrphans, freedBytes: totalBytes)
            cleanupDryRunResult = aggregate

            if aggregate.orphanCount > 0 {
                showingCleanupConfirmation = true
            } else {
                cleanupResult = aggregate
                showingCleanupResult = true
            }
        } catch {
            logger.logError(error, context: "SettingsViewModel.checkStorage")
            errorMessage = "Unable to check storage. Please try again."
        }

        isCheckingStorage = false
    }

    /// Actually delete orphaned blobs for every person. Aggregates counts across persons
    /// and surfaces the total in the result alert.
    func performCleanup(primaryKey: SymmetricKey) async {
        isCleaningStorage = true
        errorMessage = nil
        showingCleanupConfirmation = false
        // Drop the stale dry-run so a future alert body that reads cleanupDryRunResult
        // after cleanup cannot display a pre-cleanup number next to a post-cleanup one.
        cleanupDryRunResult = nil

        do {
            let persons = try await personRepository.fetchAll(primaryKey: primaryKey)
            var totalOrphans = 0
            var totalBytes: UInt64 = 0
            for person in persons {
                let result = try await cleanupService.cleanOrphans(
                    personId: person.id,
                    primaryKey: primaryKey
                )
                totalOrphans += result.orphanCount
                totalBytes += result.freedBytes
            }
            cleanupResult = CleanupResult(orphanCount: totalOrphans, freedBytes: totalBytes)
            showingCleanupResult = true
        } catch {
            logger.logError(error, context: "SettingsViewModel.performCleanup")
            errorMessage = "Some files could not be cleaned up."
        }

        isCleaningStorage = false
    }
}

// MARK: - Demo Mode Notifications

extension Notification.Name {
    /// Posted when the user requests to exit demo mode from Settings
    static let demoModeExitRequested = Notification.Name("demoModeExitRequested")
}
